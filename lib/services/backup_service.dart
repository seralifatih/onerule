import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_reminder_service.dart';
import 'secure_storage_service.dart';

enum BackupRestoreFailure {
  wrongPin,
  corruptFile,
  unknown,
}

class BackupPreparation {
  const BackupPreparation({
    required this.fileName,
    required this.encryptedPayload,
  });

  final String fileName;
  final String encryptedPayload;
}

class BackupExportResult {
  const BackupExportResult({
    required this.fileName,
    required this.filePath,
  });

  final String fileName;
  final String filePath;
}

class BackupRestoreResult {
  const BackupRestoreResult.success(this.importedCount) : failure = null;

  const BackupRestoreResult.failure(this.failure) : importedCount = 0;

  final int importedCount;
  final BackupRestoreFailure? failure;

  bool get isSuccess => failure == null;
}

class BackupService {
  BackupService({SecureStorageService? storage})
      : _storage = storage ?? SecureStorageService();

  final SecureStorageService _storage;

  static const String _defaultCategory = 'General';
  static const int _backupSchemaVersion = 3;
  static const int _pbkdf2Iterations = 200000;
  static const String _gcmAlgorithmName = 'AES-GCM-256';
  static const String _cbcAlgorithmName = 'AES-CBC-256';

  static final _gcm = AesGcm.with256bits();
  static final _cbc = AesCbc.with256bits(
    macAlgorithm: MacAlgorithm.empty,
    paddingAlgorithm: PaddingAlgorithm.pkcs7,
  );

  String buildAutoBackupFileName({DateTime? now}) {
    final timestamp = now ?? DateTime.now();
    final dateStr = DateFormat('yyyy_MM_dd').format(timestamp);
    return 'OneRule_backup_$dateStr.enc';
  }

  Future<BackupPreparation> prepareEncryptedBackup({
    required List<Map<String, dynamic>> records,
    required String passphrase,
    DateTime? now,
  }) async {
    if (records.isEmpty) {
      throw const BackupExportException('No passwords to export.');
    }
    if (passphrase.trim().isEmpty) {
      throw const BackupExportException('Backup passphrase cannot be empty.');
    }

    final payload = await createEncryptedBackup(
      records: records,
      passphrase: passphrase,
    );

    return BackupPreparation(
      fileName: buildAutoBackupFileName(now: now),
      encryptedPayload: payload,
    );
  }

  Future<BackupExportResult?> savePreparedBackupToDownloads({
    required BackupPreparation preparation,
  }) async {
    final directTarget = await _resolveDownloadsDirectoryFile(
      preparation.fileName,
    );
    if (directTarget != null) {
      final savedFile = await _writeEncryptedFile(
        directTarget,
        preparation.encryptedPayload,
      );
      if (savedFile != null) {
        await _markBackupCreated(DateTime.now());
        return BackupExportResult(
          fileName: savedFile.uri.pathSegments.last,
          filePath: savedFile.path,
        );
      }
    }

    final pickerTarget = await _pickSaveTarget(preparation.fileName);
    if (pickerTarget == null) {
      return null;
    }

    final savedFile = await _writeEncryptedFile(
      pickerTarget,
      preparation.encryptedPayload,
    );
    if (savedFile == null) {
      throw const BackupExportException('Unable to write backup file.');
    }

    await _markBackupCreated(DateTime.now());

    return BackupExportResult(
      fileName: savedFile.uri.pathSegments.last,
      filePath: savedFile.path,
    );
  }

  Future<BackupExportResult> sharePreparedBackup({
    required BackupPreparation preparation,
    required String shareText,
  }) async {
    final directory = await getTemporaryDirectory();
    final file = File(_joinPath(directory.path, preparation.fileName));

    await file.writeAsString(preparation.encryptedPayload, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: shareText);

    await _markBackupCreated(DateTime.now());

    return BackupExportResult(
      fileName: preparation.fileName,
      filePath: file.path,
    );
  }

  Future<File?> pickBackupFileForRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['enc', 'onerule'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      return null;
    }

    return File(path);
  }

  Future<BackupRestoreResult> restoreFromFile({
    required File file,
    required String passphrase,
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    final extension = _extensionOf(file.path);

    if (extension == 'json') {
      try {
        final count = await _importLegacyJson(file, addRecord: addRecord);
        return BackupRestoreResult.success(count);
      } catch (_) {
        return const BackupRestoreResult.failure(
          BackupRestoreFailure.corruptFile,
        );
      }
    }

    if (passphrase.trim().isEmpty) {
      return const BackupRestoreResult.failure(BackupRestoreFailure.wrongPin);
    }

    try {
      final encryptedString = await file.readAsString();
      final decryptedRecords = await decryptEncryptedBackupStrict(
        encryptedPayload: encryptedString,
        passphrase: passphrase,
      );
      final count =
          await _importRecords(decryptedRecords, addRecord: addRecord);
      return BackupRestoreResult.success(count);
    } on BackupCipherException catch (e) {
      if (_isAuthenticationFailure(e)) {
        return const BackupRestoreResult.failure(BackupRestoreFailure.wrongPin);
      }
      return const BackupRestoreResult.failure(
          BackupRestoreFailure.corruptFile);
    } on FormatException {
      return const BackupRestoreResult.failure(
          BackupRestoreFailure.corruptFile);
    } catch (_) {
      return const BackupRestoreResult.failure(BackupRestoreFailure.unknown);
    }
  }

  Future<int> _importLegacyJson(
    File file, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    final jsonString = await file.readAsString();
    final parsed = jsonDecode(jsonString);
    if (parsed is! List<dynamic>) {
      throw const FormatException('Legacy JSON backup must be a list.');
    }

    final count = await _importRecords(parsed, addRecord: addRecord);
    await _storage.setLegacyJsonImportCompleted();
    return count;
  }

  Future<int> _importRecords(
    List<dynamic> jsonList, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    var count = 0;
    for (final item in jsonList) {
      final record = Map<String, dynamic>.from(item as Map);
      record['category'] ??= _defaultCategory;
      await addRecord(record);
      count++;
    }
    return count;
  }

  Future<void> _markBackupCreated(DateTime backupAt) async {
    await _storage.setLastBackupAt(backupAt);
    try {
      await BackupReminderService.instance.onBackupCreated(backupAt);
    } catch (_) {
      // Notification scheduling is best effort.
    }
  }

  Future<File?> _resolveDownloadsDirectoryFile(String fileName) async {
    final downloadsDirectory = await getDownloadsDirectory();
    if (downloadsDirectory == null) {
      return null;
    }
    return File(_joinPath(downloadsDirectory.path, fileName));
  }

  Future<File?> _pickSaveTarget(String fileName) async {
    final outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save encrypted backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['enc'],
    );

    if (outputFile == null || outputFile.isEmpty) {
      return null;
    }

    final normalized = outputFile.toLowerCase().endsWith('.enc')
        ? outputFile
        : '$outputFile.enc';

    return File(normalized);
  }

  Future<File?> _writeEncryptedFile(File file, String encryptedPayload) async {
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(encryptedPayload, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  String _extensionOf(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) {
      return '';
    }
    return path.substring(dot + 1).toLowerCase();
  }

  String _joinPath(String base, String name) {
    final separator = Platform.pathSeparator;
    if (base.endsWith(separator)) {
      return '$base$name';
    }
    return '$base$separator$name';
  }

  bool _isAuthenticationFailure(BackupCipherException error) {
    return error.message.toLowerCase().contains('authentication failed');
  }

  Future<String> createEncryptedBackup({
    required List<Map<String, dynamic>> records,
    required String passphrase,
  }) async {
    final plaintext = jsonEncode(records);
    final encryptedPayload = await _encryptPayload(plaintext, passphrase);
    return jsonEncode(encryptedPayload);
  }

  Future<List<dynamic>?> decryptEncryptedBackup({
    required String encryptedPayload,
    required String passphrase,
  }) async {
    try {
      return decryptEncryptedBackupStrict(
        encryptedPayload: encryptedPayload,
        passphrase: passphrase,
      );
    } on BackupCipherException {
      return null;
    }
  }

  Future<List<dynamic>> decryptEncryptedBackupStrict({
    required String encryptedPayload,
    required String passphrase,
  }) async {
    final decrypted = await _decryptPayloadStrict(encryptedPayload, passphrase);
    final parsed = jsonDecode(decrypted);
    if (parsed is! List<dynamic>) {
      throw const BackupCipherException(
        'Backup payload is not a list of records.',
      );
    }
    return parsed;
  }

  Future<String?> migrateEncryptedBackupToLatest({
    required String encryptedPayload,
    required String passphrase,
  }) async {
    try {
      final parsed = await decryptEncryptedBackupStrict(
        encryptedPayload: encryptedPayload,
        passphrase: passphrase,
      );
      final records =
          parsed.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      return createEncryptedBackup(records: records, passphrase: passphrase);
    } on BackupCipherException {
      return null;
    }
  }

  Future<DateTime?> getLastBackupAt() {
    return _storage.getLastBackupAt();
  }

  Future<Map<String, dynamic>> _encryptPayload(
    String plaintext,
    String passphrase,
  ) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(passphrase, salt);

    final parsedPayload = jsonDecode(plaintext);
    final itemCount = parsedPayload is List ? parsedPayload.length : 0;
    final now = DateTime.now().toUtc();

    final secretBox = await _gcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    return {
      'v': _backupSchemaVersion,
      'envelope': {
        'format': 'onerule-backup',
        'version': 'v3',
        'algorithm': _gcmAlgorithmName,
        'nonce': base64UrlEncode(secretBox.nonce),
        'cipherText': base64UrlEncode(secretBox.cipherText),
        'tag': base64UrlEncode(secretBox.mac.bytes),
      },
      'salt': base64UrlEncode(salt),
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'saltLength': 16,
        'keyBits': 256,
      },
      'cipher': {
        'algorithm': 'AES-GCM-256',
        'nonceLength': 12,
      },
      'meta': {
        'createdAt': now.toIso8601String(),
        'itemCount': itemCount,
      },
    };
  }

  Future<String> _decryptPayloadStrict(
    String encryptedPayload,
    String passphrase,
  ) async {
    final data = jsonDecode(encryptedPayload);
    if (data is! Map<String, dynamic>) {
      throw const BackupCipherException('Invalid backup container format.');
    }
    final version = data['v'];
    if (version == _backupSchemaVersion) {
      return _decryptV3Gcm(data, passphrase);
    }
    if (version == 2) {
      return _decryptV2Gcm(data, passphrase);
    }
    if (version == 1) {
      return _decryptV1Legacy(data, passphrase);
    }
    throw BackupCipherException('Unsupported backup version: $version');
  }

  Future<String> _decryptV3Gcm(
    Map<String, dynamic> data,
    String passphrase,
  ) async {
    final envelope = data['envelope'];
    if (envelope is! Map<String, dynamic>) {
      throw const BackupCipherException('Missing backup envelope.');
    }
    if ((envelope['algorithm'] as String?) != _gcmAlgorithmName) {
      throw const BackupCipherException('Unsupported v3 backup algorithm.');
    }

    try {
      final salt = _decodeBase64Url(data['salt'] as String, field: 'salt');
      final nonce =
          _decodeBase64Url(envelope['nonce'] as String, field: 'nonce');
      final cipherText = _decodeBase64Url(envelope['cipherText'] as String,
          field: 'cipherText');
      final macBytes =
          _decodeBase64Url(envelope['tag'] as String, field: 'tag');
      final key = await _deriveKey(passphrase, salt);

      final clearText = await _gcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );

      return utf8.decode(clearText);
    } on SecretBoxAuthenticationError {
      throw const BackupCipherException(
        'Backup authentication failed. File may be tampered or passphrase is wrong.',
      );
    } catch (e) {
      throw BackupCipherException('Failed to decrypt v3 backup: $e');
    }
  }

  Future<String> _decryptV2Gcm(
    Map<String, dynamic> data,
    String passphrase,
  ) async {
    try {
      final salt = _decodeBase64Url(data['salt'] as String, field: 'salt');
      final nonce = _decodeBase64Url(data['nonce'] as String, field: 'nonce');
      final cipherText =
          _decodeBase64Url(data['cipherText'] as String, field: 'cipherText');
      final macBytes = _decodeBase64Url(data['mac'] as String, field: 'mac');
      final key = await _deriveKey(passphrase, salt);

      final clearText = await _gcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );

      return utf8.decode(clearText);
    } on SecretBoxAuthenticationError {
      throw const BackupCipherException(
        'Backup authentication failed. File may be tampered or passphrase is wrong.',
      );
    } catch (e) {
      throw BackupCipherException('Failed to decrypt v2 backup: $e');
    }
  }

  Future<String> _decryptV1Legacy(
    Map<String, dynamic> data,
    String passphrase,
  ) async {
    final cipher = data['cipher'];
    final algorithm =
        cipher is Map<String, dynamic> ? cipher['algorithm'] as String? : null;

    if (algorithm == _cbcAlgorithmName || data.containsKey('iv')) {
      return _decryptV1Cbc(data, passphrase);
    }
    return _decryptV2Gcm(data, passphrase);
  }

  Future<String> _decryptV1Cbc(
    Map<String, dynamic> data,
    String passphrase,
  ) async {
    try {
      final salt = _decodeBase64Url(data['salt'] as String, field: 'salt');
      final iv = _decodeBase64Url(data['iv'] as String, field: 'iv');
      final cipherText =
          _decodeBase64Url(data['cipherText'] as String, field: 'cipherText');
      final key = await _deriveKey(passphrase, salt);

      final clearText = await _cbc.decrypt(
        SecretBox(cipherText, nonce: iv, mac: Mac.empty),
        secretKey: key,
      );
      return utf8.decode(clearText);
    } catch (e) {
      throw const BackupCipherException(
        'Failed to decrypt legacy CBC backup. Passphrase may be wrong or payload is corrupted.',
      );
    }
  }

  Future<SecretKey> _deriveKey(String passphrase, List<int> salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: _pbkdf2Iterations,
      bits: 256,
    );
    return pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  List<int> _randomBytes(int length) {
    final rnd = Random.secure();
    return List<int>.generate(length, (_) => rnd.nextInt(256));
  }

  List<int> _decodeBase64Url(String value, {required String field}) {
    final remainder = value.length % 4;
    final padded = remainder == 0 ? value : '$value${'=' * (4 - remainder)}';
    try {
      return base64Url.decode(padded);
    } catch (e) {
      throw BackupCipherException('Invalid base64url $field in backup: $e');
    }
  }

  @visibleForTesting
  Future<String> createLegacyCbcBackupForTesting({
    required List<Map<String, dynamic>> records,
    required String passphrase,
  }) async {
    final plaintext = jsonEncode(records);
    final salt = _randomBytes(16);
    final iv = _randomBytes(_cbc.nonceLength);
    final key = await _deriveKey(passphrase, salt);
    final secretBox = await _cbc.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: iv,
    );

    return jsonEncode({
      'v': 1,
      'salt': base64UrlEncode(salt),
      'iv': base64UrlEncode(secretBox.nonce),
      'cipherText': base64UrlEncode(secretBox.cipherText),
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'saltLength': 16,
        'keyBits': 256,
      },
      'cipher': {
        'algorithm': _cbcAlgorithmName,
        'ivLength': _cbc.nonceLength,
      },
    });
  }
}

class BackupExportException implements Exception {
  const BackupExportException(this.message);

  final String message;

  @override
  String toString() => 'BackupExportException: $message';
}

class BackupCipherException implements Exception {
  const BackupCipherException(this.message);

  final String message;

  @override
  String toString() => 'BackupCipherException: $message';
}
