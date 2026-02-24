import 'dart:async';
import 'dart:io'; // Platform kontrolu icin gerekli
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../providers/password_provider.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
import '../services/clipboard_service.dart';
import '../services/secure_storage_service.dart';
import '../models/password_model.dart';

class AuthFacade {
  AuthFacade({
    SecureStorageService? storageService,
    BiometricService? biometricService,
  })  : _storageService = storageService ?? SecureStorageService(),
        _biometricService = biometricService ?? BiometricService();

  final SecureStorageService _storageService;
  final BiometricService _biometricService;

  Future<bool> hasMasterPin() => _storageService.hasMasterPin();
  Future<bool> hasPanicPin() => _storageService.hasPanicPin();
  Future<bool> isBiometricEnabled() => _storageService.isBiometricEnabled();
  Future<bool> isBiometricsAvailable() =>
      _biometricService.isBiometricsAvailable();
  Future<bool> canCheckBiometrics() => _biometricService.canCheckBiometrics();
  Future<List<String>> availableBiometrics() =>
      _biometricService.availableBiometrics();
  Future<void> setBiometricEnabled(bool enabled) =>
      _storageService.setBiometricEnabled(enabled);

  Future<void> loginWithPin({
    required BuildContext context,
    required String pin,
    required bool isFirstTime,
    required PasswordProvider provider,
  }) async {
    final loc = AppLocalizations.of(context)!;

    if (pin.length < 4) {
      throw AuthException(loc.pinMinLength);
    }

    if (isFirstTime) {
      await _storageService.setMasterPin(pin);
      await _storageService.setSessionKeyFromPin(pin);
      return;
    }

    final isRealPin = await _storageService.checkMasterPin(pin);
    if (isRealPin) {
      await _storageService.setSessionKeyFromPin(pin);
      provider.exitPanicMode();
      return;
    }

    final isPanicPin = await _storageService.checkPanicPin(pin);
    if (isPanicPin) {
      _storageService.clearSessionKey();
      provider.enterPanicMode();
      return;
    }

    throw AuthException(loc.incorrectPin);
  }

  Future<bool> verifyMasterPin(String pin) =>
      _storageService.checkMasterPin(pin);

  Future<void> changeMasterPin({
    required BuildContext context,
    required String newPin,
    required PasswordProvider provider,
  }) async {
    if (newPin.length < 4) {
      throw AuthException(AppLocalizations.of(context)!.pinMinLength);
    }
    final newKey =
        await _storageService.deriveHiveKeyFromPin(newPin, rotateSalt: true);
    await provider.reencryptWithNewKey(newKey);
    await _storageService.setMasterPin(newPin, derivedHiveKey: newKey);
  }

  Future<void> setPanicPin({
    required BuildContext context,
    required String panicPin,
  }) async {
    final loc = AppLocalizations.of(context)!;
    if (panicPin.length < 4) {
      throw AuthException(loc.pinMinLength);
    }
    final isReal = await _storageService.checkMasterPin(panicPin);
    if (isReal) {
      throw AuthException(loc.panicPinSameAsMaster);
    }
    await _storageService.setPanicPin(panicPin);
  }

  Future<BiometricUnlockOutcome> attemptBiometricUnlock({
    required PasswordProvider provider,
    required String localizedReason,
  }) async {
    final available = await _biometricService.isBiometricsAvailable();
    if (kDebugMode) {
      debugPrint('[AuthFacade] biometricsAvailable=$available');
    }
    if (!available) {
      if (kDebugMode) {
        debugPrint(
            '[AuthFacade] outcome=${BiometricUnlockOutcome.unavailable.name}');
      }
      return BiometricUnlockOutcome.unavailable;
    }

    final authResult = await _biometricService.authenticateDetailed(
      localizedReason: localizedReason,
    );
    if (kDebugMode) {
      debugPrint(
        '[AuthFacade] biometricAuthenticate '
        'authenticated=${authResult.authenticated} '
        'errorType=${authResult.errorType ?? 'none'}',
      );
    }
    if (!authResult.authenticated) {
      if (kDebugMode) {
        debugPrint(
          '[AuthFacade] outcome=${BiometricUnlockOutcome.failedOrCanceled.name}',
        );
      }
      return BiometricUnlockOutcome.failedOrCanceled;
    }

    final restored = await _storageService.restoreSessionKeyForBiometric();
    if (kDebugMode) {
      debugPrint('[AuthFacade] sessionRestore restored=$restored');
    }
    if (!restored) {
      if (kDebugMode) {
        debugPrint(
          '[AuthFacade] outcome=${BiometricUnlockOutcome.successButRestoreFailed.name}',
        );
      }
      return BiometricUnlockOutcome.successButRestoreFailed;
    }

    provider.exitPanicMode();
    if (kDebugMode) {
      debugPrint('[AuthFacade] outcome=${BiometricUnlockOutcome.success.name}');
    }
    return BiometricUnlockOutcome.success;
  }

  Future<bool> biometricLogin({
    required BuildContext context,
    required PasswordProvider provider,
  }) async {
    final outcome = await attemptBiometricUnlock(
      provider: provider,
      localizedReason: AppLocalizations.of(context)!.biometricPrompt,
    );
    return outcome == BiometricUnlockOutcome.success;
  }
}

enum BiometricUnlockOutcome {
  success,
  failedOrCanceled,
  unavailable,
  successButRestoreFailed,
}

class BackupFacade {
  BackupFacade({BackupService? backupService})
      : _backupService = backupService ?? BackupService();

  final BackupService _backupService;

  Future<DateTime?> getLastBackupAt() => _backupService.getLastBackupAt();

  Future<void> exportPasswords(
      BuildContext context, PasswordProvider provider) async {
    final records = provider.passwords.map(_toRecord).toList();
    await _backupService.exportPasswords(context, records);
  }

  Future<void> importPasswords(
      BuildContext context, PasswordProvider provider) async {
    await _backupService.importPasswords(
      context,
      addRecord: (record) => _addRecord(provider, record),
    );
  }

  Map<String, dynamic> _toRecord(PasswordModel model) {
    return {
      'title': model.title,
      'username': model.username,
      'password': model.password,
      'url': model.url,
      'category': model.category,
      'createdDate': model.createdDate.toIso8601String(),
    };
  }

  Future<void> _addRecord(
      PasswordProvider provider, Map<String, dynamic> record) async {
    await provider.addPassword(
      record['title'] as String? ?? '',
      record['username'] as String? ?? '',
      record['password'] as String? ?? '',
      record['category'] as String? ?? PasswordCategories.general,
    );
  }
}

class LockFacade {
  LockFacade({ClipboardService? clipboardService})
      : _clipboardService = clipboardService ?? ClipboardService.instance;

  final ClipboardService _clipboardService;

  void copyPasswordToClipboard({
    required BuildContext context,
    required String password,
    required String title,
  }) {
    unawaited(
      _clipboardService.copyWithAutoClear(
        context,
        password,
        successMessageKey: ClipboardService.copiedToClipboardKey,
        payloadType: ClipboardPayloadType.password,
      ),
    );
  }

  void copyUsernameToClipboard({
    required BuildContext context,
    required String username,
    required String title,
  }) {
    unawaited(
      _clipboardService.copyWithAutoClear(
        context,
        username,
        successMessageKey: ClipboardService.copiedToClipboardKey,
        payloadType: ClipboardPayloadType.username,
      ),
    );
  }

  void dispose() {}

  void handleLifecycleState(AppLifecycleState state) {
    // ScreenProtector sadece Android ve iOS'ta calisir.
    if (Platform.isAndroid || Platform.isIOS) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        // ScreenProtector.protectDataLeakageWithBlur();
      } else if (state == AppLifecycleState.resumed) {
        // ScreenProtector.protectDataLeakageWithBlurOff();
      }
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}
