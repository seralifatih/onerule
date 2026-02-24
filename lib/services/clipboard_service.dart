import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ClipboardPayloadType { password, username }

class ClipboardService {
  ClipboardService._();

  static final ClipboardService instance = ClipboardService._();

  static const String copiedToClipboardKey = 'copiedToClipboard';
  static const String usernameCopiedKey = 'usernameCopied';

  static const String _clipboardAutoClearSecondsKey =
      'clipboardAutoClearSeconds';
  static const String _applyClipboardPolicyToUsernameKey =
      'applyClipboardPolicyToUsername';
  static const int _defaultClipboardAutoClearSeconds = 30;
  static const bool _defaultApplyClipboardPolicyToUsername = false;
  static const Duration _snackDuration = Duration(seconds: 2);

  Timer? _autoClearTimer;
  String? _lastCopiedValue;

  Future<void> copyWithAutoClear(
    BuildContext context,
    String value, {
    required String successMessageKey,
    ClipboardPayloadType payloadType = ClipboardPayloadType.password,
  }) async {
    await Clipboard.setData(ClipboardData(text: value));
    _lastCopiedValue = value;

    final policy = await _readClipboardPolicy();
    _autoClearTimer?.cancel();

    final shouldAutoClear = _shouldAutoClear(payloadType, policy);
    if (shouldAutoClear) {
      _autoClearTimer = Timer(Duration(seconds: policy.seconds), () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text == _lastCopiedValue && data?.text == value) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      });
    }

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
        return loc.copiedToClipboard;
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

  Future<_ClipboardPolicy> _readClipboardPolicy() async {
    final prefs = await SharedPreferences.getInstance();
    final seconds = prefs.getInt(_clipboardAutoClearSecondsKey) ??
        _defaultClipboardAutoClearSeconds;
    final applyToUsername = prefs.getBool(_applyClipboardPolicyToUsernameKey) ??
        _defaultApplyClipboardPolicyToUsername;
    return _ClipboardPolicy(seconds: seconds, applyToUsername: applyToUsername);
  }

  bool _shouldAutoClear(
    ClipboardPayloadType payloadType,
    _ClipboardPolicy policy,
  ) {
    if (policy.seconds <= 0) return false;
    if (payloadType == ClipboardPayloadType.username &&
        !policy.applyToUsername) {
      return false;
    }
    return true;
  }
}

class _ClipboardPolicy {
  const _ClipboardPolicy({
    required this.seconds,
    required this.applyToUsername,
  });

  final int seconds;
  final bool applyToUsername;
}
