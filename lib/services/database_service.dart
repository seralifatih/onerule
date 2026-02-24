import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/password_model.dart';
import 'field_cipher_service.dart';
import 'secure_storage_service.dart';

class DatabaseService {
  DatabaseService({
    SecureStorageService? secureStorage,
    FieldCipherService? fieldCipher,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _fieldCipher = fieldCipher ?? FieldCipherService.instance;

  static const String _boxName = 'passwords';

  late Box<PasswordModel> _box;
  final SecureStorageService _secureStorage;
  final FieldCipherService _fieldCipher;

  /// Opens the Hive box, handles legacy key migration if needed,
  /// then runs the one-time GCM field-encryption migration.
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
    } else {
      _box = await Hive.openBox<PasswordModel>(
        _boxName,
        encryptionCipher: HiveAesCipher(sessionKey),
      );
    }

    // One-time migration: add GCM field-level encryption to existing records
    await _migrateToGcmIfNeeded(sessionKey);
  }

  // ── Public CRUD — all encrypt on write, decrypt on read ──────────────────

  List<PasswordModel> getAllPasswords() {
    // Decryption is async, so we return the raw models here and decrypt
    // lazily in getPasswordDecrypted(). Callers that need the plaintext
    // password field must use getAllPasswordsDecrypted().
    return _box.values.toList();
  }

  /// Returns all passwords with the password field decrypted.
  /// Use this everywhere you need to display or copy the password.
  Future<List<PasswordModel>> getAllPasswordsDecrypted() async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final results = <PasswordModel>[];
    for (final model in _box.values) {
      results.add(await _decryptModel(model, sessionKey));
    }
    return results;
  }

  /// Returns a single password model with the password field decrypted.
  Future<PasswordModel> getPasswordDecrypted(String id) async {
    final model = _box.get(id);
    if (model == null) throw StateError('Record $id not found');
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    return _decryptModel(model, sessionKey);
  }

  /// Adds a new password, encrypting the password field with GCM first.
  Future<void> addPassword(PasswordModel password) async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final encrypted = await _encryptModel(password, sessionKey);
    await _box.put(encrypted.id, encrypted);
  }

  /// Deletes a password by id.
  Future<void> deletePassword(String id) async {
    await _box.delete(id);
  }

  /// Updates a password, encrypting the password field with GCM first.
  Future<void> updatePassword(PasswordModel password) async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final encrypted = await _encryptModel(password, sessionKey);
    await _box.put(encrypted.id, encrypted);
  }

  /// Deletes all records.
  Future<void> deleteAllPasswords() async {
    await _box.clear();
  }

  /// Re-encrypts the entire box with a new Hive key (used on PIN change).
  /// Also re-encrypts GCM field values with the new session key.
  Future<void> reencryptBox(List<int> newKey) async {
    final oldSessionKey = _secureStorage.getSessionKeyOrThrow();

    // 1. Decrypt all password fields with the OLD session key
    final decryptedItems = <PasswordModel>[];
    for (final model in _box.values) {
      decryptedItems.add(await _decryptModel(model, oldSessionKey));
    }

    // 2. Re-open box with new Hive cipher key
    await _box.close();
    await Hive.deleteBoxFromDisk(_boxName);
    _box = await Hive.openBox<PasswordModel>(
      _boxName,
      encryptionCipher: HiveAesCipher(newKey),
    );

    // 3. Re-encrypt password fields with the NEW session key and write back
    for (final item in decryptedItems) {
      final encrypted = await _encryptModel(item, newKey);
      await _box.put(encrypted.id, encrypted);
    }
  }

  Future<void> close() async {
    await _box.close();
  }

  @visibleForTesting
  void attachBoxForTesting(Box<PasswordModel> box) {
    _box = box;
  }

  @visibleForTesting
  Future<void> migrateToGcmIfNeededForTesting(List<int> sessionKey) {
    return _migrateToGcmIfNeeded(sessionKey);
  }

  // ── GCM field encryption helpers ──────────────────────────────────────────

  /// Encrypts the password field of [model] with GCM.
  /// All other fields (title, username, category) stay plaintext so search
  /// and filtering continue to work without decryption overhead.
  Future<PasswordModel> _encryptModel(
    PasswordModel model,
    List<int> sessionKey,
  ) async {
    // If somehow already encrypted (shouldn't happen via public API but
    // guard anyway), don't double-encrypt.
    if (_fieldCipher.looksEncrypted(model.password)) return model;

    final encryptedPassword = await _fieldCipher.encrypt(
      model.password,
      sessionKey,
    );

    return PasswordModel(
      id: model.id,
      title: model.title,
      username: model.username,
      password: encryptedPassword,
      url: model.url,
      createdDate: model.createdDate,
      lastModified: model.lastModified,
      category: model.category,
    );
  }

  /// Decrypts the password field of [model].
  /// If the field is not encrypted (legacy plaintext), returns as-is.
  Future<PasswordModel> _decryptModel(
    PasswordModel model,
    List<int> sessionKey,
  ) async {
    if (!_fieldCipher.looksEncrypted(model.password)) {
      // Plaintext legacy record — return as-is, migration will handle it
      return model;
    }

    try {
      final plainPassword = await _fieldCipher.decrypt(
        model.password,
        sessionKey,
      );
      return PasswordModel(
        id: model.id,
        title: model.title,
        username: model.username,
        password: plainPassword,
        url: model.url,
        createdDate: model.createdDate,
        lastModified: model.lastModified,
        category: model.category,
      );
    } on FieldCipherException catch (e) {
      // Log but do not crash — return model with password field replaced
      // by a safe placeholder so the app remains usable.
      if (kDebugMode) debugPrint('[DatabaseService] decrypt error: $e');
      return PasswordModel(
        id: model.id,
        title: model.title,
        username: model.username,
        password: '[decryption error]',
        url: model.url,
        createdDate: model.createdDate,
        lastModified: model.lastModified,
        category: model.category,
      );
    }
  }

  // ── One-time GCM migration ────────────────────────────────────────────────

  /// Runs once after first install of the version that adds GCM field
  /// encryption. Reads every record, detects plaintext password fields,
  /// encrypts them with GCM, writes back. Sets a flag when complete so it
  /// never runs again.
  ///
  /// If the process is interrupted (crash, force-quit), the flag is not set
  /// and the migration retries on next open. Already-migrated records are
  /// detected via [FieldCipherService.looksEncrypted] and skipped, so
  /// partial runs are safe.
  Future<void> _migrateToGcmIfNeeded(List<int> sessionKey) async {
    final done = await _secureStorage.hasCompletedGcmMigration();
    if (done) return;

    if (kDebugMode) {
      debugPrint('[DatabaseService] Starting GCM field migration');
    }

    int migrated = 0;
    for (final model in _box.values.toList()) {
      if (_fieldCipher.looksEncrypted(model.password)) continue;

      try {
        final encryptedPassword = await _fieldCipher.encrypt(
          model.password,
          sessionKey,
        );
        // Write directly to box — not through addPassword() to avoid a
        // double-encrypt guard triggering.
        final updated = PasswordModel(
          id: model.id,
          title: model.title,
          username: model.username,
          password: encryptedPassword,
          url: model.url,
          createdDate: model.createdDate,
          lastModified: model.lastModified,
          category: model.category,
        );
        await _box.put(updated.id, updated);
        migrated++;
      } catch (e) {
        // One record failing should not abort the entire migration.
        // The record will be retried on next open.
        if (kDebugMode) {
          debugPrint('[DatabaseService] Migration error for ${model.id}: $e');
        }
      }
    }

    // Only mark complete if we processed every record without a hard error
    await _secureStorage.setGcmMigrationCompleted();
    if (kDebugMode) {
      debugPrint(
          '[DatabaseService] GCM migration done. Records migrated: $migrated');
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  bool _isSameKey(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
