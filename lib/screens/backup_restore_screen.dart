import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../providers/password_provider.dart';
import '../services/app_facade.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupFacade _backupFacade = BackupFacade();
  DateTime? _lastBackupAt;

  @override
  void initState() {
    super.initState();
    _refreshBackupStatus();
  }

  Future<void> _refreshBackupStatus() async {
    final value = await _backupFacade.getLastBackupAt();
    if (!mounted) return;
    setState(() => _lastBackupAt = value);
  }

  Future<void> _createBackup() async {
    final provider = context.read<PasswordProvider>();
    await _backupFacade.exportPasswords(context, provider);
    await _refreshBackupStatus();
  }

  Future<void> _restoreBackup() async {
    final provider = context.read<PasswordProvider>();
    await _backupFacade.importPasswords(context, provider);
    await _refreshBackupStatus();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final backupStatusText = _lastBackupAt == null
        ? loc.backupLastUnknown
        : DateFormat('yyyy-MM-dd HH:mm').format(_lastBackupAt!);

    return Scaffold(
      appBar: AppBar(title: Text(loc.backupRestoreTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.large),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.backupRestoreTitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  loc.backupLastTimestamp(backupStatusText),
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _createBackup,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(loc.createBackupCta),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _restoreBackup,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: Text(loc.restoreFromBackupCta),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            loc.backupGuideTitle,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GuideItem(text: loc.backupGuideStep1),
          _GuideItem(text: loc.backupGuideStep2),
          _GuideItem(text: loc.backupGuideStep3),
          _GuideItem(text: loc.backupGuideStep4),
        ],
      ),
    );
  }
}

class _GuideItem extends StatelessWidget {
  const _GuideItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Icon(
              Icons.circle,
              size: 8,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
