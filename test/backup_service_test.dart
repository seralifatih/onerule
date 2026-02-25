import 'dart:convert';
import 'dart:io';

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
    final envelope = exportedJson['envelope'] as Map<String, dynamic>;

    expect(exported.contains('super-secret'), isFalse);
    expect(exported.contains('dev@onerule.app'), isFalse);
    expect(exportedJson['v'], 3);
    expect(envelope['algorithm'], 'AES-GCM-256');
    expect((exportedJson['meta'] as Map<String, dynamic>)['itemCount'], 1);

    final imported = await service.decryptEncryptedBackupStrict(
      encryptedPayload: exported,
      passphrase: 'correct horse battery staple',
    );

    expect((imported.first as Map)['title'], 'Github');
    expect((imported.first as Map)['username'], 'dev@onerule.app');
  });

  test('decrypts legacy CBC backup and migrates to latest envelope', () async {
    final service = BackupService();

    final legacy = await service.createLegacyCbcBackupForTesting(
      records: <Map<String, dynamic>>[
        {
          'title': 'Legacy',
          'username': 'legacy@example.com',
          'password': 'old-cbc-secret',
          'category': 'General',
        },
      ],
      passphrase: 'legacy-passphrase',
    );

    final imported = await service.decryptEncryptedBackupStrict(
      encryptedPayload: legacy,
      passphrase: 'legacy-passphrase',
    );
    expect((imported.first as Map)['password'], 'old-cbc-secret');

    final migrated = await service.migrateEncryptedBackupToLatest(
      encryptedPayload: legacy,
      passphrase: 'legacy-passphrase',
    );

    expect(migrated, isNotNull);
    final migratedJson = jsonDecode(migrated!) as Map<String, dynamic>;
    expect(migratedJson['v'], 3);
  });

  test('backup tamper detection hard-fails with clear error', () async {
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

    final payload = jsonDecode(exported) as Map<String, dynamic>;
    final envelope = Map<String, dynamic>.from(payload['envelope'] as Map);
    final tagBytes = base64Url.decode(_repad(envelope['tag'] as String));
    tagBytes[tagBytes.length - 1] ^= 0x01;
    envelope['tag'] = base64Url.encode(tagBytes).replaceAll('=', '');
    payload['envelope'] = envelope;

    expect(
      () => service.decryptEncryptedBackupStrict(
        encryptedPayload: jsonEncode(payload),
        passphrase: 'right-passphrase',
      ),
      throwsA(
        isA<BackupCipherException>().having(
          (e) => e.message,
          'message',
          contains('authentication failed'),
        ),
      ),
    );
  });

  test('wrong backup passphrase fails with authentication error', () async {
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

    expect(
      () => service.decryptEncryptedBackupStrict(
        encryptedPayload: exported,
        passphrase: 'wrong-passphrase',
      ),
      throwsA(
        isA<BackupCipherException>().having(
          (e) => e.message,
          'message',
          contains('authentication failed'),
        ),
      ),
    );
  });

  test('auto backup filename uses OneRule_backup_YYYY_MM_DD.enc format', () {
    final service = BackupService();
    final fileName =
        service.buildAutoBackupFileName(now: DateTime(2026, 2, 25, 14, 30));

    expect(fileName, 'OneRule_backup_2026_02_25.enc');
  });

  test('restore reports wrong PIN state for encrypted backup auth failure',
      () async {
    final service = BackupService();
    final tempDir = await Directory.systemTemp.createTemp('onerule-restore-');
    final file = File('${tempDir.path}${Platform.pathSeparator}sample.enc');

    try {
      final exported = await service.createEncryptedBackup(
        records: <Map<String, dynamic>>[
          {
            'title': 'Email',
            'username': 'user@example.com',
            'password': 'pw-123',
            'category': 'General',
          },
        ],
        passphrase: 'correct-passphrase',
      );

      await file.writeAsString(exported, flush: true);

      final result = await service.restoreFromFile(
        file: file,
        passphrase: 'wrong-passphrase',
        addRecord: (_) async {},
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, BackupRestoreFailure.wrongPin);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });

  test('restore reports corrupt file for malformed backup payload', () async {
    final service = BackupService();
    final tempDir = await Directory.systemTemp.createTemp('onerule-restore-');
    final file = File('${tempDir.path}${Platform.pathSeparator}broken.enc');

    try {
      await file.writeAsString('not-a-valid-backup', flush: true);

      final result = await service.restoreFromFile(
        file: file,
        passphrase: 'any-passphrase',
        addRecord: (_) async {},
      );

      expect(result.isSuccess, isFalse);
      expect(result.failure, BackupRestoreFailure.corruptFile);
    } finally {
      await tempDir.delete(recursive: true);
    }
  });
}

String _repad(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) return value;
  return value + '=' * (4 - remainder);
}
