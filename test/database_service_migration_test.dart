import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/services/field_cipher_service.dart';

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

Future<List<PasswordModel>> _migratePass(
  List<PasswordModel> records,
  List<int> key,
  FieldCipherService fieldCipher,
) async {
  final migrated = <PasswordModel>[];
  for (final item in records) {
    final maybeUpdated =
        await fieldCipher.migrateToCurrentEnvelopeIfNeeded(item.password, key);
    final nextPassword = maybeUpdated ?? item.password;
    migrated.add(
      PasswordModel(
        id: item.id,
        title: item.title,
        username: item.username,
        password: nextPassword,
        url: item.url,
        createdDate: item.createdDate,
        lastModified: item.lastModified,
        category: item.category,
      ),
    );
  }
  return migrated;
}

void main() {
  final fieldCipher = FieldCipherService.instance;
  final key = List<int>.generate(32, (index) => index + 7);

  test('migration-style pass upgrades plaintext/CBC/legacy-GCM to current GCM',
      () async {
    final legacyCbc =
        await fieldCipher.encryptLegacyCbcForTesting('cbc-2', key);
    final legacyGcm =
        await fieldCipher.encryptLegacyGcmMarkerForTesting('gcm-3', key);
    final currentGcm = await fieldCipher.encrypt('gcm-4', key);

    final first = <PasswordModel>[
      _model(id: '1', password: 'plain-1'),
      _model(id: '2', password: legacyCbc),
      _model(id: '3', password: legacyGcm),
      _model(id: '4', password: currentGcm),
    ];

    final once = await _migratePass(first, key, fieldCipher);

    expect(
      once.every((item) => fieldCipher.isCurrentEnvelope(item.password)),
      isTrue,
    );

    expect(await fieldCipher.decrypt(once[0].password, key), 'plain-1');
    expect(await fieldCipher.decrypt(once[1].password, key), 'cbc-2');
    expect(await fieldCipher.decrypt(once[2].password, key), 'gcm-3');
    expect(await fieldCipher.decrypt(once[3].password, key), 'gcm-4');
  });

  test('migration-style pass is idempotent', () async {
    final first = <PasswordModel>[
      _model(id: '1', password: 'plain-1'),
      _model(id: '2', password: 'plain-2'),
    ];

    final once = await _migratePass(first, key, fieldCipher);
    final twice = await _migratePass(once, key, fieldCipher);

    expect(
      twice.map((item) => item.password).toList(),
      equals(once.map((item) => item.password).toList()),
    );

    expect(await fieldCipher.decrypt(twice[0].password, key), 'plain-1');
    expect(await fieldCipher.decrypt(twice[1].password, key), 'plain-2');
  });
}
