import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/password_model.dart';
import 'autofill_mvp_service.dart';
import 'field_cipher_service.dart';
import 'secure_storage_service.dart';

abstract class CredentialProvider {
  Future<void> onVaultUnlocked(List<PasswordModel> entries);
  Future<void> onVaultLocked();
  Future<bool> isSupported();
  Future<bool> isEnabled();
  Future<void> openSetup();
}

class PlatformCredentialProvider implements CredentialProvider {
  PlatformCredentialProvider({CredentialProvider? delegate})
      : _delegate = delegate ?? _defaultDelegate();

  final CredentialProvider _delegate;

  static CredentialProvider _defaultDelegate() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidCredentialProvider();
    }
    return const NoopCredentialProvider();
  }

  @override
  Future<void> onVaultUnlocked(List<PasswordModel> entries) {
    return _delegate.onVaultUnlocked(entries);
  }

  @override
  Future<void> onVaultLocked() {
    return _delegate.onVaultLocked();
  }

  @override
  Future<bool> isSupported() {
    return _delegate.isSupported();
  }

  @override
  Future<bool> isEnabled() {
    return _delegate.isEnabled();
  }

  @override
  Future<void> openSetup() {
    return _delegate.openSetup();
  }
}

class AndroidCredentialProvider implements CredentialProvider {
  AndroidCredentialProvider({
    AutofillMvpService? autofillService,
    SecureStorageService? secureStorageService,
    FieldCipherService? fieldCipherService,
  })  : _autofillService = autofillService ?? AutofillMvpService(),
        _secureStorageService = secureStorageService ?? SecureStorageService(),
        _fieldCipherService = fieldCipherService ?? FieldCipherService.instance;

  final AutofillMvpService _autofillService;
  final SecureStorageService _secureStorageService;
  final FieldCipherService _fieldCipherService;

  static const Map<String, List<String>> _domainPackageHints =
      <String, List<String>>{
    'google.com': <String>['com.android.chrome', 'com.google.android.gm'],
    'facebook.com': <String>['com.facebook.katana'],
    'instagram.com': <String>['com.instagram.android'],
    'reddit.com': <String>['com.reddit.frontpage'],
    'discord.com': <String>['com.discord'],
    'x.com': <String>['com.twitter.android'],
    'twitter.com': <String>['com.twitter.android'],
    'spotify.com': <String>['com.spotify.music'],
    'netflix.com': <String>['com.netflix.mediaclient'],
  };

  @override
  Future<void> onVaultUnlocked(List<PasswordModel> entries) async {
    try {
      final state = await _autofillService.availability();
      if (state != AutofillMvpAvailability.available) {
        return;
      }

      final sessionKey = _secureStorageService.getSessionKeyOrThrow();
      final payload = await _buildEncryptedSnapshot(entries, sessionKey);
      final sessionKeyBase64 = base64UrlEncode(sessionKey);

      await _autofillService.syncCredentialSnapshot(
        payload: payload,
        sessionKeyBase64: sessionKeyBase64,
      );
    } on PlatformException catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[CredentialProvider] Autofill snapshot sync failed (${error.code}).',
        );
      }
    } on MissingPluginException {
      // No-op for non-Android test environments.
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
            '[CredentialProvider] Autofill snapshot sync failed: $error');
      }
    }
  }

  @override
  Future<void> onVaultLocked() async {
    try {
      await _autofillService.clearSessionKey();
    } on PlatformException catch (_) {
      // Ignore lock cleanup errors.
    } on MissingPluginException {
      // Ignore in tests.
    }
  }

  @override
  Future<bool> isSupported() async {
    try {
      return (await _autofillService.availability()) ==
          AutofillMvpAvailability.available;
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> isEnabled() async {
    try {
      return await _autofillService.isEnabledInSystem();
    } on PlatformException catch (_) {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openSetup() async {
    await _autofillService.openSettingsIfAvailable();
  }

  Future<String> _buildEncryptedSnapshot(
    List<PasswordModel> entries,
    List<int> sessionKey,
  ) async {
    final credentials = <Map<String, Object?>>[];
    for (final entry in entries) {
      final passwordPlaintext =
          _fieldCipherService.looksEncrypted(entry.password)
              ? await _fieldCipherService.decrypt(entry.password, sessionKey)
              : entry.password;
      final displayNamePlaintext = entry.title;
      final usernamePlaintext = entry.username;

      final domains = _extractDomains(entry.url);
      final packageHints = _packageHintsForDomains(domains);

      credentials.add(
        <String, Object?>{
          'id': entry.id,
          'displayNameEnc': await _fieldCipherService.encrypt(
              displayNamePlaintext, sessionKey),
          'usernameEnc':
              await _fieldCipherService.encrypt(usernamePlaintext, sessionKey),
          'passwordEnc':
              await _fieldCipherService.encrypt(passwordPlaintext, sessionKey),
          'domains': domains,
          'packages': packageHints,
        },
      );
    }

    return jsonEncode(
      <String, Object?>{
        'schemaVersion': 1,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'credentials': credentials,
      },
    );
  }

  List<String> _extractDomains(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return const <String>[];

    Uri? parsed = Uri.tryParse(rawUrl.trim());
    parsed ??= Uri.tryParse('https://${rawUrl.trim()}');
    final host = parsed?.host.toLowerCase().trim();
    if (host == null || host.isEmpty) return const <String>[];
    final normalized = host.startsWith('www.') ? host.substring(4) : host;
    return <String>[normalized];
  }

  List<String> _packageHintsForDomains(List<String> domains) {
    final result = <String>{};
    for (final domain in domains) {
      final exact = _domainPackageHints[domain] ?? const <String>[];
      result.addAll(exact);
      for (final entry in _domainPackageHints.entries) {
        if (domain.endsWith('.${entry.key}') ||
            entry.key.endsWith('.$domain')) {
          result.addAll(entry.value);
        }
      }
    }
    return result.toList(growable: false);
  }
}

class NoopCredentialProvider implements CredentialProvider {
  const NoopCredentialProvider();

  @override
  Future<void> onVaultUnlocked(List<PasswordModel> entries) async {}

  @override
  Future<void> onVaultLocked() async {}

  @override
  Future<bool> isSupported() async => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> openSetup() async {}
}
