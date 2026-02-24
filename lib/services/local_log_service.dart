import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';

class LocalLogService {
  LocalLogService._();
  static final LocalLogService instance = LocalLogService._();

  static const String _logFileName = 'onerule_debug.log';
  static const int _maxLogBytes = 2 * 1024 * 1024;
  static const int _trimTargetBytes = 1536 * 1024;
  static const String _truncateNotice =
      '[log-truncated] older lines removed to keep local ring buffer within limit.\n';

  bool _initialized = false;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> initializeGlobalErrorHandlers() async {
    if (_initialized) return;
    _initialized = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousFlutterOnError?.call(details);
      unawaited(
        logError(
          source: 'FlutterError.onError',
          error: details.exception,
          stackTrace: details.stack,
        ),
      );
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      unawaited(
        logError(
          source: 'PlatformDispatcher.onError',
          error: error,
          stackTrace: stack,
        ),
      );
      if (previousPlatformOnError != null) {
        return previousPlatformOnError(error, stack);
      }
      return true;
    };
  }

  Future<void> logError({
    required String source,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final next = _writeQueue.then((_) async {
      try {
        final file = await _getLogFile();
        final now = DateTime.now().toIso8601String();
        final sanitizedError = _sanitize(error?.toString() ?? 'Unknown error');
        final sanitizedStack = _sanitize(stackTrace?.toString() ?? 'No stack');

        final payload = StringBuffer()
          ..writeln('[$now] source=$source')
          ..writeln('error=$sanitizedError')
          ..writeln('stack=$sanitizedStack')
          ..writeln('---');

        await file.writeAsString(payload.toString(), mode: FileMode.append);
        await _truncateIfNeeded(file);
      } catch (_) {
        // Intentionally swallow logging failures.
      }
    });
    _writeQueue = next.catchError((_) {});
    return next;
  }

  Future<String> readLogText() async {
    try {
      final file = await _getLogFile();
      if (!await file.exists()) return '';
      final bytes = await file.readAsBytes();
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return '';
    }
  }

  Future<void> exportLog(
    BuildContext context, {
    required bool shareEnabled,
  }) async {
    final loc = AppLocalizations.of(context)!;
    if (!shareEnabled) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.shareCrashReportsDisabled)),
      );
      return;
    }

    try {
      final file = await _getLogFile();
      final exists = await file.exists();
      if (!exists || await file.length() == 0) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.debugLogEmpty)),
        );
        return;
      }

      await Share.shareXFiles(
        [XFile(file.path)],
        text: loc.exportDebugLogTitle,
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.debugLogExportFailed)),
      );
    }
  }

  Future<File> _getLogFile() async {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_logFileName');
    final exists = await file.exists();
    if (!exists) {
      await file.create(recursive: true);
    }
    await _migrateLegacyDocumentsLog(file);
    return file;
  }

  Future<void> _migrateLegacyDocumentsLog(File targetFile) async {
    try {
      if (await targetFile.length() > 0) return;

      final legacyDir = await getApplicationDocumentsDirectory();
      final legacyFile = File(
        '${legacyDir.path}${Platform.pathSeparator}$_logFileName',
      );
      if (!await legacyFile.exists()) return;

      final legacyBytes = await legacyFile.readAsBytes();
      if (legacyBytes.isEmpty) return;

      await targetFile.writeAsBytes(legacyBytes, mode: FileMode.append);
      await _truncateIfNeeded(targetFile);
      await legacyFile.delete();
    } catch (_) {
      // Logging migration failures are non-critical.
    }
  }

  Future<void> _truncateIfNeeded(File file) async {
    final size = await file.length();
    if (size <= _maxLogBytes) return;

    final bytes = await file.readAsBytes();
    if (bytes.length <= _trimTargetBytes) return;
    final keepFrom = bytes.length - _trimTargetBytes;
    final trimmed = bytes.sublist(keepFrom);
    final prefix = utf8.encode(_truncateNotice);
    await file.writeAsBytes(<int>[...prefix, ...trimmed], flush: true);
  }

  String _sanitize(String input) {
    var value = input;

    const secretKeyPattern =
        r'(password|passphrase|secret|token|pin|masterPin|backupPassphrase|cipherText|ciphertext|nonce|iv|mac|tag|salt|plaintext|decrypted|entryContent|content)';

    // Never keep obvious secret-bearing keys.
    value = value.replaceAllMapped(
      RegExp(
        '$secretKeyPattern\\s*[:=]\\s*([^\\s,}\\]]+)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}=[REDACTED]',
    );

    value = value.replaceAllMapped(
      RegExp(
        '("?$secretKeyPattern"?\\s*:\\s*")([^"]*)(")',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED]${m.group(3)}',
    );

    // Entry content keys (title/username/url/category/etc.) are redacted.
    value = value.replaceAllMapped(
      RegExp(
        r'("?(title|username|url|category|createdDate|lastModified|id)"?\s*:\s*")([^"]*)(")',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED]${m.group(4)}',
    );
    value = value.replaceAllMapped(
      RegExp(
        r'\b(title|username|url|category|createdDate|lastModified|id)\s*[:=]\s*([^\s,}\]]+)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}=[REDACTED]',
    );

    // Redact envelope-looking ciphertext chunks.
    value = value.replaceAllMapped(
      RegExp(r'or1:v\d+:(gcm|cbc):[A-Za-z0-9+/_\-=:.]+', caseSensitive: false),
      (_) => '[REDACTED_ENVELOPE]',
    );

    // Redact long base64/hex blobs.
    value = value.replaceAllMapped(
      RegExp(r'[A-Za-z0-9+/_-]{64,}={0,2}'),
      (_) => '[REDACTED_BLOB]',
    );
    value = value.replaceAllMapped(
      RegExp(r'\b[a-fA-F0-9]{64,}\b'),
      (_) => '[REDACTED_HEX]',
    );

    return value;
  }
}
