import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/services/field_cipher_service.dart';

String _repadBase64Url(String value) {
  final remainder = value.length % 4;
  if (remainder == 0) return value;
  return value + '=' * (4 - remainder);
}

void main() {
  const plaintext = 'super-secret-password';
  final key = List<int>.generate(32, (index) => index + 1);

  test('encrypt/decrypt roundtrip succeeds for password field', () async {
    final service = FieldCipherService.instance;

    final encrypted = await service.encrypt(plaintext, key);

    expect(encrypted, isNot(plaintext));
    expect(service.looksEncrypted(encrypted), isTrue);

    final decrypted = await service.decrypt(encrypted, key);
    expect(decrypted, plaintext);
  });

  test('decryption fails on tampered ciphertext (auth tag mismatch)', () async {
    final service = FieldCipherService.instance;
    final encrypted = await service.encrypt(plaintext, key);

    final payload = Uint8List.fromList(
      base64Url.decode(_repadBase64Url(encrypted)),
    );
    payload[payload.length - 1] = payload[payload.length - 1] ^ 0x01;

    final tampered = base64Url.encode(payload).replaceAll('=', '');

    expect(
      () => service.decrypt(tampered, key),
      throwsA(
        isA<FieldCipherException>().having(
          (e) => e.message,
          'message',
          contains('authentication failed'),
        ),
      ),
    );
  });
}
