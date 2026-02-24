import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/services/field_cipher_service.dart';

void main() {
  const plaintext = 'super-secret-password';
  final key = List<int>.generate(32, (index) => index + 1);
  final wrongKey = List<int>.generate(32, (index) => index + 101);

  test('encrypt/decrypt roundtrip succeeds for current GCM envelope', () async {
    final service = FieldCipherService.instance;

    final encrypted = await service.encrypt(plaintext, key);

    expect(encrypted.startsWith('or1:v2:gcm:'), isTrue);
    expect(service.looksEncrypted(encrypted), isTrue);
    expect(service.isCurrentEnvelope(encrypted), isTrue);

    final decrypted = await service.decrypt(encrypted, key);
    expect(decrypted, plaintext);
  });

  test('decrypts legacy CBC payload then re-encrypts to current GCM envelope',
      () async {
    final service = FieldCipherService.instance;

    final legacyCbc = await service.encryptLegacyCbcForTesting(plaintext, key);
    expect(service.isCurrentEnvelope(legacyCbc), isFalse);

    final decrypted = await service.decrypt(legacyCbc, key);
    expect(decrypted, plaintext);

    final migrated =
        await service.migrateToCurrentEnvelopeIfNeeded(legacyCbc, key);
    expect(migrated, isNotNull);
    expect(migrated!.startsWith('or1:v2:gcm:'), isTrue);
    expect(await service.decrypt(migrated, key), plaintext);
  });

  test(
      'decrypts legacy marker-GCM payload then re-encrypts to current envelope',
      () async {
    final service = FieldCipherService.instance;

    final legacyGcm = await service.encryptLegacyGcmMarkerForTesting(
      plaintext,
      key,
    );
    expect(service.isCurrentEnvelope(legacyGcm), isFalse);

    final decrypted = await service.decrypt(legacyGcm, key);
    expect(decrypted, plaintext);

    final migrated =
        await service.migrateToCurrentEnvelopeIfNeeded(legacyGcm, key);
    expect(migrated, isNotNull);
    expect(migrated!.startsWith('or1:v2:gcm:'), isTrue);
    expect(await service.decrypt(migrated, key), plaintext);
  });

  test('decryption hard-fails on tampered GCM tag', () async {
    final service = FieldCipherService.instance;
    final encrypted = await service.encrypt(plaintext, key);

    final parts = encrypted.split(':');
    expect(parts.length, 6);

    final tamperedTagBytes = base64Url.decode(_repad(parts[5]));
    tamperedTagBytes[tamperedTagBytes.length - 1] ^= 0x01;
    parts[5] = base64Url.encode(tamperedTagBytes).replaceAll('=', '');
    final tampered = parts.join(':');

    expect(
      () => service.decrypt(tampered, key),
      throwsA(
        isA<FieldCipherException>().having(
          (e) => e.message,
          'message',
          contains('Authentication failed'),
        ),
      ),
    );
  });

  test('wrong PIN/key hard-fails with clear auth error', () async {
    final service = FieldCipherService.instance;
    final encrypted = await service.encrypt(plaintext, key);

    expect(
      () => service.decrypt(encrypted, wrongKey),
      throwsA(
        isA<FieldCipherException>().having(
          (e) => e.message,
          'message',
          contains('Authentication failed'),
        ),
      ),
    );
  });
}

String _repad(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) return value;
  return value + '=' * (4 - remainder);
}
