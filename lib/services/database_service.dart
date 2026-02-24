import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../models/password_model.dart';
import 'field_cipher_service.dart';
import 'secure_storage_service.dart';

typedef DatabaseOpenOverride = Future<Database> Function({
  required String path,
  required String password,
});

typedef AppDirectoryProvider = Future<Directory> Function();

class DatabaseService {
  DatabaseService({
    SecureStorageService? secureStorage,
    FieldCipherService? fieldCipher,
    DatabaseOpenOverride? databaseOpenOverride,
    AppDirectoryProvider? appDirectoryProvider,
  })  : _secureStorage = secureStorage ?? SecureStorageService(),
        _fieldCipher = fieldCipher ?? FieldCipherService.instance,
        _databaseOpenOverride = databaseOpenOverride,
        _appDirectoryProvider = appDirectoryProvider;

  static const String _databaseFileName = 'onerule_vault.db';
  static const String _tableName = 'passwords';
  static const String _legacyHiveBoxName = 'passwords';

  final SecureStorageService _secureStorage;
  final FieldCipherService _fieldCipher;
  final DatabaseOpenOverride? _databaseOpenOverride;
  final AppDirectoryProvider? _appDirectoryProvider;

  Database? _db;
  List<PasswordModel> _cachedRawModels = <PasswordModel>[];

  Future<void> init() async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    _db = await _openEncryptedDatabase(sessionKey);

    await _migrateLegacyHiveIfNeeded(sessionKey);
    await _refreshCache();
    await _migrateToCurrentCipherEnvelopeIfNeeded(sessionKey);
    await _refreshCache();
  }

  List<PasswordModel> getAllPasswords() {
    return List<PasswordModel>.from(_cachedRawModels);
  }

  Future<List<PasswordModel>> getAllPasswordsDecrypted() async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final raw = await _fetchAllRaw();
    final results = <PasswordModel>[];
    for (final model in raw) {
      try {
        results.add(await _decryptModel(model, sessionKey));
      } on FieldCipherException catch (e) {
        throw VaultDataIntegrityException(
          'Failed to decrypt vault entry ${model.id}: ${e.message}',
        );
      }
    }
    return results;
  }

  Future<PasswordModel> getPasswordDecrypted(String id) async {
    final row = await _databaseOrThrow().query(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object>[id],
      limit: 1,
    );
    if (row.isEmpty) {
      throw StateError('Record $id not found');
    }
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final model = _rowToModel(row.first);
    try {
      return _decryptModel(model, sessionKey);
    } on FieldCipherException catch (e) {
      throw VaultDataIntegrityException(
        'Failed to decrypt vault entry ${model.id}: ${e.message}',
      );
    }
  }

  Future<void> addPassword(PasswordModel password) async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final encrypted = await _encryptModel(password, sessionKey);
    await _databaseOrThrow().insert(
      _tableName,
      _modelToRow(encrypted),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedRawModels = <PasswordModel>[
      encrypted,
      ..._cachedRawModels.where((item) => item.id != encrypted.id),
    ];
  }

  Future<void> deletePassword(String id) async {
    await _databaseOrThrow().delete(
      _tableName,
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
    _cachedRawModels = _cachedRawModels.where((item) => item.id != id).toList();
  }

  Future<void> updatePassword(PasswordModel password) async {
    final sessionKey = _secureStorage.getSessionKeyOrThrow();
    final encrypted = await _encryptModel(password, sessionKey);
    await _databaseOrThrow().update(
      _tableName,
      _modelToRow(encrypted),
      where: 'id = ?',
      whereArgs: <Object>[encrypted.id],
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _cachedRawModels = <PasswordModel>[
      for (final item in _cachedRawModels)
        if (item.id == encrypted.id) encrypted else item,
    ];
  }

  Future<void> deleteAllPasswords() async {
    await _databaseOrThrow().delete(_tableName);
    _cachedRawModels = <PasswordModel>[];
  }

  Future<void> reencryptBox(List<int> newKey) async {
    final database = _databaseOrThrow();
    final oldSessionKey = _secureStorage.getSessionKeyOrThrow();
    final rows = await _fetchAllRaw();

    final decryptedItems = <PasswordModel>[];
    for (final model in rows) {
      decryptedItems.add(await _decryptModel(model, oldSessionKey));
    }

    await database.execute(
      "PRAGMA rekey = '${_escapeSqlString(_sqlCipherPasswordFromKey(newKey))}'",
    );

    final batch = database.batch();
    for (final item in decryptedItems) {
      final encrypted = await _encryptModel(item, newKey);
      batch.update(
        _tableName,
        _modelToRow(encrypted),
        where: 'id = ?',
        whereArgs: <Object>[encrypted.id],
      );
    }
    await batch.commit(noResult: true);

    await _refreshCache();
  }

  Future<void> close() async {
    final database = _db;
    _db = null;
    if (database != null) {
      await database.close();
    }
  }

  @visibleForTesting
  Future<void> migrateToGcmIfNeededForTesting(List<int> sessionKey) {
    return _migrateToCurrentCipherEnvelopeIfNeeded(sessionKey);
  }

  Future<Database> _openEncryptedDatabase(List<int> sessionKey) async {
    final directory = await _getApplicationDirectory();
    final dbPath =
        '${directory.path}${Platform.pathSeparator}$_databaseFileName';
    final password = _sqlCipherPasswordFromKey(sessionKey);

    final databaseOpenOverride = _databaseOpenOverride;
    if (databaseOpenOverride != null) {
      final database = await databaseOpenOverride(
        path: dbPath,
        password: password,
      );
      await _createSchema(database);
      return database;
    }

    return openDatabase(
      dbPath,
      password: password,
      version: 1,
      onCreate: (database, _) async {
        await _createSchema(database);
      },
      onOpen: (database) async => _createSchema(database),
    );
  }

  Future<void> _createSchema(Database database) async {
    await database.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        username TEXT NOT NULL,
        password TEXT NOT NULL,
        url TEXT,
        createdDate TEXT NOT NULL,
        lastModified TEXT,
        category TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateLegacyHiveIfNeeded(List<int> sessionKey) async {
    if (await _secureStorage.hasCompletedSqlCipherMigration()) {
      return;
    }

    final records = await _readLegacyHiveRecords(sessionKey);
    if (records.isNotEmpty) {
      final database = _databaseOrThrow();
      final batch = database.batch();
      for (final record in records) {
        batch.insert(
          _tableName,
          _modelToRow(record),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    }

    await _secureStorage.setSqlCipherMigrationCompleted();
  }

  Future<List<PasswordModel>> _readLegacyHiveRecords(
      List<int> sessionKey) async {
    final appDir = await _getApplicationDirectory();
    final hivePath = appDir.path;

    if (!await Hive.boxExists(_legacyHiveBoxName, path: hivePath)) {
      return <PasswordModel>[];
    }

    Hive.init(hivePath);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PasswordModelAdapter());
    }

    final legacyKey = await _secureStorage.getLegacyEncryptionKey();
    final keyCandidates = <List<int>>[
      sessionKey,
      if (legacyKey != null) legacyKey,
    ];

    Box<PasswordModel>? box;
    List<PasswordModel> records = <PasswordModel>[];
    for (final key in keyCandidates) {
      try {
        box = await Hive.openBox<PasswordModel>(
          _legacyHiveBoxName,
          encryptionCipher: HiveAesCipher(key),
        );
        records = box.values.toList();
        break;
      } catch (_) {
        if (Hive.isBoxOpen(_legacyHiveBoxName)) {
          await Hive.box<PasswordModel>(_legacyHiveBoxName).close();
        }
      }
    }

    if (box != null && box.isOpen) {
      await box.close();
      await Hive.deleteBoxFromDisk(_legacyHiveBoxName, path: hivePath);
      await _secureStorage.removeLegacyEncryptionKey();
    }

    return records;
  }

  Future<void> _refreshCache() async {
    _cachedRawModels = await _fetchAllRaw();
  }

  Future<List<PasswordModel>> _fetchAllRaw() async {
    final rows = await _databaseOrThrow().query(_tableName);
    return rows.map(_rowToModel).toList();
  }

  Future<PasswordModel> _encryptModel(
    PasswordModel model,
    List<int> sessionKey,
  ) async {
    if (_fieldCipher.isCurrentEnvelope(model.password)) {
      return model;
    }

    final sourcePassword = _fieldCipher.looksEncrypted(model.password)
        ? await _fieldCipher.decrypt(model.password, sessionKey)
        : model.password;
    final encryptedPassword =
        await _fieldCipher.encrypt(sourcePassword, sessionKey);

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

  Future<PasswordModel> _decryptModel(
    PasswordModel model,
    List<int> sessionKey,
  ) async {
    if (!_fieldCipher.looksEncrypted(model.password)) {
      return model;
    }

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
  }

  Future<void> _migrateToCurrentCipherEnvelopeIfNeeded(
      List<int> sessionKey) async {
    if (kDebugMode) {
      debugPrint('[DatabaseService] Starting field cipher envelope migration');
    }

    final rows = await _fetchAllRaw();
    var migrated = 0;
    for (final model in rows) {
      try {
        final migratedPassword =
            await _fieldCipher.migrateToCurrentEnvelopeIfNeeded(
          model.password,
          sessionKey,
        );
        if (migratedPassword == null) {
          continue;
        }

        final updated = PasswordModel(
          id: model.id,
          title: model.title,
          username: model.username,
          password: migratedPassword,
          url: model.url,
          createdDate: model.createdDate,
          lastModified: model.lastModified,
          category: model.category,
        );
        await _databaseOrThrow().transaction((txn) async {
          final updatedRows = await txn.update(
            _tableName,
            _modelToRow(updated),
            where: 'id = ?',
            whereArgs: <Object>[updated.id],
          );
          if (updatedRows != 1) {
            throw StateError(
              'Atomic migration failed for ${updated.id}. Expected 1 row update, got $updatedRows.',
            );
          }
        });
        migrated++;
      } on FieldCipherException catch (e) {
        throw VaultDataIntegrityException(
          'Failed to migrate vault entry ${model.id}: ${e.message}',
        );
      } catch (e) {
        throw VaultDataIntegrityException(
          'Unexpected migration error for vault entry ${model.id}: $e',
        );
      }
    }

    if (kDebugMode && migrated > 0) {
      debugPrint(
        '[DatabaseService] Field cipher envelope migration done. Records migrated: $migrated',
      );
    }
  }

  Map<String, Object?> _modelToRow(PasswordModel model) {
    return <String, Object?>{
      'id': model.id,
      'title': model.title,
      'username': model.username,
      'password': model.password,
      'url': model.url,
      'createdDate': model.createdDate.toUtc().toIso8601String(),
      'lastModified': model.lastModified?.toUtc().toIso8601String(),
      'category': model.category,
    };
  }

  PasswordModel _rowToModel(Map<String, Object?> row) {
    final createdDateRaw = row['createdDate'] as String? ?? '';
    final lastModifiedRaw = row['lastModified'] as String?;

    return PasswordModel(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      username: row['username'] as String? ?? '',
      password: row['password'] as String? ?? '',
      url: row['url'] as String?,
      createdDate: DateTime.tryParse(createdDateRaw)?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      lastModified: lastModifiedRaw == null
          ? null
          : DateTime.tryParse(lastModifiedRaw)?.toLocal(),
      category: row['category'] as String? ?? 'General',
    );
  }

  String _sqlCipherPasswordFromKey(List<int> key) {
    return base64UrlEncode(key);
  }

  String _escapeSqlString(String value) {
    return value.replaceAll("'", "''");
  }

  Database _databaseOrThrow() {
    final database = _db;
    if (database == null) {
      throw StateError('DatabaseService.init() must be called before use.');
    }
    return database;
  }

  Future<Directory> _getApplicationDirectory() async {
    final provider = _appDirectoryProvider;
    if (provider != null) {
      return provider();
    }
    return getApplicationDocumentsDirectory();
  }
}

class VaultDataIntegrityException implements Exception {
  const VaultDataIntegrityException(this.message);

  final String message;

  @override
  String toString() => 'VaultDataIntegrityException: $message';
}
