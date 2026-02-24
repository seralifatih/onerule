import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Provides authenticated AES-256-GCM encryption for individual fields.
///
/// Used to add a second encryption layer on top of Hive's AES-CBC box
/// encryption. Even if the box-level cipher is attacked (no authentication
/// tag in CBC mode), the password field itself remains authenticated and
/// confidential under GCM.
///
/// Wire format stored in the Hive field (base64url, no padding):
///   [12-byte nonce][ciphertext][16-byte GCM tag]
/// All concatenated, then base64url-encoded as a single string.
///
/// A plaintext value is detectable because it will NOT successfully
/// base64url-decode AND decrypt with the session key — the migration
/// path uses this to distinguish old records from already-migrated ones.
class FieldCipherService {
  FieldCipherService._();
  static final FieldCipherService instance = FieldCipherService._();

  static final _algorithm = AesGcm.with256bits(nonceLength: 12);

  // Sentinel prefix written into the stored string so migration can
  // distinguish an encrypted field from a legacy plaintext field without
  // attempting a full decrypt-and-catch. Stored BEFORE base64 encoding.
  // One byte is enough — 0x01 is never a valid base64url character at
  // position 0 of a raw binary payload, so there is no false-positive risk.
  static const int _encryptedMarker = 0x01;

  /// Encrypts [plaintext] with [sessionKey] (32 bytes).
  /// Returns a base64url string safe to store in a Hive String field.
  Future<String> encrypt(String plaintext, List<int> sessionKey) async {
    final secretKey = SecretKey(sessionKey);
    final nonce = _generateNonce();

    final secretBox = await _algorithm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    // Layout: marker(1) + nonce(12) + ciphertext(n) + mac(16)
    final payload = Uint8List(
      1 +
          nonce.length +
          secretBox.cipherText.length +
          secretBox.mac.bytes.length,
    );
    var offset = 0;
    payload[offset++] = _encryptedMarker;
    payload.setAll(offset, nonce);
    offset += nonce.length;
    payload.setAll(offset, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    payload.setAll(offset, secretBox.mac.bytes);

    return base64Url.encode(payload).replaceAll('=', '');
  }

  /// Decrypts a value produced by [encrypt].
  /// Throws [FieldCipherException] if authentication fails or the format
  /// is unrecognised — caller must treat this as data corruption.
  Future<String> decrypt(String encoded, List<int> sessionKey) async {
    final Uint8List payload;
    try {
      // Re-pad to valid base64url before decoding
      final padded = _repad(encoded);
      payload = base64Url.decode(padded);
    } catch (_) {
      throw FieldCipherException('Invalid base64url encoding');
    }

    if (payload.isEmpty || payload[0] != _encryptedMarker) {
      throw FieldCipherException(
          'Missing encryption marker — likely plaintext');
    }

    const nonceLength = 12;
    const macLength = 16;
    const headerLength = 1; // marker byte

    if (payload.length < headerLength + nonceLength + macLength) {
      throw FieldCipherException('Payload too short');
    }

    final nonce = payload.sublist(headerLength, headerLength + nonceLength);
    final cipherTextEnd = payload.length - macLength;
    final cipherText =
        payload.sublist(headerLength + nonceLength, cipherTextEnd);
    final mac = Mac(payload.sublist(cipherTextEnd));

    try {
      final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
      final plainBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: SecretKey(sessionKey),
      );
      return utf8.decode(plainBytes);
    } on SecretBoxAuthenticationError {
      throw FieldCipherException(
        'GCM authentication failed — data may be tampered or key is wrong',
      );
    } catch (e) {
      throw FieldCipherException('Decryption error: $e');
    }
  }

  /// Returns true if [value] looks like it was produced by [encrypt].
  /// Use this during migration to skip already-encrypted fields.
  bool looksEncrypted(String value) {
    try {
      final payload = base64Url.decode(_repad(value));
      return payload.isNotEmpty && payload[0] == _encryptedMarker;
    } catch (_) {
      return false;
    }
  }

  List<int> _generateNonce() {
    final rng = Random.secure();
    return List<int>.generate(12, (_) => rng.nextInt(256));
  }

  String _repad(String s) {
    final remainder = s.length % 4;
    if (remainder == 0) return s;
    return s + '=' * (4 - remainder);
  }
}

class FieldCipherException implements Exception {
  const FieldCipherException(this.message);
  final String message;

  @override
  String toString() => 'FieldCipherException: $message';
}
