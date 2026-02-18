import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/services/backup_service.dart';

void main() {
  test('encrypted backup round-trip succeeds with correct passphrase',
      () async {
    final service = BackupService();

    final records = <Map<String, dynamic>>[
      {
        'title': 'Github',
        'username': 'dev@onerule.app',
        'password': 'super-secret',
        'category': 'General',
      },
    ];

    final exported = await service.createEncryptedBackup(
      records: records,
      passphrase: 'correct horse battery staple',
    );

    final exportedJson = jsonDecode(exported) as Map<String, dynamic>;

    expect(exported.contains('super-secret'), isFalse);
    expect(exported.contains('dev@onerule.app'), isFalse);
    expect(exportedJson['v'], 2);
    expect((exportedJson['meta'] as Map<String, dynamic>)['itemCount'], 1);

    final imported = await service.decryptEncryptedBackup(
      encryptedPayload: exported,
      passphrase: 'correct horse battery staple',
    );

    expect(imported, isNotNull);
    expect((imported!.first as Map)['title'], 'Github');
    expect((imported.first as Map)['username'], 'dev@onerule.app');
  });

  test('encrypted backup import fails with incorrect passphrase', () async {
    final service = BackupService();

    final exported = await service.createEncryptedBackup(
      records: <Map<String, dynamic>>[
        {
          'title': 'Email',
          'username': 'user@example.com',
          'password': 'pw-123',
          'category': 'General',
        },
      ],
      passphrase: 'right-passphrase',
    );

    final imported = await service.decryptEncryptedBackup(
      encryptedPayload: exported,
      passphrase: 'wrong-passphrase',
    );

    expect(imported, isNull);
  });
}
