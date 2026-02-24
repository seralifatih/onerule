import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class BackupReminderService {
  BackupReminderService._internal({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static final BackupReminderService instance =
      BackupReminderService._internal();

  static const String _channelId = 'backup_restore_reminder';
  static const String _channelName = 'Backup reminders';
  static const String _channelDescription =
      'One-time reminders to test backup restore.';
  static const int _notificationId = 7107;

  static const String _vaultCreatedAtUtcKey = 'vaultCreatedAtUtc';
  static const String _backupReminderScheduledKey = 'backupReminderScheduled';
  static const String _backupReminderPermissionPromptedKey =
      'backupReminderPermissionPrompted';
  static const String _backupReminderPermissionGrantedKey =
      'backupReminderPermissionGranted';
  static const String _backupReminderEnabledKey = 'backupReminderEnabled';

  static const Duration _delayAfterVaultCreation = Duration(days: 7);

  final FlutterLocalNotificationsPlugin _plugin;

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
  }

  Future<void> _scheduleReminderIfEligible({
    required bool requestPermissionIfNeeded,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final remindersEnabled = prefs.getBool(_backupReminderEnabledKey) ?? true;
    if (!remindersEnabled) {
      return;
    }

    final alreadyScheduled =
        prefs.getBool(_backupReminderScheduledKey) ?? false;
    if (alreadyScheduled) {
      return;
    }

    final createdAtRaw = prefs.getString(_vaultCreatedAtUtcKey);
    if (createdAtRaw == null || createdAtRaw.isEmpty) {
      return;
    }

    final createdAtUtc = DateTime.tryParse(createdAtRaw)?.toUtc();
    if (createdAtUtc == null) {
      return;
    }

    final fireAtUtc = createdAtUtc.add(_delayAfterVaultCreation);
    if (!fireAtUtc.isAfter(DateTime.now().toUtc())) {
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
        'Test your backup: make sure you can restore your vault if you lose this phone.',
        scheduleAt,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      await prefs.setBool(_backupReminderScheduledKey, true);
    } catch (_) {
      // Scheduling is best-effort only.
    }
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
