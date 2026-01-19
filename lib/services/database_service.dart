import 'package:hive_flutter/hive_flutter.dart';
import '../models/password_model.dart';
import 'secure_storage_service.dart';

class DatabaseService {
  // Kutu ismi sabit olsun
  static const String _boxName = 'passwords';

  // Hive Kutusu
  late Box<PasswordModel> _box;

  final SecureStorageService _secureStorage = SecureStorageService();

  /// Veritabanını şifreli olarak başlatır
  Future<void> init() async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final legacyKey = await _secureStorage.getLegacyEncryptionKey();

    if (legacyKey != null) {
      _box = await Hive.openBox<PasswordModel>(
        _boxName,
        encryptionCipher: HiveAesCipher(legacyKey),
      );

      if (!_isSameKey(legacyKey, sessionKey)) {
        await reencryptBox(sessionKey);
      }

      await _secureStorage.removeLegacyEncryptionKey();
      return;
    }

    _box = await Hive.openBox<PasswordModel>(
      _boxName,
      encryptionCipher: HiveAesCipher(sessionKey),
    );
  }

  /// Tüm şifreleri getir
  List<PasswordModel> getAllPasswords() {
    return _box.values.toList();
  }

  /// Yeni şifre ekle
  Future<void> addPassword(PasswordModel password) async {
    await _box.put(password.id, password);
  }

  /// Şifre sil
  Future<void> deletePassword(String id) async {
    await _box.delete(id);
  }

  /// Şifre güncelle
  Future<void> updatePassword(PasswordModel password) async {
    await _box.put(password.id, password);
  }

  /// Tüm verileri sil (Ayarlardaki "Delete All" için)
  Future<void> deleteAllPasswords() async {
    await _box.clear();
  }

  /// Veritabanını kapat
  Future<void> close() async {
    await _box.close();
  }

  /// Şifreleme anahtarını değiştir (PIN değişimi için)
  Future<void> reencryptBox(List<int> newKey) async {
    final items = _box.values.toList();
    await _box.close();
    await Hive.deleteBoxFromDisk(_boxName);
    _box = await Hive.openBox<PasswordModel>(
      _boxName,
      encryptionCipher: HiveAesCipher(newKey),
    );
    for (final item in items) {
      await _box.put(item.id, item);
    }
  }

  bool _isSameKey(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
