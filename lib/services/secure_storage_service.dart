import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyBiometricEnabled = 'biometricEnabled';
  static const String _keyHiveKey = 'hiveEncryptionKey';
  static const String _keyMasterPin = 'masterPin';
  static const String _keyEncryptionKey = 'encryptionKey';
  static const String _keyMasterPinHash = 'masterPinHash';
  static const String _keyMasterPinSalt = 'masterPinSalt';
  static const String _keyPanicPinHash = 'panicPinHash';
  static const String _keyPanicPinSalt = 'panicPinSalt';
  static const String _keyHiveSalt = 'hiveSalt';
  static const String _keyLegacyJsonImportDone = 'legacyJsonImportDone';
  static List<int>? _sessionKey;

  Future<void> setBiometricEnabled(bool enabled) async {
    await _secureStorage.write(
        key: _keyBiometricEnabled, value: enabled.toString());
  }

  List<int> getSessionKeyOrThrow() {
    final key = _sessionKey;
    if (key == null) {
      throw StateError('Session encryption key is not set.');
    }
    return List<int>.from(key);
  }

  Future<void> setSessionKeyFromPin(String pin) async {
    _sessionKey = await deriveHiveKeyFromPin(pin);
  }

  void setSessionKey(List<int> key) {
    _sessionKey = List<int>.from(key);
  }

  void clearSessionKey() {
    _sessionKey = null;
  }

  Future<bool> isBiometricEnabled() async {
    String? value = await _secureStorage.read(key: _keyBiometricEnabled);
    return value == 'true';
  }

  // --- HIVE ŞİFRELEME ANAHTARI (ESKİ KISIM) ---
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

  // --- YENİ: MASTER PIN YÖNETİMİ ---

  // Kullanıcının daha önce PIN oluşturup oluşturmadığını kontrol et
  Future<bool> hasMasterPin() async {
    final hash = await _secureStorage.read(key: _keyMasterPinHash);
    if (hash != null) return true;
    String? legacyPin = await _secureStorage.read(key: _keyMasterPin);
    return legacyPin != null;
  }

  // Girilen PIN doğru mu?
  Future<bool> checkMasterPin(String inputPin) async {
    final storedHash = await _secureStorage.read(key: _keyMasterPinHash);
    final storedSalt = await _secureStorage.read(key: _keyMasterPinSalt);

    if (storedHash != null && storedSalt != null) {
      final derived = await _deriveKey(
        inputPin,
        base64Url.decode(storedSalt),
        length: 32,
      );
      return _constantTimeEquals(
        base64Url.decode(storedHash),
        derived,
      );
    }

    // Legacy fallback: düz PIN ile kontrol ve migrasyon
    String? legacyPin = await _secureStorage.read(key: _keyMasterPin);
    final isValid = legacyPin == inputPin;
    if (isValid) {
      await _migrateLegacyMasterPin(inputPin);
    }
    return isValid;
  }

  // Yeni PIN kaydet
  Future<void> setMasterPin(String newPin,
      {List<int>? derivedHiveKey}) async {
    await _storeMasterPinHash(newPin);

    final key = derivedHiveKey ??
        await deriveHiveKeyFromPin(newPin, rotateSalt: true);
    setSessionKey(key);
  }

  static const String _keyPanicPin = 'panicPin';

  // Panik Pini Ayarla
  Future<void> setPanicPin(String pin) async {
    final salt = _generateSalt();
    final hash = await _deriveKey(pin, salt, length: 32);
    await _secureStorage.write(
      key: _keyPanicPinSalt,
      value: base64Url.encode(salt),
    );
    await _secureStorage.write(
      key: _keyPanicPinHash,
      value: base64Url.encode(hash),
    );
    await _secureStorage.delete(key: _keyPanicPin);
  }

  // Panik Pini Kontrol Et
  Future<bool> checkPanicPin(String pin) async {
    final storedHash = await _secureStorage.read(key: _keyPanicPinHash);
    final storedSalt = await _secureStorage.read(key: _keyPanicPinSalt);

    if (storedHash != null && storedSalt != null) {
      final derived = await _deriveKey(
        pin,
        base64Url.decode(storedSalt),
        length: 32,
      );
      return _constantTimeEquals(
        base64Url.decode(storedHash),
        derived,
      );
    }

    // Legacy fallback: düz PIN ile kontrol ve migrasyon
    String? legacyPin = await _secureStorage.read(key: _keyPanicPin);
    final isValid = legacyPin == pin;
    if (isValid) {
      await _migrateLegacyPanicPin(pin);
    }
    return isValid;
  }

  // Panik Pini Var mı?
  Future<bool> hasPanicPin() async {
    final hash = await _secureStorage.read(key: _keyPanicPinHash);
    if (hash != null) return true;
    String? pin = await _secureStorage.read(key: _keyPanicPin);
    return pin != null;
  }

  // Panik Pinini Sil (İsteğe bağlı)
  Future<void> removePanicPin() async {
    await _secureStorage.delete(key: _keyPanicPin);
    await _secureStorage.delete(key: _keyPanicPinHash);
    await _secureStorage.delete(key: _keyPanicPinSalt);
  }

  Future<bool> hasCompletedLegacyJsonImport() async {
    final value = await _secureStorage.read(key: _keyLegacyJsonImportDone);
    return value == 'true';
  }

  Future<void> setLegacyJsonImportCompleted() async {
    await _secureStorage.write(key: _keyLegacyJsonImportDone, value: 'true');
  }

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

    return _deriveKey(pin, base64Url.decode(saltString), length: 32);
  }

  Future<void> _migrateLegacyMasterPin(String pin) async {
    await _storeMasterPinHash(pin);
  }

  Future<void> _migrateLegacyPanicPin(String pin) async {
    await setPanicPin(pin);
  }

  Future<void> _storeMasterPinHash(String pin) async {
    final salt = _generateSalt();
    final hash = await _deriveKey(pin, salt, length: 32);
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

  List<int> _generateSalt([int length = 16]) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  Future<List<int>> _deriveKey(String pin, List<int> salt,
      {int length = 32}) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 200000,
      bits: length * 8,
    );
    final secretKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return secretKey.extractBytes();
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
