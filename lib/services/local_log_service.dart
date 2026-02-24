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
  static const int _maxLogBytes = 512 * 1024;

  bool _initialized = false;
  bool _writeInProgress = false;

  Future<void> initializeGlobalErrorHandlers() async {
    if (_initialized) return;
    _initialized = true;

    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previousFlutterOnError?.call(details);
      logError(
        source: 'FlutterError.onError',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    final previousPlatformOnError = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logError(
        source: 'PlatformDispatcher.onError',
        error: error,
        stackTrace: stack,
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
  }) async {
    if (_writeInProgress) return;
    _writeInProgress = true;
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
    } finally {
      _writeInProgress = false;
    }
  }

  Future<void> exportLog(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
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
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}${Platform.pathSeparator}$_logFileName');
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    return file;
  }

  Future<void> _truncateIfNeeded(File file) async {
    final size = await file.length();
    if (size <= _maxLogBytes) return;
    final content = await file.readAsString();
    final keepFrom = content.length ~/ 2;
    await file.writeAsString(content.substring(keepFrom), mode: FileMode.write);
  }

  String _sanitize(String input) {
    var value = input;

    value = value.replaceAllMapped(
      RegExp(
        r'(password|passphrase|secret|token|pin)\s*[:=]\s*([^\s,}\]]+)',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}=[REDACTED]',
    );

    value = value.replaceAllMapped(
      RegExp(
        r'("?(password|passphrase|secret|token|pin)"?\s*:\s*")([^"]*)(")',
        caseSensitive: false,
      ),
      (m) => '${m.group(1)}[REDACTED]${m.group(4)}',
    );

    value = value.replaceAllMapped(
      RegExp(r'[A-Za-z0-9+/_-]{80,}={0,2}'),
      (_) => '[REDACTED_BLOB]',
    );

    return value;
  }
}
