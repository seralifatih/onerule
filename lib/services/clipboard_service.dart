import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';

class ClipboardService {
  ClipboardService._();

  static final ClipboardService instance = ClipboardService._();

  static const String copiedToClipboardKey = 'copiedToClipboard';
  static const String usernameCopiedKey = 'usernameCopied';

  static const Duration _autoClearDelay = Duration(seconds: 30);
  static const Duration _snackDuration = Duration(seconds: 2);

  Timer? _autoClearTimer;
  String? _lastCopiedValue;

  Future<void> copyWithAutoClear(
    BuildContext context,
    String value, {
    required String successMessageKey,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    _lastCopiedValue = value;

    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(_autoClearDelay, () async {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == _lastCopiedValue && data?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });

    if (!context.mounted) return;
    _showSnackBar(
      context: context,
      message: _messageForKey(
        AppLocalizations.of(context)!,
        successMessageKey,
      ),
    );
  }

  String _messageForKey(AppLocalizations loc, String key) {
    switch (key) {
      case copiedToClipboardKey:
        return loc.copiedToClipboard;
      case usernameCopiedKey:
        return loc.usernameCopied;
      default:
        return loc.copiedToClipboard;
    }
  }

  void _showSnackBar({
    required BuildContext context,
    required String message,
  }) {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          duration: _snackDuration,
        ),
      );
  }
}
