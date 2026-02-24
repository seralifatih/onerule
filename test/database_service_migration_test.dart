import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/services/database_service.dart';
import 'package:offline_pass_manager/services/field_cipher_service.dart';
import 'package:offline_pass_manager/services/secure_storage_service.dart';

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService({
    required this.sessionKey,
  }) : super.forTesting();

  final List<int> sessionKey;
  bool gcmMigrationCompleted = false;
  int setGcmMigrationCompletedCalls = 0;

  @override
  List<int> getSessionKeyOrThrow() => List<int>.from(sessionKey);

  @override
  Future<bool> hasCompletedGcmMigration() async => gcmMigrationCompleted;

  @override
  Future<void> setGcmMigrationCompleted() async {
    gcmMigrationCompleted = true;
    setGcmMigrationCompletedCalls += 1;
  }
}

PasswordModel _model({
  required String id,
  required String password,
}) {
  return PasswordModel(
    id: id,
    title: 'Service-$id',
    username: 'user-$id',
    password: password,
    category: 'General',
    createdDate: DateTime(2026, 1, 1),
  );
}

Future<Box<PasswordModel>> _openBox(String testName) async {
  final name =
      'migration_box_${testName}_${DateTime.now().microsecondsSinceEpoch}';
  return Hive.openBox<PasswordModel>(name);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  final fieldCipher = FieldCipherService.instance;
  final key = List<int>.generate(32, (index) => index + 7);

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('onerule_migration_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(PasswordModelAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('migration is idempotent and does not double-encrypt records', () async {
    final secureStorage = _FakeSecureStorageService(sessionKey: key);
    final db = DatabaseService(secureStorage: secureStorage);
    final box = await _openBox('idempotent');
    db.attachBoxForTesting(box);

    await box.put('1', _model(id: '1', password: 'plain-1'));
    await box.put('2', _model(id: '2', password: 'plain-2'));

    await db.migrateToGcmIfNeededForTesting(key);

    final firstPass = <String, String>{
      for (final item in box.values) item.id: item.password,
    };
    expect(
      firstPass.values.every(fieldCipher.looksEncrypted),
      isTrue,
    );

    secureStorage.gcmMigrationCompleted = false;
    await db.migrateToGcmIfNeededForTesting(key);

    final secondPass = <String, String>{
      for (final item in box.values) item.id: item.password,
    };
    expect(secondPass, equals(firstPass));

    expect(await fieldCipher.decrypt(secondPass['1']!, key), 'plain-1');
    expect(await fieldCipher.decrypt(secondPass['2']!, key), 'plain-2');

    await box.deleteFromDisk();
  });

  test('partial migration state is safe and converges on rerun', () async {
    final secureStorage = _FakeSecureStorageService(sessionKey: key);
    final db = DatabaseService(secureStorage: secureStorage);
    final box = await _openBox('partial');
    db.attachBoxForTesting(box);

    final alreadyEncrypted = await fieldCipher.encrypt('plain-1', key);
    await box.put('1', _model(id: '1', password: alreadyEncrypted));
    await box.put('2', _model(id: '2', password: 'plain-2'));

    await db.migrateToGcmIfNeededForTesting(key);

    final rec1 = box.get('1')!;
    final rec2 = box.get('2')!;

    expect(rec1.password, alreadyEncrypted);
    expect(fieldCipher.looksEncrypted(rec2.password), isTrue);
    expect(await fieldCipher.decrypt(rec2.password, key), 'plain-2');
    expect(secureStorage.gcmMigrationCompleted, isTrue);

    secureStorage.gcmMigrationCompleted = false;
    await db.migrateToGcmIfNeededForTesting(key);

    final rec1After = box.get('1')!;
    final rec2After = box.get('2')!;
    expect(rec1After.password, rec1.password);
    expect(rec2After.password, rec2.password);

    await box.deleteFromDisk();
  });
}
