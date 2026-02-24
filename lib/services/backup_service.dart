import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../services/secure_storage_service.dart';

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

  Future<void> exportPasswords(
    BuildContext context,
    List<Map<String, dynamic>> records,
  ) async {
    final loc = AppLocalizations.of(context)!;
    try {
      if (records.isEmpty) {
        _showSnack(context, loc.noPasswordsToExport);
        return;
      }

      String? passphrase = await _askForExportPassphrase(
        context,
        title: loc.backupPassphraseTitle,
        hint: loc.backupPassphraseHint,
        confirmHint: loc.backupPassphraseConfirmHint,
      );
      if (passphrase == null || passphrase.isEmpty) {
        return;
      }

      final exportString = await createEncryptedBackup(
        records: records,
        passphrase: passphrase,
      );

      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final fileName = 'onerule_backup_$dateStr.onerule';

      if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(exportString);
        await Share.shareXFiles([XFile(file.path)], text: loc.backupShareText);
      } else {
        final outputFile = await FilePicker.platform.saveFile(
          dialogTitle: loc.saveBackupFileTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['onerule'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(exportString);
          if (!context.mounted) return;
          _showSnack(context, loc.backupSavedToDevice);
        }
      }

      await _storage.setLastBackupAt(DateTime.now());
      passphrase = '';
    } catch (e) {
      if (!context.mounted) return;
      _showSnack(context, loc.exportFailed(e.toString()));
    }
  }

  Future<void> importPasswords(
    BuildContext context, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['onerule', 'json'],
      );

      if (result == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final extension = result.files.single.extension ?? '';

      if (extension.toLowerCase() == 'json') {
        if (!context.mounted) return;
        final ok = await _confirmLegacyJsonImport(context);
        if (!ok || !context.mounted) {
          return;
        }
        await _importLegacyJson(context, file, addRecord: addRecord);
        return;
      }

      final encryptedString = await file.readAsString();
      if (!context.mounted) return;
      String? passphrase = await _askForPassphrase(
        context,
        title: loc.backupPassphraseTitle,
        hint: loc.backupPassphraseHint,
      );
      if (passphrase == null || passphrase.isEmpty) {
        return;
      }

      final decryptedRecords = await decryptEncryptedBackup(
        encryptedPayload: encryptedString,
        passphrase: passphrase,
      );
      passphrase = '';

      if (decryptedRecords == null) {
        if (!context.mounted) return;
        _showSnack(context, loc.importFailedInvalidOrPassword);
        return;
      }

      final count =
          await _importRecords(decryptedRecords, addRecord: addRecord);
      await _storage.setLastBackupAt(DateTime.now());
      if (!context.mounted) return;
      _showSnack(context, loc.passwordsImported(count));
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, loc.importFailed);
    }
  }

  Future<void> _importLegacyJson(
    BuildContext context,
    File file, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final jsonString = await file.readAsString();
      final parsed = jsonDecode(jsonString);
      if (parsed is! List<dynamic>) {
        throw const FormatException('Legacy JSON backup must be a list.');
      }

      final count = await _importRecords(parsed, addRecord: addRecord);
      await _storage.setLegacyJsonImportCompleted();
      await _storage.setLastBackupAt(DateTime.now());
      if (!context.mounted) return;
      _showSnack(context, loc.passwordsImported(count));
    } catch (_) {
      if (!context.mounted) return;
      _showSnack(context, loc.importFailed);
    }
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

  Future<bool> _confirmLegacyJsonImport(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    if (await _storage.hasCompletedLegacyJsonImport()) {
      return true;
    }
    if (!context.mounted) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.legacyImportWarningTitle),
        content: Text(loc.legacyImportWarningBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.legacyImportConfirm),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<String?> _askForPassphrase(
    BuildContext context, {
    required String title,
    required String hint,
  }) async {
    final controller = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    try {
      return showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration: InputDecoration(hintText: hint),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: Text(loc.confirm),
            ),
          ],
        ),
      );
    } finally {
      controller.text = '';
      controller.dispose();
    }
  }

  Future<String?> _askForExportPassphrase(
    BuildContext context, {
    required String title,
    required String hint,
    required String confirmHint,
  }) async {
    final loc = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    Future<String?> result;
    try {
      result = showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  obscureText: true,
                  decoration: InputDecoration(hintText: hint),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: confirmHint,
                    errorText: errorText,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel),
              ),
              FilledButton(
                onPressed: () {
                  final first = controller.text;
                  final second = confirmController.text;
                  if (first.isEmpty || second.isEmpty) {
                    setState(() => errorText = loc.backupPassphraseEmpty);
                    return;
                  }
                  if (first != second) {
                    setState(() => errorText = loc.backupPassphraseMismatch);
                    return;
                  }
                  Navigator.pop(context, first);
                },
                child: Text(loc.confirm),
              ),
            ],
          ),
        ),
      );
      return await result;
    } finally {
      controller.text = '';
      confirmController.text = '';
      controller.dispose();
      confirmController.dispose();
    }
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class BackupCipherException implements Exception {
  const BackupCipherException(this.message);

  final String message;

  @override
  String toString() => 'BackupCipherException: $message';
}
