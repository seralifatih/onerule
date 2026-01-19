import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart'; // Telefondaki klasör yolları için
import 'package:share_plus/share_plus.dart'; // Telefonda paylaşım menüsü için
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../services/secure_storage_service.dart';

class BackupService {
  final SecureStorageService _storage = SecureStorageService();
  static const String _defaultCategory = 'General';

  // --- DIŞARI AKTAR (EXPORT) ---
  Future<void> exportPasswords(
      BuildContext context, List<Map<String, dynamic>> records) async {
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

      // 1. Verileri JSON formatına çevir
      String jsonString = jsonEncode(records);

      final encryptedPayload = await _encryptPayload(jsonString, passphrase);
      final exportString = jsonEncode(encryptedPayload);

      // Dosya ismini hazırla
      String dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      String fileName = "onerule_backup_$dateStr.onerule";

      // 2. Platforma göre kaydetme yöntemi seç
      if (Platform.isAndroid || Platform.isIOS) {
        // --- TELEFON İÇİN (Android/iOS) ---
        // Dosyayı önce geçici bir alana yazmamız lazım
        final directory = await getTemporaryDirectory();
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(exportString);

        // Şimdi "Paylaş" menüsünü aç (Kullanıcı buradan Drive'a veya Dosyalara kaydet diyebilir)
        // iPad'de menünün nerede açılacağını belirtmek için sharePositionOrigin gerekli olabilir ama telefonda zorunlu değil.
        await Share.shareXFiles([XFile(file.path)], text: loc.backupShareText);
      } else {
        // --- BİLGİSAYAR İÇİN (Windows/Mac/Linux) ---
        // Klasik "Farklı Kaydet" penceresi aç
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: loc.saveBackupFileTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['onerule'],
        );

        if (outputFile != null) {
          File file = File(outputFile);
          await file.writeAsString(exportString);
          _showSnack(context, loc.backupSavedToDevice);
        }
      }

      passphrase = '';
    } catch (e) {
      _showSnack(context, loc.exportFailed(e.toString()));
    }
  }

  // --- İÇERİ AL (IMPORT) ---
  // Import işlemi hem telefonda hem bilgisayarda "Dosya Seçici" ile çalışır
  Future<void> importPasswords(
    BuildContext context, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    final loc = AppLocalizations.of(context)!;
    try {
      // Dosya seçme penceresi aç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['onerule', 'json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        final extension = result.files.single.extension ?? '';
        if (extension.toLowerCase() == 'json') {
          final ok = await _confirmLegacyJsonImport(context);
          if (!ok) {
            return;
          }
          await _importLegacyJson(context, file, addRecord: addRecord);
          return;
        }

        String encryptedString = await file.readAsString();

        String? passphrase = await _askForPassphrase(
          context,
          title: loc.backupPassphraseTitle,
          hint: loc.backupPassphraseHint,
        );
        if (passphrase == null || passphrase.isEmpty) {
          return;
        }

        final decrypted = await _decryptPayload(encryptedString, passphrase);
        passphrase = '';
        if (decrypted == null) {
          _showSnack(context, loc.importFailedInvalidOrPassword);
          return;
        }

        // JSON'ı listeye çevir
        List<dynamic> jsonList = jsonDecode(decrypted);
        final count = await _importRecords(jsonList, addRecord: addRecord);
        _showSnack(context, loc.passwordsImported(count));
      }
    } catch (e) {
      _showSnack(context, loc.importFailed);
    }
  }

  Future<void> _importLegacyJson(BuildContext context, File file,
      {required Future<void> Function(Map<String, dynamic> record)
          addRecord}) async {
    final loc = AppLocalizations.of(context)!;
    try {
      String jsonString = await file.readAsString();
      List<dynamic> jsonList = jsonDecode(jsonString);
      final count = await _importRecords(jsonList, addRecord: addRecord);

      await _storage.setLegacyJsonImportCompleted();
      _showSnack(context, loc.passwordsImported(count));
    } catch (e) {
      _showSnack(context, loc.importFailed);
    }
  }

  Future<int> _importRecords(
    List<dynamic> jsonList, {
    required Future<void> Function(Map<String, dynamic> record) addRecord,
  }) async {
    int count = 0;
    for (var item in jsonList) {
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
              child: Text(loc.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(loc.legacyImportConfirm),
          ),
        ],
      ),
    );

    return confirmed == true;
  }

  Future<String?> _askForPassphrase(BuildContext context,
      {required String title, required String hint}) async {
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
            decoration: InputDecoration(
              hintText: hint,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel)),
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

  Future<String?> _askForExportPassphrase(BuildContext context,
      {required String title,
      required String hint,
      required String confirmHint}) async {
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
                  decoration: InputDecoration(
                    hintText: hint,
                  ),
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
                  child: Text(loc.cancel)),
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

  Future<Map<String, dynamic>> _encryptPayload(
      String plaintext, String passphrase) async {
    final salt = _randomBytes(16);
    final nonce = _randomBytes(12);
    final key = await _deriveKey(passphrase, salt);
    final aesGcm = AesGcm.with256bits();

    final secretBox = await aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: key,
      nonce: nonce,
    );

    return {
      'v': 1,
      'salt': base64UrlEncode(salt),
      'nonce': base64UrlEncode(secretBox.nonce),
      'cipherText': base64UrlEncode(secretBox.cipherText),
      'mac': base64UrlEncode(secretBox.mac.bytes),
    };
  }

  Future<String?> _decryptPayload(
      String encryptedPayload, String passphrase) async {
    final data = jsonDecode(encryptedPayload);
    if (data is! Map<String, dynamic> || data['v'] != 1) {
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
        SecretBox(
          cipherText,
          nonce: nonce,
          mac: Mac(macBytes),
        ),
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
      iterations: 200000,
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
