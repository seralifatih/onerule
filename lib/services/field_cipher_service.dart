// DocDrifter v1-release smoke test: no behavior change.
import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';

enum FieldCipherPayloadKind {
  plaintext,
  gcmEnvelopeV2,
  legacyCbcEnvelopeV1,
  legacyGcmMarkerV1,
}

class FieldCipherService {
  FieldCipherService._();
  static final FieldCipherService instance = FieldCipherService._();

  static final _gcm = AesGcm.with256bits(nonceLength: 12);
  static final _cbc = AesCbc.with256bits(
    macAlgorithm: MacAlgorithm.empty,
    paddingAlgorithm: PaddingAlgorithm.pkcs7,
  );

  static const String _prefix = 'or1';
  static const String _versionGcmV2 = 'v2';
  static const String _versionCbcV1 = 'v1';
  static const String _algoGcm = 'gcm';
  static const String _algoCbc = 'cbc';

  static const int _legacyGcmMarker = 0x01;
  static const int _gcmNonceLength = 12;
  static const int _gcmTagLength = 16;

  /// Current canonical format:
  /// `or1:v2:gcm:<nonce_b64url>:<ciphertext_b64url>:<tag_b64url>`
  Future<String> encrypt(String plaintext, List<int> sessionKey) async {
    final secretKey = SecretKey(sessionKey);
    final nonce = _generateNonce();

    final secretBox = await _gcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      nonce: nonce,
    );

    return _joinParts(<String>[
      _prefix,
      _versionGcmV2,
      _algoGcm,
      _b64(secretBox.nonce),
      _b64(secretBox.cipherText),
      _b64(secretBox.mac.bytes),
    ]);
  }

  Future<String> decrypt(String encoded, List<int> sessionKey) async {
    final kind = detectPayloadKind(encoded);

    switch (kind) {
      case FieldCipherPayloadKind.gcmEnvelopeV2:
        return _decryptGcmEnvelope(encoded, sessionKey);
      case FieldCipherPayloadKind.legacyCbcEnvelopeV1:
        return _decryptLegacyCbcEnvelope(encoded, sessionKey);
      case FieldCipherPayloadKind.legacyGcmMarkerV1:
        return _decryptLegacyGcmMarkerPayload(encoded, sessionKey);
      case FieldCipherPayloadKind.plaintext:
        throw const FieldCipherException(
          'Unencrypted plaintext value encountered; migration required before decrypt.',
        );
    }
  }

  /// Returns `null` when already current envelope, otherwise returns a
  /// re-encrypted v2 GCM envelope.
  Future<String?> migrateToCurrentEnvelopeIfNeeded(
    String value,
    List<int> sessionKey,
  ) async {
    final kind = detectPayloadKind(value);
    if (kind == FieldCipherPayloadKind.gcmEnvelopeV2) {
      return null;
    }

    if (kind == FieldCipherPayloadKind.plaintext) {
      return encrypt(value, sessionKey);
    }

    final plaintext = await decrypt(value, sessionKey);
    return encrypt(plaintext, sessionKey);
  }

  FieldCipherPayloadKind detectPayloadKind(String value) {
    final envelope = _tryParseEnvelope(value);
    if (envelope != null) {
      final version = envelope.version;
      final algorithm = envelope.algorithm;
      if (version == _versionGcmV2 && algorithm == _algoGcm) {
        return FieldCipherPayloadKind.gcmEnvelopeV2;
      }
      if (version == _versionCbcV1 && algorithm == _algoCbc) {
        return FieldCipherPayloadKind.legacyCbcEnvelopeV1;
      }
    }

    try {
      final payload = base64Url.decode(_repad(value));
      if (payload.isNotEmpty && payload[0] == _legacyGcmMarker) {
        return FieldCipherPayloadKind.legacyGcmMarkerV1;
      }
    } catch (_) {
      // Not base64 payload, treat as plaintext.
    }

    return FieldCipherPayloadKind.plaintext;
  }

  bool looksEncrypted(String value) {
    return detectPayloadKind(value) != FieldCipherPayloadKind.plaintext;
  }

  bool isCurrentEnvelope(String value) {
    return detectPayloadKind(value) == FieldCipherPayloadKind.gcmEnvelopeV2;
  }

  Future<String> _decryptGcmEnvelope(
    String encoded,
    List<int> sessionKey,
  ) async {
    final envelope = _tryParseEnvelope(encoded);
    if (envelope == null ||
        envelope.version != _versionGcmV2 ||
        envelope.algorithm != _algoGcm ||
        envelope.parts.length != 3) {
      throw const FieldCipherException('Invalid GCM envelope format.');
    }

    final nonce = _decodeB64(envelope.parts[0], label: 'nonce');
    final cipherText = _decodeB64(envelope.parts[1], label: 'cipherText');
    final tag = _decodeB64(envelope.parts[2], label: 'tag');

    if (nonce.length != _gcmNonceLength) {
      throw const FieldCipherException('Invalid GCM nonce length.');
    }
    if (tag.length != _gcmTagLength) {
      throw const FieldCipherException(
          'Invalid GCM authentication tag length.');
    }

    try {
      final plainBytes = await _gcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(sessionKey),
      );
      return utf8.decode(plainBytes);
    } on SecretBoxAuthenticationError {
      throw const FieldCipherException(
        'Authentication failed for AES-GCM payload. Data may be tampered or key is wrong.',
      );
    } catch (e) {
      throw FieldCipherException('Failed to decrypt GCM envelope: $e');
    }
  }

  Future<String> _decryptLegacyCbcEnvelope(
    String encoded,
    List<int> sessionKey,
  ) async {
    final envelope = _tryParseEnvelope(encoded);
    if (envelope == null ||
        envelope.version != _versionCbcV1 ||
        envelope.algorithm != _algoCbc ||
        envelope.parts.length != 2) {
      throw const FieldCipherException('Invalid legacy CBC envelope format.');
    }

    final iv = _decodeB64(envelope.parts[0], label: 'iv');
    final cipherText = _decodeB64(envelope.parts[1], label: 'cipherText');

    if (iv.length != _cbc.nonceLength) {
      throw const FieldCipherException('Invalid CBC IV length.');
    }

    try {
      final clear = await _cbc.decrypt(
        SecretBox(cipherText, nonce: iv, mac: Mac.empty),
        secretKey: SecretKey(sessionKey),
      );
      return utf8.decode(clear);
    } catch (_) {
      throw const FieldCipherException(
        'Failed to decrypt legacy AES-CBC payload. Key may be wrong or payload is corrupted.',
      );
    }
  }

  Future<String> _decryptLegacyGcmMarkerPayload(
    String encoded,
    List<int> sessionKey,
  ) async {
    final Uint8List payload;
    try {
      payload = Uint8List.fromList(base64Url.decode(_repad(encoded)));
    } catch (_) {
      throw const FieldCipherException('Invalid base64url payload.');
    }

    if (payload.isEmpty || payload[0] != _legacyGcmMarker) {
      throw const FieldCipherException('Missing legacy GCM marker byte.');
    }

    if (payload.length < 1 + _gcmNonceLength + _gcmTagLength) {
      throw const FieldCipherException('Legacy GCM payload too short.');
    }

    final nonce = payload.sublist(1, 1 + _gcmNonceLength);
    final cipherTextEnd = payload.length - _gcmTagLength;
    final cipherText = payload.sublist(1 + _gcmNonceLength, cipherTextEnd);
    final tag = payload.sublist(cipherTextEnd);

    try {
      final plainBytes = await _gcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKey(sessionKey),
      );
      return utf8.decode(plainBytes);
    } on SecretBoxAuthenticationError {
      throw const FieldCipherException(
        'Authentication failed for legacy AES-GCM payload. Data may be tampered or key is wrong.',
      );
    } catch (e) {
      throw FieldCipherException('Failed to decrypt legacy GCM payload: $e');
    }
  }

  _EnvelopeParts? _tryParseEnvelope(String value) {
    if (!value.startsWith('$_prefix:')) {
      return null;
    }
    final parts = value.split(':');
    if (parts.length < 4 || parts[0] != _prefix) {
      return null;
    }
    return _EnvelopeParts(
      version: parts[1],
      algorithm: parts[2],
      parts: parts.sublist(3),
    );
  }

  String _b64(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  String _joinParts(List<String> parts) {
    return parts.join(':');
  }

  List<int> _decodeB64(String value, {required String label}) {
    try {
      return base64Url.decode(_repad(value));
    } catch (_) {
      throw FieldCipherException(
          'Invalid base64url $label in cipher envelope.');
    }
  }

  List<int> _generateNonce() {
    final rng = Random.secure();
    return List<int>.generate(_gcmNonceLength, (_) => rng.nextInt(256));
  }

  String _repad(String s) {
    final remainder = s.length % 4;
    if (remainder == 0) return s;
    return s + '=' * (4 - remainder);
  }

  @visibleForTesting
  Future<String> encryptLegacyCbcForTesting(
    String plaintext,
    List<int> sessionKey,
  ) async {
    final rng = Random.secure();
    final iv = List<int>.generate(_cbc.nonceLength, (_) => rng.nextInt(256));
    final secretBox = await _cbc.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(sessionKey),
      nonce: iv,
    );
    return _joinParts(<String>[
      _prefix,
      _versionCbcV1,
      _algoCbc,
      _b64(secretBox.nonce),
      _b64(secretBox.cipherText),
    ]);
  }

  @visibleForTesting
  Future<String> encryptLegacyGcmMarkerForTesting(
    String plaintext,
    List<int> sessionKey,
  ) async {
    final nonce = _generateNonce();
    final secretBox = await _gcm.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(sessionKey),
      nonce: nonce,
    );

    final payload = Uint8List(
      1 +
          nonce.length +
          secretBox.cipherText.length +
          secretBox.mac.bytes.length,
    );
    var offset = 0;
    payload[offset++] = _legacyGcmMarker;
    payload.setAll(offset, nonce);
    offset += nonce.length;
    payload.setAll(offset, secretBox.cipherText);
    offset += secretBox.cipherText.length;
    payload.setAll(offset, secretBox.mac.bytes);

    return base64Url.encode(payload).replaceAll('=', '');
  }
}

class FieldCipherException implements Exception {
  const FieldCipherException(this.message);
  final String message;

  @override
  String toString() => 'FieldCipherException: $message';
}

class _EnvelopeParts {
  const _EnvelopeParts({
    required this.version,
    required this.algorithm,
    required this.parts,
  });

  final String version;
  final String algorithm;
  final List<String> parts;
}
