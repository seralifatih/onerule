import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettingsProvider extends ChangeNotifier {
  static const String _autoLockTimeoutKey = 'autoLockTimeoutSeconds';
  static const String _clipboardAutoClearSecondsKey =
      'clipboardAutoClearSeconds';
  static const String _applyClipboardPolicyToUsernameKey =
      'applyClipboardPolicyToUsername';
  static const int defaultAutoLockTimeoutSeconds = 60;
  static const int defaultClipboardAutoClearSeconds = 30;
  static const bool defaultApplyClipboardPolicyToUsername = false;

  int _autoLockTimeoutSeconds = defaultAutoLockTimeoutSeconds;
  int get autoLockTimeoutSeconds => _autoLockTimeoutSeconds;
  int _clipboardAutoClearSeconds = defaultClipboardAutoClearSeconds;
  int get clipboardAutoClearSeconds => _clipboardAutoClearSeconds;
  bool _applyClipboardPolicyToUsername = defaultApplyClipboardPolicyToUsername;
  bool get applyClipboardPolicyToUsername => _applyClipboardPolicyToUsername;

  SecuritySettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _autoLockTimeoutSeconds =
        prefs.getInt(_autoLockTimeoutKey) ?? defaultAutoLockTimeoutSeconds;
    _clipboardAutoClearSeconds = prefs.getInt(_clipboardAutoClearSecondsKey) ??
        defaultClipboardAutoClearSeconds;
    _applyClipboardPolicyToUsername =
        prefs.getBool(_applyClipboardPolicyToUsernameKey) ??
            defaultApplyClipboardPolicyToUsername;
    notifyListeners();
  }

  Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    if (_autoLockTimeoutSeconds == seconds) return;
    _autoLockTimeoutSeconds = seconds;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockTimeoutKey, seconds);
  }

  Future<void> setClipboardAutoClearSeconds(int seconds) async {
    if (_clipboardAutoClearSeconds == seconds) return;
    _clipboardAutoClearSeconds = seconds;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_clipboardAutoClearSecondsKey, seconds);
  }

  Future<void> setApplyClipboardPolicyToUsername(bool enabled) async {
    if (_applyClipboardPolicyToUsername == enabled) return;
    _applyClipboardPolicyToUsername = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_applyClipboardPolicyToUsernameKey, enabled);
  }
}
