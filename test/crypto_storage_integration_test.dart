import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/services/backup_service.dart';
import 'package:offline_pass_manager/services/database_service.dart';
import 'package:offline_pass_manager/services/field_cipher_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'test_utils/crypto_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  final bytes = DeterministicBytes(seed: 77);

  Future<DatabaseService> buildService({
    required Directory tempDir,
    required List<int> sessionKey,
  }) async {
    final service = DatabaseService(
      secureStorage: TestSecureStorageService(sessionKey),
      databaseOpenOverride: openFfiDatabaseForTests,
      appDirectoryProvider: () async => tempDir,
    );
    await service.init();
    return service;
  }

  test('create vault -> add entry -> read back -> matches', () async {
    final tempDir = await createTempVaultDirectory('create_read');
    addTearDown(() async => tempDir.delete(recursive: true));

    final key = bytes.next(32);
    final db = await buildService(tempDir: tempDir, sessionKey: key);
    addTearDown(db.close);

    final entry = PasswordModel(
      id: 'entry-1',
      title: 'GitHub',
      username: 'dev@onerule.app',
      password: 'my-strong-secret',
      category: 'General',
      createdDate: DateTime(2026, 2, 24),
    );

    await db.addPassword(entry);
    final records = await db.getAllPasswordsDecrypted();

    expect(records, hasLength(1));
    expect(records.first.title, entry.title);
    expect(records.first.username, entry.username);
    expect(records.first.password, entry.password);
  });

  test('wrong PIN fails without leaking partial data', () async {
    final tempDir = await createTempVaultDirectory('wrong_pin');
    addTearDown(() async => tempDir.delete(recursive: true));

    final correctKey = bytes.next(32);
    final wrongKey = bytes.next(32);
    const secret = 'vault-secret-do-not-leak';

    final writer = await buildService(tempDir: tempDir, sessionKey: correctKey);
    await writer.addPassword(
      PasswordModel(
        id: 'entry-2',
        title: 'Email',
        username: 'user@example.com',
        password: secret,
        category: 'General',
        createdDate: DateTime(2026, 2, 24),
      ),
    );
    await writer.close();

    final reader = await buildService(tempDir: tempDir, sessionKey: wrongKey);
    addTearDown(reader.close);

    final raw = reader.getAllPasswords();
    expect(raw, hasLength(1));
    expect(raw.first.password, isNot(contains(secret)));

    try {
      await reader.getAllPasswordsDecrypted();
      fail('Expected wrong PIN/key to fail decryption.');
    } on VaultDataIntegrityException catch (e) {
      expect(e.message, contains('Failed to decrypt vault entry'));
      expect(e.message, isNot(contains(secret)));
    }
  });

  test('tampered ciphertext fails with authentication failure', () async {
    final tempDir = await createTempVaultDirectory('tampered_payload');
    addTearDown(() async => tempDir.delete(recursive: true));

    final key = bytes.next(32);
    final db = await buildService(tempDir: tempDir, sessionKey: key);
    await db.addPassword(
      PasswordModel(
        id: 'entry-3',
        title: 'Bank',
        username: 'me@bank.test',
        password: 'bank-secret',
        category: 'Finance',
        createdDate: DateTime(2026, 2, 24),
      ),
    );
    await db.close();

    final dbPath = _dbPath(tempDir);
    final rawDb = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    final rows =
        await rawDb.query('passwords', where: 'id = ?', whereArgs: ['entry-3']);
    expect(rows, hasLength(1));
    final payload = rows.first['password']! as String;
    final tampered = _tamperGcmEnvelopeTag(payload);
    await rawDb.update(
      'passwords',
      <String, Object?>{'password': tampered},
      where: 'id = ?',
      whereArgs: <Object>['entry-3'],
    );
    await rawDb.close();

    final reader = await buildService(tempDir: tempDir, sessionKey: key);
    addTearDown(reader.close);
    await expectLater(
      reader.getAllPasswordsDecrypted(),
      throwsA(
        isA<VaultDataIntegrityException>().having(
          (e) => e.message,
          'message',
          contains('Authentication failed'),
        ),
      ),
    );
  });

  test('migration test (legacy CBC -> current GCM envelope)', () async {
    final tempDir = await createTempVaultDirectory('cbc_to_gcm');
    addTearDown(() async => tempDir.delete(recursive: true));

    final key = bytes.next(32);
    final fieldCipher = FieldCipherService.instance;
    final legacyCbc = await fieldCipher.encryptLegacyCbcForTesting(
      'legacy-cbc-secret',
      key,
    );

    final rawDb = await databaseFactoryFfi.openDatabase(
      _dbPath(tempDir),
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await rawDb.execute(passwordsTableSchema);
    await rawDb.insert('passwords', <String, Object?>{
      'id': 'entry-4',
      'title': 'Legacy Item',
      'username': 'legacy@example.com',
      'password': legacyCbc,
      'url': null,
      'createdDate': DateTime(2026, 2, 24).toUtc().toIso8601String(),
      'lastModified': null,
      'category': 'General',
    });
    await rawDb.close();

    final db = await buildService(tempDir: tempDir, sessionKey: key);
    addTearDown(db.close);

    final decrypted = await db.getAllPasswordsDecrypted();
    expect(decrypted, hasLength(1));
    expect(decrypted.first.password, 'legacy-cbc-secret');

    final rawAfter = db.getAllPasswords();
    expect(rawAfter.first.password.startsWith('or1:v2:gcm:'), isTrue);
    expect(rawAfter.first.password, isNot(equals(legacyCbc)));
  });

  test('backup export -> restore -> matches', () async {
    final sourceDir = await createTempVaultDirectory('backup_source');
    final targetDir = await createTempVaultDirectory('backup_target');
    addTearDown(() async => sourceDir.delete(recursive: true));
    addTearDown(() async => targetDir.delete(recursive: true));

    final sourceKey = bytes.next(32);
    final targetKey = bytes.next(32);
    const backupPassphrase = 'backup-passphrase-2026';

    final sourceDb =
        await buildService(tempDir: sourceDir, sessionKey: sourceKey);
    addTearDown(sourceDb.close);

    await sourceDb.addPassword(
      PasswordModel(
        id: 'source-1',
        title: 'GitHub',
        username: 'dev@onerule.app',
        password: 'gh-secret',
        category: 'General',
        createdDate: DateTime(2026, 2, 24),
      ),
    );
    await sourceDb.addPassword(
      PasswordModel(
        id: 'source-2',
        title: 'Email',
        username: 'user@example.com',
        password: 'mail-secret',
        category: 'Communication',
        createdDate: DateTime(2026, 2, 24),
      ),
    );

    final sourceRecords = await sourceDb.getAllPasswordsDecrypted();
    final backupService =
        BackupService(storage: TestSecureStorageService(sourceKey));
    final payload = await backupService.createEncryptedBackup(
      records: sourceRecords
          .map(
            (e) => <String, dynamic>{
              'title': e.title,
              'username': e.username,
              'password': e.password,
              'url': e.url,
              'category': e.category,
              'createdDate': e.createdDate.toUtc().toIso8601String(),
            },
          )
          .toList(),
      passphrase: backupPassphrase,
    );

    final restored = await backupService.decryptEncryptedBackupStrict(
      encryptedPayload: payload,
      passphrase: backupPassphrase,
    );

    final targetDb =
        await buildService(tempDir: targetDir, sessionKey: targetKey);
    addTearDown(targetDb.close);
    for (var i = 0; i < restored.length; i++) {
      final map = Map<String, dynamic>.from(restored[i] as Map);
      await targetDb.addPassword(
        PasswordModel(
          id: 'restored-$i',
          title: map['title'] as String,
          username: map['username'] as String,
          password: map['password'] as String,
          category: map['category'] as String? ?? 'General',
          createdDate: DateTime.parse(map['createdDate'] as String).toLocal(),
          url: map['url'] as String?,
        ),
      );
    }

    final targetRecords = await targetDb.getAllPasswordsDecrypted();
    final normalizedSource = sourceRecords
        .map((e) => '${e.title}|${e.username}|${e.password}|${e.category}')
        .toSet();
    final normalizedTarget = targetRecords
        .map((e) => '${e.title}|${e.username}|${e.password}|${e.category}')
        .toSet();
    expect(normalizedTarget, equals(normalizedSource));
  });
}

String _dbPath(Directory dir) {
  return '${dir.path}${Platform.pathSeparator}onerule_vault.db';
}

String _tamperGcmEnvelopeTag(String envelope) {
  final parts = envelope.split(':');
  if (parts.length != 6 || parts[0] != 'or1' || parts[1] != 'v2') {
    throw StateError('Unexpected envelope format: $envelope');
  }
  final tagBytes = base64Url.decode(_repad(parts[5]));
  tagBytes[tagBytes.length - 1] ^= 0x01;
  parts[5] = base64Url.encode(tagBytes).replaceAll('=', '');
  return parts.join(':');
}

String _repad(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) return value;
  return value + '=' * (4 - remainder);
}
