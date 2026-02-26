import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettingsProvider extends ChangeNotifier {
  static const String _autoLockTimeoutKey = 'autoLockTimeoutSeconds';
  static const String _clipboardAutoClearSecondsKey =
      'clipboardAutoClearSeconds';
  static const String _applyClipboardPolicyToUsernameKey =
      'applyClipboardPolicyToUsername';
  static const String _shareCrashReportsKey = 'shareCrashReportsEnabled';
  static const String _backupReminderEnabledKey = 'backupReminderEnabled';
  static const int defaultAutoLockTimeoutSeconds = 60;
  static const int defaultClipboardAutoClearSeconds = 30;
  static const bool defaultApplyClipboardPolicyToUsername = false;
  static const bool defaultShareCrashReportsEnabled = false;
  static const bool defaultBackupReminderEnabled = true;
  static const Set<int> _allowedAutoLockTimeouts = <int>{30, 60, 120, 300};

  int _autoLockTimeoutSeconds = defaultAutoLockTimeoutSeconds;
  int get autoLockTimeoutSeconds => _autoLockTimeoutSeconds;
  int _clipboardAutoClearSeconds = defaultClipboardAutoClearSeconds;
  int get clipboardAutoClearSeconds => _clipboardAutoClearSeconds;
  bool _applyClipboardPolicyToUsername = defaultApplyClipboardPolicyToUsername;
  bool get applyClipboardPolicyToUsername => _applyClipboardPolicyToUsername;
  bool _shareCrashReportsEnabled = defaultShareCrashReportsEnabled;
  bool get shareCrashReportsEnabled => _shareCrashReportsEnabled;
  bool _backupReminderEnabled = defaultBackupReminderEnabled;
  bool get backupReminderEnabled => _backupReminderEnabled;

  SecuritySettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final storedAutoLock = prefs.getInt(_autoLockTimeoutKey);
    _autoLockTimeoutSeconds = _sanitizeAutoLockTimeout(storedAutoLock);
    _clipboardAutoClearSeconds = prefs.getInt(_clipboardAutoClearSecondsKey) ??
        defaultClipboardAutoClearSeconds;
    _applyClipboardPolicyToUsername =
        prefs.getBool(_applyClipboardPolicyToUsernameKey) ??
            defaultApplyClipboardPolicyToUsername;
    _shareCrashReportsEnabled =
        prefs.getBool(_shareCrashReportsKey) ?? defaultShareCrashReportsEnabled;
    _backupReminderEnabled = prefs.getBool(_backupReminderEnabledKey) ??
        defaultBackupReminderEnabled;
    notifyListeners();
  }

  Future<void> setAutoLockTimeoutSeconds(int seconds) async {
    seconds = _sanitizeAutoLockTimeout(seconds);
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

  Future<void> setShareCrashReportsEnabled(bool enabled) async {
    if (_shareCrashReportsEnabled == enabled) return;
    _shareCrashReportsEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_shareCrashReportsKey, enabled);
  }

  Future<void> setBackupReminderEnabled(bool enabled) async {
    if (_backupReminderEnabled == enabled) return;
    _backupReminderEnabled = enabled;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupReminderEnabledKey, enabled);
  }

  int _sanitizeAutoLockTimeout(int? rawSeconds) {
    if (rawSeconds == null || !_allowedAutoLockTimeouts.contains(rawSeconds)) {
      return defaultAutoLockTimeoutSeconds;
    }
    return rawSeconds;
  }
}
