import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';
import '../services/backup_reminder_service.dart';
import '../services/credential_provider.dart';
import '../services/secure_storage_service.dart';
import 'autofill_setup_screen.dart';
import 'backup_restore_screen.dart';
import 'logs_screen.dart';
import 'login_screen.dart';
import 'vault_health_screen.dart';
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
  final AnalyticsService _analytics = AnalyticsService.instance;
  final CredentialProvider _credentialProvider = PlatformCredentialProvider();

  bool _biometricEnabled = false;
  bool _hardwareAvailable = false;
  bool _autofillSupported = false;
  bool _autofillEnabled = false;

  static const _buyMeCoffeeUrl = 'https://buymeacoffee.com/seralifatih';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    bool enabled = false;
    bool available = false;
    bool autofillSupported = false;
    bool autofillEnabled = false;

    try {
      enabled = await _authFacade.isBiometricEnabled();
      available = await _authFacade.isBiometricsAvailable();
    } catch (_) {}

    try {
      autofillSupported = await _credentialProvider.isSupported();
      autofillEnabled =
          autofillSupported ? await _credentialProvider.isEnabled() : false;
    } catch (_) {}

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _hardwareAvailable = available;
        _autofillSupported = autofillSupported;
        _autofillEnabled = autofillEnabled;
      });
    }
  }

  Future<void> _openBuyMeCoffee() async {
    final uri = Uri.parse(_buyMeCoffeeUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.openLinkFailed)),
        );
      }
    }
  }

  // ── Dialogs (unchanged logic) ─────────────────────────────────────────────

  void _showVerifyCurrentPinDialog() {
    final verifyController = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.verify),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.verifyCurrentPinDescription),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: verifyController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '••••••',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              final isValid = await _authFacade.verifyMasterPin(
                verifyController.text,
              );
              verifyController.clear();
              if (!mounted) return;
              navigator.pop();
              if (isValid) {
                _showSetNewPinDialog();
                return;
              }
              final semanticColors =
                  Theme.of(context).extension<AppSemanticColors>() ??
                      AppTheme.fallbackSemanticColors;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(loc.wrongPin),
                  backgroundColor: semanticColors.destructive,
                ),
              );
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
      builder: (dialogContext) => AlertDialog(
        title: Text(loc.setNewPinTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(loc.setNewPinDescription),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: newPinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '••••••',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(loc.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final newPin = newPinController.text;
              final navigator = Navigator.of(dialogContext);
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
                newPinController.clear();
                if (!mounted) return;
                navigator.pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(loc.pinChangeSuccess)),
                );
              } on AuthException catch (_) {
                newPinController.clear();
                if (!mounted) return;
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
    bool confirmed = false;
    String? localError;

    showDialog(
      context: context,
      builder: (context) {
        final semanticColors =
            Theme.of(context).extension<AppSemanticColors>() ??
                AppTheme.fallbackSemanticColors;
        final textTheme = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(loc.setPanicPin),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: semanticColors.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.panicPinInfoTitle,
                          style: textTheme.labelLarge?.copyWith(
                            color: semanticColors.warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '- ${loc.panicPinInfoWhatItDoes}\n'
                          '- ${loc.panicPinInfoDecoyVault}\n'
                          '- ${loc.panicPinInfoRisk}',
                          style: textTheme.bodySmall?.copyWith(
                            color: semanticColors.warning,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(loc.enterPanicPin),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: panicController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: '••••••',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  CheckboxListTile(
                    value: confirmed,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(loc.panicPinConfirmLabel),
                    onChanged: (value) {
                      setDialogState(() {
                        confirmed = value ?? false;
                        localError = null;
                      });
                    },
                  ),
                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text(
                        localError!,
                        style: textTheme.bodySmall?.copyWith(
                          color: semanticColors.destructive,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(loc.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: semanticColors.destructive,
                ),
                onPressed: () async {
                  if (!confirmed) {
                    setDialogState(
                      () => localError = loc.panicPinConfirmRequired,
                    );
                    return;
                  }
                  final navigator = Navigator.of(context);
                  try {
                    await _authFacade.setPanicPin(
                      context: this.context,
                      panicPin: panicController.text,
                    );
                    panicController.clear();
                    if (!mounted) return;
                    navigator.pop();
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text(loc.panicPinSet)),
                    );
                  } on AuthException catch (e) {
                    panicController.clear();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(e.message),
                        backgroundColor: semanticColors.destructive,
                      ),
                    );
                  }
                },
                child: Text(loc.save),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final provider = Provider.of<PasswordProvider>(context, listen: false);
    SecureStorageService().clearSessionKey();
    await _credentialProvider.onVaultLocked();
    await provider.lockForSession();
    if (!mounted) return;
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
                Text(loc.autoLockTitle,
                    style: textTheme.titleMedium
                        ?.copyWith(color: colorScheme.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                ...options.map(
                  (seconds) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_autoLockLabel(loc, seconds),
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.onSurface)),
                    trailing:
                        securitySettings.autoLockTimeoutSeconds == seconds
                            ? Icon(Icons.check_rounded,
                                color: colorScheme.primary)
                            : null,
                    onTap: () => Navigator.pop(sheetContext, seconds),
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
                Text(loc.clearClipboardAfterTitle,
                    style: textTheme.titleMedium
                        ?.copyWith(color: colorScheme.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                ...options.map(
                  (seconds) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_clipboardClearLabel(loc, seconds),
                        style: textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.onSurface)),
                    trailing:
                        securitySettings.clipboardAutoClearSeconds == seconds
                            ? Icon(Icons.check_rounded,
                                color: colorScheme.primary)
                            : null,
                    onTap: () => Navigator.pop(sheetContext, seconds),
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'VAULT SETTINGS',
          style: textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.0,
            fontSize: 13,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.giant + AppSpacing.xl,
        ),
        children: [
          // ── Appearance & Localization ────────────────────────────────────
          _buildSectionHeader(
            context,
            'APPEARANCE & LOCALIZATION',
            colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language tile
              Expanded(
                child: _buildTile(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTileLabel(context, loc.language),
                      const SizedBox(height: AppSpacing.sm),
                      ...[
                        (LanguageMode.system, loc.auto,
                            Icons.settings_system_daydream_outlined),
                        (LanguageMode.en, loc.english, Icons.language_rounded),
                        (LanguageMode.tr, loc.turkish, Icons.language_rounded),
                        (LanguageMode.de, 'Deutsch', Icons.language_rounded),
                      ].map((entry) {
                        final (mode, label, icon) = entry;
                        final isSelected =
                            languageProvider.currentMode == mode;
                        return GestureDetector(
                          onTap: () => languageProvider.setLanguage(mode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.surfaceContainerHigh
                                  : Colors.transparent,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                              border: isSelected
                                  ? Border.all(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.4),
                                    )
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(icon,
                                    size: 16,
                                    color: isSelected
                                        ? colorScheme.primary
                                        : colorScheme.onSurfaceVariant),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    label,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: isSelected
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_circle_rounded,
                                      size: 16, color: colorScheme.primary),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Theme tile
              Expanded(
                child: _buildTile(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTileLabel(context, loc.appearance),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          (ThemeMode.system, loc.auto,
                              Icons.brightness_auto_rounded),
                          (ThemeMode.light, loc.light,
                              Icons.wb_sunny_rounded),
                          (ThemeMode.dark, loc.dark,
                              Icons.dark_mode_rounded),
                        ].map((entry) {
                          final (mode, label, icon) = entry;
                          final isSelected =
                              themeProvider.themeMode == mode;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => themeProvider.setTheme(mode),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.sm,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? colorScheme.surfaceContainerHighest
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.medium),
                                  border: isSelected
                                      ? Border.all(
                                          color: colorScheme.primary
                                              .withValues(alpha: 0.4),
                                        )
                                      : null,
                                ),
                                child: Column(
                                  children: [
                                    Icon(icon,
                                        size: 18,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant),
                                    const SizedBox(height: 3),
                                    Text(
                                      label.toUpperCase(),
                                      style: textTheme.labelSmall?.copyWith(
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 8,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Security Protocol ────────────────────────────────────────────
          _buildSectionHeader(context, 'SECURITY PROTOCOL', colorScheme.tertiary),
          const SizedBox(height: AppSpacing.sm),
          _buildGroupCard(
            context,
            children: [
              _buildListItem(
                context,
                icon: Icons.lock_reset_rounded,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.primary,
                title: loc.changeMasterPin,
                subtitle: 'Update encryption key',
                onTap: _showVerifyCurrentPinDialog,
              ),
              _buildDivider(context),
              _buildSwitchItem(
                context,
                icon: Icons.fingerprint_rounded,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.primary,
                title: loc.biometricLogin,
                subtitle: _hardwareAvailable
                    ? loc.biometricAvailable
                    : loc.biometricUnavailable,
                value: _biometricEnabled,
                onChanged: _hardwareAvailable
                    ? (val) async {
                        if (val) {
                          final outcome =
                              await _authFacade.attemptBiometricUnlock(
                            provider: Provider.of<PasswordProvider>(
                              context,
                              listen: false,
                            ),
                            localizedReason:
                                'Confirm your biometric to enable unlock',
                          );
                          if (outcome ==
                                  BiometricUnlockOutcome.failedOrCanceled ||
                              outcome == BiometricUnlockOutcome.unavailable) {
                            return;
                          }
                        }
                        await _authFacade.setBiometricEnabled(val);
                        if (mounted) setState(() => _biometricEnabled = val);
                      }
                    : null,
              ),
              _buildDivider(context),
              _buildListItem(
                context,
                icon: Icons.emergency_share_rounded,
                iconBg: colorScheme.errorContainer.withValues(alpha: 0.3),
                iconColor: colorScheme.error,
                title: loc.setPanicPin,
                subtitle: 'Emergency data wipe',
                onTap: _showSetPanicPinDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Session & Clipboard ──────────────────────────────────────────
          _buildSectionHeader(
              context, loc.clipboardSectionTitle, colorScheme.secondary),
          const SizedBox(height: AppSpacing.sm),
          _buildGroupCard(
            context,
            children: [
              _buildListItem(
                context,
                icon: Icons.timer_outlined,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.primary,
                title: loc.autoLockTitle,
                subtitle: _autoLockLabel(
                    loc, securitySettings.autoLockTimeoutSeconds),
                onTap: () => _showAutoLockPicker(securitySettings),
              ),
              _buildDivider(context),
              _buildListItem(
                context,
                icon: Icons.content_paste_go_rounded,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.primary,
                title: loc.clearClipboardAfterTitle,
                subtitle: _clipboardClearLabel(
                    loc, securitySettings.clipboardAutoClearSeconds),
                onTap: () => _showClipboardClearPicker(securitySettings),
              ),
              _buildDivider(context),
              _buildSwitchItem(
                context,
                icon: Icons.alternate_email_rounded,
                iconBg: colorScheme.secondaryContainer,
                iconColor: securitySettings.clipboardAutoClearSeconds > 0
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                title: loc.alsoClearUsernameCopiesTitle,
                value: securitySettings.applyClipboardPolicyToUsername,
                onChanged: securitySettings.clipboardAutoClearSeconds > 0
                    ? (enabled) async {
                        await securitySettings
                            .setApplyClipboardPolicyToUsername(enabled);
                      }
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Security Tools ───────────────────────────────────────────────
          _buildSectionHeader(
              context, 'SECURITY TOOLS', colorScheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.sm),
          _buildGroupCard(
            context,
            children: [
              _buildListItem(
                context,
                icon: Icons.health_and_safety_outlined,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.primary,
                title: loc.vaultHealthTitle,
                subtitle: loc.vaultHealthSubtitle,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VaultHealthScreen(),
                    ),
                  );
                },
              ),
              if (_autofillSupported) ...[
                _buildDivider(context),
                _buildListItem(
                  context,
                  icon: Icons.touch_app_outlined,
                  iconBg: colorScheme.secondaryContainer,
                  iconColor: _autofillEnabled
                      ? semanticColors.success
                      : colorScheme.onSurfaceVariant,
                  title: loc.autofillTitle,
                  subtitle: _autofillEnabled
                      ? loc.autofillEnabledSubtitle
                      : loc.autofillDisabledSubtitle,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AutofillSetupScreen(),
                      ),
                    );
                    _loadSettings();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Data Management ──────────────────────────────────────────────
          _buildSectionHeader(
              context, 'DATA MANAGEMENT', colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _buildIconTile(
                  context,
                  icon: Icons.upload_rounded,
                  label: 'Export Vault',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildIconTile(
                  context,
                  icon: Icons.download_rounded,
                  label: 'Import Vault',
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const BackupRestoreScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildGroupCard(
            context,
            children: [
              _buildSwitchItem(
                context,
                icon: Icons.notifications_active_outlined,
                iconBg: colorScheme.secondaryContainer,
                iconColor: securitySettings.backupReminderEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                title: loc.backupReminderTitle,
                subtitle: loc.backupReminderSubtitle,
                value: securitySettings.backupReminderEnabled,
                onChanged: (enabled) async {
                  await securitySettings.setBackupReminderEnabled(enabled);
                  await BackupReminderService.instance
                      .onReminderPreferenceChanged(enabled);
                },
              ),
              _buildDivider(context),
              _buildListItem(
                context,
                icon: Icons.article_outlined,
                iconBg: colorScheme.secondaryContainer,
                iconColor: colorScheme.onSurfaceVariant,
                title: loc.viewLogsTitle,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LogsScreen(),
                    ),
                  );
                },
              ),
              _buildDivider(context),
              _buildSwitchItem(
                context,
                icon: Icons.shield_outlined,
                iconBg: colorScheme.secondaryContainer,
                iconColor: securitySettings.shareCrashReportsEnabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
                title: loc.shareCrashReportsTitle,
                subtitle: loc.shareCrashReportsSubtitle,
                value: securitySettings.shareCrashReportsEnabled,
                onChanged: (enabled) async {
                  await securitySettings.setShareCrashReportsEnabled(enabled);
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Delete All
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: Text(loc.deleteAllTitle),
                  content: Text(loc.deleteAllDescription),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(loc.cancel),
                    ),
                    TextButton(
                      onPressed: () async {
                        final navigator = Navigator.of(dialogContext);
                        final provider = Provider.of<PasswordProvider>(
                          this.context,
                          listen: false,
                        );
                        await _analytics.vaultDeleteAllTriggered();
                        await provider.deleteAllPasswords();
                        await _analytics.vaultDeleteAllListEmptyConfirmed(
                          isEmpty: provider.passwords.isEmpty,
                        );
                        if (!mounted) return;
                        navigator.pop();
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                              content: Text(loc.allPasswordsDeleted)),
                        );
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
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(
                  color: colorScheme.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    child: Icon(Icons.delete_forever,
                        size: 18, color: colorScheme.onPrimary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.deleteAllData,
                          style: textTheme.labelLarge?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Irreversible action',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.error.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.warning_rounded,
                      color: colorScheme.error.withValues(alpha: 0.6),
                      size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Support ──────────────────────────────────────────────────────
          _buildSectionHeader(
              context, loc.supportDevelopmentTitle, colorScheme.outline),
          const SizedBox(height: AppSpacing.sm),
          _buildGroupCard(
            context,
            children: [
              _buildListItem(
                context,
                icon: Icons.coffee_rounded,
                iconBg: const Color(0xFFFFDD00).withValues(alpha: 0.15),
                iconColor: const Color(0xFFFFDD00),
                title: loc.buyMeCoffeeTitle,
                subtitle: loc.supportDevelopmentBody,
                trailing: Icon(Icons.open_in_new_rounded,
                    size: 14, color: colorScheme.onSurfaceVariant),
                onTap: _openBuyMeCoffee,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Logout ───────────────────────────────────────────────────────
          GestureDetector(
            onTap: _logout,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.large),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded,
                      size: 18, color: colorScheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    loc.logout.toUpperCase(),
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.error,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Text(
              'v2.0.2 • AES-256 ENCRYPTED',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                letterSpacing: 1.5,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────

  Widget _buildSectionHeader(
      BuildContext context, String label, Color accentColor) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildTileLabel(BuildContext context, String label) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label.toUpperCase(),
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        fontSize: 9,
      ),
    );
  }

  Widget _buildTile(BuildContext context, {required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: child,
    );
  }

  Widget _buildGroupCard(BuildContext context,
      {required List<Widget> children}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildIconTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: colorScheme.primary, size: 24),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
      height: 1,
      indent: AppSpacing.lg + 36 + AppSpacing.md,
      color: colorScheme.outlineVariant.withValues(alpha: 0.25),
    );
  }
}
