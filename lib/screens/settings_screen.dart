import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';
import 'login_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';
import '../providers/security_settings_provider.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthFacade _authFacade = AuthFacade();
  final BackupFacade _backupFacade = BackupFacade();
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _biometricEnabled = false;
  bool _hardwareAvailable = false; // Cihazda parmak izi var mı?
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadBackupStatus();
  }

  Future<void> _loadSettings() async {
    bool enabled = false;
    bool available = false;

    try {
      enabled = await _authFacade.isBiometricEnabled();
      available = await _authFacade.isBiometricsAvailable();
    } catch (_) {
      enabled = false;
      available = false;
    }

    // GÜNCELLEME: Cihaz desteklemiyorsa veritabanındaki ayarı ARTIK DEĞİŞTİRMİYORUZ.
    // Böylece kullanıcı telefon değiştirirse tercihi (true/false) korunur.
    // UI tarafında switch zaten pasif (disabled) olacak.

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _hardwareAvailable = available; // Donanım durumunu kaydet
      });
    }
  }

  Future<void> _loadBackupStatus() async {
    final lastBackupAt = await _backupFacade.getLastBackupAt();
    if (!mounted) return;
    setState(() {
      _lastBackupAt = lastBackupAt;
    });
  }

  // --- DİALOG FONKSİYONLARI ---
  void _showVerifyCurrentPinDialog() {
    final verifyController = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.verify),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.verifyCurrentPinDescription),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs / 2),
            TextField(
              controller: verifyController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "••••••",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
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
            onPressed: () async {
              bool isValid = await _authFacade.verifyMasterPin(
                verifyController.text,
              );

              // GÜVENLİK: İşlem biter bitmez controller'ı temizle
              verifyController.clear();

              if (isValid && mounted) {
                Navigator.pop(context);
                _showSetNewPinDialog();
              } else if (mounted) {
                Navigator.pop(context);
                final semanticColors =
                    Theme.of(context).extension<AppSemanticColors>() ??
                        AppTheme.fallbackSemanticColors;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc.wrongPin),
                    backgroundColor: semanticColors.destructive,
                  ),
                );
              }
            },
            child: Text(loc.verify),
          ),
        ],
      ),
    );
  }

  void _showSetNewPinDialog() {
    final newPinController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.setNewPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.setNewPinDescription),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs / 2),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "••••••",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
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
            onPressed: () async {
              final newPin = newPinController.text;
              final provider = Provider.of<PasswordProvider>(
                context,
                listen: false,
              );
              try {
                await _authFacade.changeMasterPin(
                  context: context,
                  newPin: newPin,
                  provider: provider,
                );

                // GÜVENLİK: PIN değişti, belleği temizle
                newPinController.clear();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(loc.pinChangeSuccess)));
                }
              } on AuthException catch (_) {
                // Hata durumunda da temizle
                newPinController.clear();
                if (mounted) {
                  final semanticColors =
                      Theme.of(context).extension<AppSemanticColors>() ??
                          AppTheme.fallbackSemanticColors;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc.pinChangeFailed),
                      backgroundColor: semanticColors.destructive,
                    ),
                  );
                }
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  void _showSetPanicPinDialog() {
    final panicController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.setPanicPin),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.enterPanicPin),
            const SizedBox(height: AppSpacing.sm + AppSpacing.xs / 2),
            TextField(
              controller: panicController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "••••••",
                border: OutlineInputBorder(),
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
            style: FilledButton.styleFrom(
              backgroundColor:
                  (Theme.of(context).extension<AppSemanticColors>() ??
                          AppTheme.fallbackSemanticColors)
                      .destructive,
            ),
            onPressed: () async {
              try {
                await _authFacade.setPanicPin(
                  context: context,
                  panicPin: panicController.text,
                );

                // GÜVENLİK: Panik PIN'i bellekte tutma
                panicController.clear();

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(loc.panicPinSet)));
                }
              } on AuthException catch (e) {
                panicController.clear();
                if (mounted) {
                  final semanticColors =
                      Theme.of(context).extension<AppSemanticColors>() ??
                          AppTheme.fallbackSemanticColors;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: semanticColors.destructive,
                    ),
                  );
                }
              }
            },
            child: Text(loc.save),
          ),
        ],
      ),
    );
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  String _autoLockLabel(AppLocalizations loc, int seconds) {
    if (seconds < 60) return loc.secondsShort(seconds);
    final minutes = seconds ~/ 60;
    return loc.minutesShort(minutes);
  }

  String _clipboardClearLabel(AppLocalizations loc, int seconds) {
    if (seconds == 0) return loc.offLabel;
    return loc.secondsShort(seconds);
  }

  Future<void> _showAutoLockPicker(
    SecuritySettingsProvider securitySettings,
  ) async {
    final loc = AppLocalizations.of(context)!;
    const options = <int>[30, 60, 120, 300];
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final textTheme = theme.textTheme;
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.autoLockTitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...options.map(
                  (seconds) => Semantics(
                    button: true,
                    selected: securitySettings.autoLockTimeoutSeconds == seconds,
                    label: '${loc.autoLockTitle}: ${_autoLockLabel(loc, seconds)}',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _autoLockLabel(loc, seconds),
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: securitySettings.autoLockTimeoutSeconds == seconds
                          ? Icon(
                              Icons.check_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, seconds),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    await securitySettings.setAutoLockTimeoutSeconds(selected);
  }

  Future<void> _showClipboardClearPicker(
    SecuritySettingsProvider securitySettings,
  ) async {
    final loc = AppLocalizations.of(context)!;
    const options = <int>[0, 15, 30, 60];
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final textTheme = theme.textTheme;
        final colorScheme = theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.clearClipboardAfterTitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...options.map(
                  (seconds) => Semantics(
                    button: true,
                    selected:
                        securitySettings.clipboardAutoClearSeconds == seconds,
                    label:
                        '${loc.clearClipboardAfterTitle}: ${_clipboardClearLabel(loc, seconds)}',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _clipboardClearLabel(loc, seconds),
                        style: textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                      ),
                      trailing: securitySettings.clipboardAutoClearSeconds ==
                              seconds
                          ? Icon(
                              Icons.check_rounded,
                              color: colorScheme.primary,
                            )
                          : null,
                      onTap: () => Navigator.pop(sheetContext, seconds),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    await securitySettings.setClipboardAutoClearSeconds(selected);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final securitySettings = Provider.of<SecuritySettingsProvider>(context);
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final semanticColors =
        theme.extension<AppSemanticColors>() ?? AppTheme.fallbackSemanticColors;
    final backupStatusText = _lastBackupAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(_lastBackupAt!);

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        children: [
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),

          // --- DİL SEÇİMİ ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    loc.language,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<LanguageMode>(
                    segments: [
                      ButtonSegment(
                        value: LanguageMode.system,
                        label: Text(loc.auto),
                        icon: const Icon(Icons.settings_system_daydream),
                      ),
                      ButtonSegment(
                        value: LanguageMode.en,
                        label: Text(loc.english),
                        icon: const Text("🇺🇸"),
                      ),
                      ButtonSegment(
                        value: LanguageMode.tr,
                        label: Text(loc.turkish),
                        icon: const Text("🇹🇷"),
                      ),
                      ButtonSegment(
                        value: LanguageMode.de,
                        label: const Text("Deutsch"),
                        icon: const Text("🇩🇪"),
                      ),
                    ],
                    selected: {languageProvider.currentMode},
                    onSelectionChanged: (Set<LanguageMode> newSelection) {
                      languageProvider.setLanguage(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg + AppSpacing.xs),

          // --- TEMA SEÇİCİ ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  child: Text(
                    loc.appearance,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(loc.auto),
                        icon: const Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(loc.light),
                        icon: const Icon(Icons.wb_sunny),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(loc.dark),
                        icon: const Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeProvider.setTheme(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      shape: MaterialStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + AppSpacing.xs / 2),
          const Divider(),

          ListTile(
            leading: Icon(
              Icons.lock_reset,
              color: colorScheme.onSurfaceVariant,
            ),
            title: Text(loc.changeMasterPin),
            trailing: const Icon(Icons.arrow_forward_ios, size: AppSpacing.lg),
            onTap: _showVerifyCurrentPinDialog,
          ),

          // --- BİYOMETRİK GİRİŞ ---
          SwitchListTile(
            secondary: Icon(
              Icons.fingerprint,
              color: _hardwareAvailable
                  ? colorScheme.secondary
                  : colorScheme.onSurfaceVariant,
            ),
            title: Text(loc.biometricLogin),
            subtitle: Text(
              _hardwareAvailable
                  ? loc.biometricAvailable
                  : loc.biometricUnavailable,
            ),
            value: _biometricEnabled,
            // Donanım yoksa (available=false) onChanged NULL olur -> Tıklanamaz.
            // Ama yukarıdaki 'value' sayesinde kullanıcının tercihi (açıksa) açık görünür.
            onChanged: _hardwareAvailable
                ? (val) async {
                    await _authFacade.setBiometricEnabled(val);
                    setState(() => _biometricEnabled = val);
                  }
                : null,
          ),
          Semantics(
            button: true,
            label:
                '${loc.autoLockTitle}: ${_autoLockLabel(loc, securitySettings.autoLockTimeoutSeconds)}',
            child: ListTile(
              leading: Icon(
                Icons.timer_outlined,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(loc.autoLockTitle),
              subtitle: Text(
                _autoLockLabel(loc, securitySettings.autoLockTimeoutSeconds),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: AppSpacing.lg),
              onTap: () => _showAutoLockPicker(securitySettings),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              loc.clipboardSectionTitle,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Semantics(
            button: true,
            label:
                '${loc.clearClipboardAfterTitle}: ${_clipboardClearLabel(loc, securitySettings.clipboardAutoClearSeconds)}',
            child: ListTile(
              leading: Icon(
                Icons.content_paste_go_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
              title: Text(loc.clearClipboardAfterTitle),
              subtitle: Text(
                _clipboardClearLabel(
                  loc,
                  securitySettings.clipboardAutoClearSeconds,
                ),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: AppSpacing.lg),
              onTap: () => _showClipboardClearPicker(securitySettings),
            ),
          ),
          Semantics(
            enabled: securitySettings.clipboardAutoClearSeconds > 0,
            hint: securitySettings.clipboardAutoClearSeconds > 0
                ? null
                : loc.enableClipboardAutoClearFirstHint,
            child: SwitchListTile(
              secondary: Icon(
                Icons.alternate_email_rounded,
                color: securitySettings.clipboardAutoClearSeconds > 0
                    ? colorScheme.secondary
                    : colorScheme.onSurfaceVariant,
              ),
              title: Text(loc.alsoClearUsernameCopiesTitle),
              value: securitySettings.applyClipboardPolicyToUsername,
              onChanged: securitySettings.clipboardAutoClearSeconds > 0
                  ? (enabled) async {
                      await securitySettings
                          .setApplyClipboardPolicyToUsername(enabled);
                    }
                  : null,
            ),
          ),

          ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: semanticColors.warning,
            ),
            title: Text(loc.setPanicPin),
            trailing: const Icon(Icons.arrow_forward_ios, size: AppSpacing.lg),
            onTap: _showSetPanicPinDialog,
          ),
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              loc.privacyModeHelperText,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            child: Text(
              loc.dataManagement,
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          ListTile(
            leading: Icon(Icons.upload_file, color: colorScheme.primary),
            title: Text(loc.exportPasswords),
            subtitle: Text(loc.backupLastTimestamp(backupStatusText)),
            onTap: () async {
              final provider = Provider.of<PasswordProvider>(
                context,
                listen: false,
              );
              await _backupFacade.exportPasswords(context, provider);
              await _loadBackupStatus();
            },
          ),

          ListTile(
            leading: Icon(
              Icons.download_for_offline,
              color: colorScheme.secondary,
            ),
            title: Text(loc.importPasswords),
            onTap: () async {
              final provider = Provider.of<PasswordProvider>(
                context,
                listen: false,
              );
              await _backupFacade.importPasswords(context, provider);
              await _loadBackupStatus();
            },
          ),

          const Divider(),

          ListTile(
            leading: Icon(
              Icons.delete_forever,
              color: semanticColors.destructive,
            ),
            title: Text(
              loc.deleteAllData,
              style: textTheme.bodyLarge?.copyWith(
                color: semanticColors.destructive,
              ),
            ),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.deleteAllTitle),
                  content: Text(loc.deleteAllDescription),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel),
                    ),
                    TextButton(
                      onPressed: () async {
                        await _analytics.vaultDeleteAllTriggered();
                        await Provider.of<PasswordProvider>(
                          context,
                          listen: false,
                        ).deleteAllPasswords();
                        final provider = Provider.of<PasswordProvider>(
                          context,
                          listen: false,
                        );
                        await _analytics.vaultDeleteAllListEmptyConfirmed(
                          isEmpty: provider.passwords.isEmpty,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.allPasswordsDeleted)),
                          );
                        }
                      },
                      child: Text(
                        loc.delete,
                        style: textTheme.labelLarge?.copyWith(
                          color: semanticColors.destructive,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(loc.logout),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }
}
