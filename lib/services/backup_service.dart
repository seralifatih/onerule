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
  static const int _backupSchemaVersion = 2;
  static const int _pbkdf2Iterations = 200000;

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
          _showSnack(context, loc.backupSavedToDevice);
        }
      }

      await _storage.setLastBackupAt(DateTime.now());
      passphrase = '';
    } catch (e) {
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
        final ok = await _confirmLegacyJsonImport(context);
        if (!ok) {
          return;
        }
        await _importLegacyJson(context, file, addRecord: addRecord);
        return;
      }

      final encryptedString = await file.readAsString();
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
        _showSnack(context, loc.importFailedInvalidOrPassword);
        return;
      }

      final count =
          await _importRecords(decryptedRecords, addRecord: addRecord);
      _showSnack(context, loc.passwordsImported(count));
    } catch (_) {
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
      _showSnack(context, loc.passwordsImported(count));
    } catch (_) {
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
    final decrypted = await _decryptPayload(encryptedPayload, passphrase);
    if (decrypted == null) {
      return null;
    }
    final parsed = jsonDecode(decrypted);
    if (parsed is! List<dynamic>) {
      return null;
    }
    return parsed;
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
    final aesGcm = AesGcm.with256bits();

    final parsedPayload = jsonDecode(plaintext);
    final itemCount = parsedPayload is List ? parsedPayload.length : 0;
    final now = DateTime.now().toUtc();

    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    return {
      'v': _backupSchemaVersion,
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(secretBox.nonce),
      'cipherText': base64UrlEncode(secretBox.cipherText),
      'mac': base64UrlEncode(secretBox.mac.bytes),
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

  Future<String?> _decryptPayload(
    String encryptedPayload,
    String passphrase,
  ) async {
    final data = jsonDecode(encryptedPayload);
    if (data is! Map<String, dynamic>) {
      return null;
    }
    final version = data['v'];
    if (version != 1 && version != _backupSchemaVersion) {
      return null;
    }

    try {
      final salt = base64Url.decode(data['salt'] as String);
      final nonce = base64Url.decode(data['nonce'] as String);
      final cipherText = base64Url.decode(data['cipherText'] as String);
      final macBytes = base64Url.decode(data['mac'] as String);
      final key = await _deriveKey(passphrase, salt);
      final aesGcm = AesGcm.with256bits();

      final clearText = await aesGcm.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
      );

      return utf8.decode(clearText);
    } catch (_) {
      return null;
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

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
