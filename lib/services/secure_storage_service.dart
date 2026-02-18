import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart'; // Compute için gerekli
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal()
      : _secureStorage = const FlutterSecureStorage(
          aOptions: AndroidOptions(
            encryptedSharedPreferences: true,
          ),
        );

  SecureStorageService.forTesting({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
            );

  final FlutterSecureStorage _secureStorage;

  // --- SABİTLER ---
  static const String _keyBiometricEnabled = 'biometricEnabled';
  static const String _keyHiveKey = 'hiveEncryptionKey';
  static const String _keyMasterPin = 'masterPin';
  static const String _keyEncryptionKey = 'encryptionKey';
  static const String _keyMasterPinHash = 'masterPinHash';
  static const String _keyMasterPinSalt = 'masterPinSalt';
  static const String _keyPanicPin = 'panicPin'; // EKLENDİ
  static const String _keyPanicPinHash = 'panicPinHash';
  static const String _keyPanicPinSalt = 'panicPinSalt';
  static const String _keyHiveSalt = 'hiveSalt';
  static const String _keyLegacyJsonImportDone = 'legacyJsonImportDone';
  static const String _keyLastBackupAt = 'lastBackupAt';

  static List<int>? _sessionKey;

  // --- Session Yönetimi ---
  List<int> getSessionKeyOrThrow() {
    final key = _sessionKey;
    if (key == null) {
      throw StateError('Session encryption key is not set.');
    }
    return List<int>.from(key);
  }

  Future<void> setSessionKeyFromPin(String pin) async {
    // İşlemi arka planda (Isolate) yap
    final key = await deriveHiveKeyFromPin(pin);
    setSessionKey(key);
    await _storeBiometricUnlockKey(key);
  }

  void setSessionKey(List<int> key) {
    _sessionKey = List<int>.from(key);
  }

  void clearSessionKey() {
    _sessionKey = null;
  }

  // --- Biyometrik Ayarlar ---
  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
        key: _keyBiometricEnabled, value: enabled.toString());
  }

  Future<bool> isBiometricEnabled() async {
    String? value = await _secureStorage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // --- HIVE ŞİFRELEME ---
  Future<List<int>> getHiveEncryptionKey() async {
    String? keyString = await _secureStorage.read(key: _keyHiveKey);
    if (keyString == null) {
      final List<int> key = Hive.generateSecureKey();
      await _secureStorage.write(key: _keyHiveKey, value: base64UrlEncode(key));
      return key;
    } else {
      return base64Url.decode(keyString);
    }
  }

  // --- PIN KONTROLLERİ ---
  Future<bool> hasMasterPin() async {
    final hash = await _secureStorage.read(key: _keyMasterPinHash);
    if (hash != null) return true;
    String? legacyPin = await _secureStorage.read(key: _keyMasterPin);
    return legacyPin != null;
  }

  Future<bool> checkMasterPin(String inputPin) async {
    final storedHash = await _secureStorage.read(key: _keyMasterPinHash);
    final storedSalt = await _secureStorage.read(key: _keyMasterPinSalt);

    if (storedHash != null && storedSalt != null) {
      // Ağır işlemi arka plana atıyoruz
      final derived = await _computeDeriveKey(
        inputPin,
        base64Url.decode(storedSalt),
      );

      return _constantTimeEquals(
        base64Url.decode(storedHash),
        derived,
      );
    }

    // Legacy fallback
    String? legacyPin = await _secureStorage.read(key: _keyMasterPin);
    final isValid = legacyPin == inputPin;
    if (isValid) {
      await _migrateLegacyMasterPin(inputPin);
    }
    return isValid;
  }

  Future<void> setMasterPin(String newPin, {List<int>? derivedHiveKey}) async {
    await _storeMasterPinHash(newPin);
    final key =
        derivedHiveKey ?? await deriveHiveKeyFromPin(newPin, rotateSalt: true);
    setSessionKey(key);
    await _storeBiometricUnlockKey(key);
  }

  Future<bool> restoreSessionKeyForBiometric() async {
    final keyString = await _secureStorage.read(key: _keyHiveKey);
    if (keyString == null || keyString.isEmpty) {
      return false;
    }

    try {
      final decoded = base64Url.decode(keyString);
      setSessionKey(decoded);
      return true;
    } catch (_) {
      return false;
    }
  }

  // --- PANİK PIN ---
  Future<void> setPanicPin(String pin) async {
    final salt = _generateSalt();
    // Arka plan işlemi
    final hash = await _computeDeriveKey(pin, salt);

    await _secureStorage.write(
        key: _keyPanicPinSalt, value: base64Url.encode(salt));
    await _secureStorage.write(
        key: _keyPanicPinHash, value: base64Url.encode(hash));
    // Legacy temizliği
    await _secureStorage.delete(key: _keyPanicPin);
  }

  Future<bool> checkPanicPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _keyPanicPinHash);
    final storedSalt = await _secureStorage.read(key: _keyPanicPinSalt);

    if (storedHash != null && storedSalt != null) {
      // Arka plan işlemi
      final derived =
          await _computeDeriveKey(pin, base64Url.decode(storedSalt));

      return _constantTimeEquals(
        base64Url.decode(storedHash),
        derived,
      );
    }

    // Legacy fallback
    String? legacyPin = await _secureStorage.read(key: _keyPanicPin);
    return legacyPin == pin;
  }

  Future<bool> hasPanicPin() async {
    final hash = await _secureStorage.read(key: _keyPanicPinHash);
    if (hash != null) return true;

    // Legacy check
    String? legacyPin = await _secureStorage.read(key: _keyPanicPin);
    return legacyPin != null;
  }

  Future<void> removePanicPin() async {
    await _secureStorage.delete(key: _keyPanicPinHash);
    await _secureStorage.delete(key: _keyPanicPinSalt);
    // Legacy temizliği
    await _secureStorage.delete(key: _keyPanicPin);
  }

  // --- LEGACY / MIGRATION METODLARI (EKLENDİ) ---

  Future<List<int>?> getLegacyEncryptionKey() async {
    final storedKey = await _secureStorage.read(key: _keyEncryptionKey);
    if (storedKey == null) {
      return null;
    }
    return base64Url.decode(storedKey);
  }

  Future<void> removeLegacyEncryptionKey() async {
    await _secureStorage.delete(key: _keyEncryptionKey);
  }

  Future<bool> hasCompletedLegacyJsonImport() async {
    final value = await _secureStorage.read(key: _keyLegacyJsonImportDone);
    return value == 'true';
  }

  Future<void> setLegacyJsonImportCompleted() async {
    await _secureStorage.write(key: _keyLegacyJsonImportDone, value: 'true');
  }

  Future<void> setLastBackupAt(DateTime dateTime) async {
    await _secureStorage.write(
      key: _keyLastBackupAt,
      value: dateTime.toUtc().toIso8601String(),
    );
  }

  Future<DateTime?> getLastBackupAt() async {
    final value = await _secureStorage.read(key: _keyLastBackupAt);
    if (value == null || value.isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }

  // --- YARDIMCI METODLAR ---

  Future<List<int>> deriveHiveKeyFromPin(String pin,
      {bool rotateSalt = false}) async {
    String? saltString = await _secureStorage.read(key: _keyHiveSalt);

    if (rotateSalt || saltString == null) {
      final salt = _generateSalt();
      await _secureStorage.write(
        key: _keyHiveSalt,
        value: base64Url.encode(salt),
      );
      saltString = base64Url.encode(salt);
    }

    // ARKA PLAN (ISOLATE) KULLANIMI
    return _computeDeriveKey(pin, base64Url.decode(saltString));
  }

  // Isolate Wrapper
  Future<List<int>> _computeDeriveKey(String pin, List<int> salt) async {
    return await compute(_deriveKeyInternal, {'pin': pin, 'salt': salt});
  }

  Future<void> _storeMasterPinHash(String pin) async {
    final salt = _generateSalt();
    final hash = await _computeDeriveKey(pin, salt);
    await _secureStorage.write(
      key: _keyMasterPinSalt,
      value: base64Url.encode(salt),
    );
    await _secureStorage.write(
      key: _keyMasterPinHash,
      value: base64Url.encode(hash),
    );
    await _secureStorage.delete(key: _keyMasterPin);
  }

  Future<void> _migrateLegacyMasterPin(String pin) async {
    await _storeMasterPinHash(pin);
  }

  Future<void> _storeBiometricUnlockKey(List<int> key) async {
    await _secureStorage.write(
      key: _keyHiveKey,
      value: base64UrlEncode(key),
    );
  }

  List<int> _generateSalt([int length = 16]) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

// BU FONKSİYON CLASS DIŞINDA (TOP-LEVEL) OLMALIDIR
// Isolate (Arka plan iş parçacığı) sadece statik veya top-level fonksiyonları çalıştırabilir.
Future<List<int>> _deriveKeyInternal(Map<String, dynamic> args) async {
  final String pin = args['pin'];
  final List<int> salt = args['salt'];

  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256, // 32 bytes
  );

  final secretKey = await pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(pin)),
    nonce: salt,
  );

  return secretKey.extractBytes();
}
