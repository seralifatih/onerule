import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'secure_storage_service.dart';

class BackupReminderService {
  BackupReminderService._internal({
    FlutterLocalNotificationsPlugin? plugin,
    SecureStorageService? secureStorage,
  })  : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
        _secureStorage = secureStorage ?? SecureStorageService();

  static final BackupReminderService instance =
      BackupReminderService._internal();

  static const String _channelId = 'backup_restore_reminder';
  static const String _channelName = 'Backup reminders';
  static const String _channelDescription =
      'Monthly reminders to refresh your encrypted OneRule backup.';
  static const int _notificationId = 7107;

  static const String _vaultCreatedAtUtcKey = 'vaultCreatedAtUtc';
  static const String _backupReminderScheduledKey = 'backupReminderScheduled';
  static const String _backupReminderScheduledAtUtcKey =
      'backupReminderScheduledAtUtc';
  static const String _backupReminderPermissionPromptedKey =
      'backupReminderPermissionPrompted';
  static const String _backupReminderPermissionGrantedKey =
      'backupReminderPermissionGranted';
  static const String _backupReminderEnabledKey = 'backupReminderEnabled';

  static const Duration _backupFreshnessWindow = Duration(days: 30);

  final FlutterLocalNotificationsPlugin _plugin;
  final SecureStorageService _secureStorage;

  bool _initialized = false;
  tz.Location _location = tz.UTC;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings();
      const settings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(settings);
      await _configureTimezone();
      _initialized = true;

      unawaited(
        _scheduleReminderIfEligible(
          requestPermissionIfNeeded: false,
          forceReschedule: false,
        ),
      );
    } catch (_) {
      // Notification stack may be unavailable in test environments.
    }
  }

  Future<void> recordVaultCreationAndSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_vaultCreatedAtUtcKey)) {
      await prefs.setString(
        _vaultCreatedAtUtcKey,
        DateTime.now().toUtc().toIso8601String(),
      );
    }

    unawaited(
      _scheduleReminderIfEligible(
        requestPermissionIfNeeded: true,
        forceReschedule: false,
      ),
    );
  }

  Future<void> onBackupCreated(DateTime _) async {
    unawaited(
      _scheduleReminderIfEligible(
        requestPermissionIfNeeded: false,
        forceReschedule: true,
      ),
    );
  }

  Future<void> onReminderPreferenceChanged(bool enabled) async {
    if (!enabled) {
      await cancelReminder();
      return;
    }

    await _scheduleReminderIfEligible(
      requestPermissionIfNeeded: false,
      forceReschedule: true,
    );
  }

  Future<void> cancelReminder() async {
    await initialize();
    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {
      // Ignore cancellation failures.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_backupReminderScheduledKey, false);
    await prefs.remove(_backupReminderScheduledAtUtcKey);
  }

  Future<void> _scheduleReminderIfEligible({
    required bool requestPermissionIfNeeded,
    required bool forceReschedule,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final remindersEnabled = prefs.getBool(_backupReminderEnabledKey) ?? true;
    if (!remindersEnabled) {
      return;
    }

    final alreadyScheduled =
        prefs.getBool(_backupReminderScheduledKey) ?? false;
    final hasNextScheduledAt =
        prefs.getString(_backupReminderScheduledAtUtcKey) != null;

    if (alreadyScheduled && hasNextScheduledAt && !forceReschedule) {
      return;
    }

    final referenceUtc = await _resolveBackupReferenceUtc(prefs);
    if (referenceUtc == null) {
      return;
    }

    final permissionGranted = await _ensureNotificationPermission(
      requestIfNeeded: requestPermissionIfNeeded,
      prefs: prefs,
    );
    if (!permissionGranted) {
      return;
    }

    await initialize();

    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {
      // Ignore cancellation failures and continue with scheduling.
    }

    final nowUtc = DateTime.now().toUtc();
    final dueUtc = referenceUtc.add(_backupFreshnessWindow);

    DateTime fireAtUtc;
    int daysSinceBackup;

    if (dueUtc.isAfter(nowUtc)) {
      fireAtUtc = dueUtc;
      daysSinceBackup = fireAtUtc.difference(referenceUtc).inDays;
    } else {
      fireAtUtc = nowUtc.add(const Duration(minutes: 1));
      daysSinceBackup = nowUtc.difference(referenceUtc).inDays;
    }

    final scheduleAt = tz.TZDateTime.from(fireAtUtc.toLocal(), _location);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _plugin.zonedSchedule(
        _notificationId,
        'OneRule',
        _buildReminderBody(daysSinceBackup),
        scheduleAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      );

      await prefs.setBool(_backupReminderScheduledKey, true);
      await prefs.setString(
        _backupReminderScheduledAtUtcKey,
        fireAtUtc.toIso8601String(),
      );
    } catch (_) {
      // Scheduling is best-effort only.
    }
  }

  Future<DateTime?> _resolveBackupReferenceUtc(SharedPreferences prefs) async {
    final lastBackupLocal = await _secureStorage.getLastBackupAt();
    if (lastBackupLocal != null) {
      return lastBackupLocal.toUtc();
    }

    final createdAtRaw = prefs.getString(_vaultCreatedAtUtcKey);
    if (createdAtRaw == null || createdAtRaw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(createdAtRaw)?.toUtc();
  }

  String _buildReminderBody(int daysSinceBackup) {
    final effectiveDays = daysSinceBackup < 30 ? 30 : daysSinceBackup;
    return 'Last backup: $effectiveDays days ago. Create a new one?';
  }

  Future<void> _configureTimezone() async {
    try {
      tzdata.initializeTimeZones();
      final localTzName = await FlutterTimezone.getLocalTimezone();
      _location = tz.getLocation(localTzName);
      tz.setLocalLocation(_location);
    } catch (_) {
      _location = tz.local;
    }
  }

  Future<bool> _ensureNotificationPermission({
    required bool requestIfNeeded,
    required SharedPreferences prefs,
  }) async {
    await initialize();

    if (kIsWeb) {
      return false;
    }

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl == null) {
        return true;
      }

      final currentlyEnabled = await androidImpl.areNotificationsEnabled();
      if (currentlyEnabled == true) {
        await prefs.setBool(_backupReminderPermissionGrantedKey, true);
        return true;
      }

      await prefs.setBool(_backupReminderPermissionGrantedKey, false);

      if (!requestIfNeeded) {
        return false;
      }

      final promptedBefore =
          prefs.getBool(_backupReminderPermissionPromptedKey) ?? false;
      if (promptedBefore) {
        return false;
      }

      await prefs.setBool(_backupReminderPermissionPromptedKey, true);
      final granted = await androidImpl.requestNotificationsPermission();
      await prefs.setBool(_backupReminderPermissionGrantedKey, granted == true);
      return granted == true;
    }

    if (Platform.isIOS || Platform.isMacOS) {
      final promptedBefore =
          prefs.getBool(_backupReminderPermissionPromptedKey) ?? false;
      if (promptedBefore) {
        return prefs.getBool(_backupReminderPermissionGrantedKey) ?? false;
      }

      if (!requestIfNeeded) {
        return false;
      }

      await prefs.setBool(_backupReminderPermissionPromptedKey, true);

      if (Platform.isIOS) {
        final iosImpl = _plugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
        if (iosImpl == null) {
          return true;
        }
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        await prefs.setBool(
          _backupReminderPermissionGrantedKey,
          granted == true,
        );
        return granted == true;
      }

      final macImpl = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      if (macImpl == null) {
        return true;
      }
      final granted = await macImpl.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      await prefs.setBool(
        _backupReminderPermissionGrantedKey,
        granted == true,
      );
      return granted == true;
    }

    return false;
  }
}
