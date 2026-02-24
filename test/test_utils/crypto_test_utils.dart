import 'dart:io';
import 'dart:math';

import 'package:offline_pass_manager/services/secure_storage_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const String passwordsTableSchema = '''
  CREATE TABLE IF NOT EXISTS passwords (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    username TEXT NOT NULL,
    password TEXT NOT NULL,
    url TEXT,
    createdDate TEXT NOT NULL,
    lastModified TEXT,
    category TEXT NOT NULL
  )
''';

class DeterministicBytes {
  DeterministicBytes({int seed = 20260224}) : _random = Random(seed);

  final Random _random;

  List<int> next(int length) {
    return List<int>.generate(length, (_) => _random.nextInt(256));
  }
}

class TestSecureStorageService extends SecureStorageService {
  TestSecureStorageService(this._sessionKey) : super.forTesting();

  final List<int> _sessionKey;
  bool sqlCipherMigrationCompleted = true;

  @override
  List<int> getSessionKeyOrThrow() => List<int>.from(_sessionKey);

  @override
  Future<bool> hasCompletedSqlCipherMigration() async {
    return sqlCipherMigrationCompleted;
  }

  @override
  Future<void> setSqlCipherMigrationCompleted() async {
    sqlCipherMigrationCompleted = true;
  }

  @override
  Future<List<int>?> getLegacyEncryptionKey() async {
    return null;
  }

  @override
  Future<void> removeLegacyEncryptionKey() async {}
}

Future<Directory> createTempVaultDirectory(String name) {
  return Directory.systemTemp.createTemp('onerule_crypto_storage_$name');
}

Future<Database> openFfiDatabaseForTests({
  required String path,
  required String password,
}) async {
  final db = await databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      singleInstance: false,
    ),
  );
  // Password is intentionally unused in tests; production path still uses SQLCipher.
  await db.execute(passwordsTableSchema);
  return db;
}
