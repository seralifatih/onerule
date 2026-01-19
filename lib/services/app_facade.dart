import 'dart:async';
import 'dart:io'; // Platform kontrolü için gerekli
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../providers/password_provider.dart';
import '../services/backup_service.dart';
import '../services/biometric_service.dart';
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
  Future<bool> isBiometricEnabled() => _storageService.isBiometricEnabled();
  Future<bool> isBiometricsAvailable() =>
      _biometricService.isBiometricsAvailable();
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
    if (panicPin.length < 4) {
      throw AuthException(AppLocalizations.of(context)!.pinMinLength);
    }
    final isReal = await _storageService.checkMasterPin(panicPin);
    if (isReal) {
      throw AuthException(AppLocalizations.of(context)!.panicPinSameAsMaster);
    }
    await _storageService.setPanicPin(panicPin);
  }

  Future<bool> biometricLogin({
    required BuildContext context,
    required PasswordProvider provider,
  }) async {
    final authenticated = await _biometricService.authenticate(
      localizedReason: AppLocalizations.of(context)!.biometricPrompt,
    );
    if (!authenticated) {
      return false;
    }

    final pin = await _promptForPin(context);
    if (pin == null) {
      return false;
    }

    final isValid = await _storageService.checkMasterPin(pin);
    if (!isValid) {
      _showSnack(context, AppLocalizations.of(context)!.incorrectPin);
      return false;
    }

    await _storageService.setSessionKeyFromPin(pin);
    provider.exitPanicMode();
    return true;
  }

  Future<String?> _promptForPin(BuildContext context) async {
    final controller = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    try {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.enterPin),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: "••••••",
              counterText: "",
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel)),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(loc.confirm),
            ),
          ],
        ),
      );
    } finally {
      controller.text = '';
      controller.dispose();
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class BackupFacade {
  BackupFacade({BackupService? backupService})
      : _backupService = backupService ?? BackupService();

  final BackupService _backupService;

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
  Timer? _clipboardTimer;
  String? _lastCopiedPassword;

  void copyPasswordToClipboard({
    required BuildContext context,
    required String password,
    required String title,
  }) {
    final loc = AppLocalizations.of(context)!;
    Clipboard.setData(ClipboardData(text: password));
    _lastCopiedPassword = password;
    _clipboardTimer?.cancel();
    _clipboardTimer = Timer(const Duration(seconds: 30), () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == _lastCopiedPassword) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${loc.copiedPassword(title)} ${loc.clipboardWillClear}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void dispose() {
    _clipboardTimer?.cancel();
  }

  void handleLifecycleState(AppLifecycleState state) {
    // --- KRİTİK DÜZELTME BURADA ---
    // ScreenProtector sadece Android ve iOS'ta çalışır.
    // Windows'ta bu kodu atlamazsak uygulama çöker.
    if (Platform.isAndroid || Platform.isIOS) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        //ScreenProtector.protectDataLeakageWithBlur();
      } else if (state == AppLifecycleState.resumed) {
        //ScreenProtector.protectDataLeakageWithBlurOff();
      }
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
}
