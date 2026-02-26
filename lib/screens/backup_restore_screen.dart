import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';

import '../providers/password_provider.dart';
import '../services/app_facade.dart';
import '../services/backup_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

enum _RestoreUiError {
  noFile,
  wrongPin,
  corruptFile,
  unknown,
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupFacade _backupFacade = BackupFacade();
  final TextEditingController _restorePinController = TextEditingController();

  DateTime? _lastBackupAt;
  File? _selectedRestoreFile;
  bool _isRestoring = false;
  _RestoreUiError? _restoreError;
  String? _restoreSuccessMessage;

  @override
  void initState() {
    super.initState();
    _refreshBackupStatus();
  }

  @override
  void dispose() {
    _restorePinController.dispose();
    super.dispose();
  }

  Future<void> _refreshBackupStatus() async {
    final value = await _backupFacade.getLastBackupAt();
    if (!mounted) return;
    setState(() => _lastBackupAt = value);
  }

  Future<void> _openCreateBackupWizard() async {
    final provider = context.read<PasswordProvider>();

    final created = await showDialog<BackupExportResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CreateBackupWizardDialog(
        backupFacade: _backupFacade,
        provider: provider,
      ),
    );

    if (created == null || !mounted) {
      return;
    }

    await _refreshBackupStatus();
  }

  Future<void> _pickRestoreFile() async {
    final file = await _backupFacade.pickBackupFileForRestore();
    if (!mounted || file == null) return;

    setState(() {
      _selectedRestoreFile = file;
      _restoreError = null;
      _restoreSuccessMessage = null;
    });
  }

  Future<void> _restoreBackup() async {
    final file = _selectedRestoreFile;
    if (file == null) {
      setState(() {
        _restoreError = _RestoreUiError.noFile;
        _restoreSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isRestoring = true;
      _restoreError = null;
      _restoreSuccessMessage = null;
    });

    final provider = context.read<PasswordProvider>();
    final result = await _backupFacade.restoreFromFile(
      provider: provider,
      file: file,
      passphrase: _restorePinController.text,
    );

    if (!mounted) return;

    setState(() {
      _isRestoring = false;
      if (result.isSuccess) {
        final loc = AppLocalizations.of(context)!;
        _restoreSuccessMessage = loc.passwordsImported(result.importedCount);
        _restoreError = null;
        _restorePinController.clear();
      } else {
        _restoreSuccessMessage = null;
        _restoreError = switch (result.failure) {
          BackupRestoreFailure.wrongPin => _RestoreUiError.wrongPin,
          BackupRestoreFailure.corruptFile => _RestoreUiError.corruptFile,
          BackupRestoreFailure.unknown => _RestoreUiError.unknown,
          null => null,
        };
      }
    });
  }

  String? _restoreErrorMessage(AppLocalizations loc) {
    switch (_restoreError) {
      case _RestoreUiError.noFile:
        return loc.restoreSelectFileFirst;
      case _RestoreUiError.wrongPin:
        return loc.restoreWrongPin;
      case _RestoreUiError.corruptFile:
        return loc.restoreCorruptFile;
      case _RestoreUiError.unknown:
        return loc.restoreUnknownError;
      case null:
        return null;
    }
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
      appBar: AppBar(
        leading: Icon(Icons.backup_rounded, color: colorScheme.onSurface),
        title: Text(loc.backupRestoreTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: colorScheme.outlineVariant),
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
                    onPressed: _openCreateBackupWizard,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(loc.createBackupCta),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.restoreSectionTitle,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  loc.restoreSectionDescription,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickRestoreFile,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(loc.restorePickFileCta),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _selectedRestoreFile == null
                      ? loc.restoreNoFileChosen
                      : loc.restoreSelectedFile(
                          _selectedRestoreFile!.uri.pathSegments.last,
                        ),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _restorePinController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: loc.backupPassphraseHint,
                  ),
                  onChanged: (_) {
                    if (_restoreError != null ||
                        _restoreSuccessMessage != null) {
                      setState(() {
                        _restoreError = null;
                        _restoreSuccessMessage = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isRestoring ? null : _restoreBackup,
                    icon: const Icon(Icons.download_for_offline_rounded),
                    label: _isRestoring
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(loc.restoreFromBackupCta),
                  ),
                ),
                if (_restoreErrorMessage(loc) != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _restoreErrorMessage(loc)!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ],
                if (_restoreSuccessMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _restoreSuccessMessage!,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            loc.backupGuideTitle,
            style: textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
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

class _CreateBackupWizardDialog extends StatefulWidget {
  const _CreateBackupWizardDialog({
    required this.backupFacade,
    required this.provider,
  });

  final BackupFacade backupFacade;
  final PasswordProvider provider;

  @override
  State<_CreateBackupWizardDialog> createState() =>
      _CreateBackupWizardDialogState();
}

class _CreateBackupWizardDialogState extends State<_CreateBackupWizardDialog> {
  final TextEditingController _passphraseController = TextEditingController();
  final TextEditingController _confirmPassphraseController =
      TextEditingController();

  int _step = 1;
  bool _isBusy = false;
  String? _errorMessage;
  BackupPreparation? _preparation;
  BackupExportResult? _result;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmPassphraseController.dispose();
    super.dispose();
  }

  Future<void> _createBackupDraft() async {
    final loc = AppLocalizations.of(context)!;
    final passphrase = _passphraseController.text;
    final confirm = _confirmPassphraseController.text;

    if (passphrase.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = loc.backupPassphraseEmpty);
      return;
    }
    if (passphrase != confirm) {
      setState(() => _errorMessage = loc.backupPassphraseMismatch);
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final preparation = await widget.backupFacade.prepareBackup(
        provider: widget.provider,
        passphrase: passphrase,
      );

      if (!mounted) return;
      setState(() {
        _preparation = preparation;
        _step = 2;
      });
    } on BackupExportException {
      if (!mounted) return;
      setState(() => _errorMessage = loc.noPasswordsToExport);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = loc.exportFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _saveToDownloads() async {
    final preparation = _preparation;
    if (preparation == null) {
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final loc = AppLocalizations.of(context)!;

    try {
      final result =
          await widget.backupFacade.saveBackupToDownloads(preparation);

      if (!mounted) return;

      if (result == null) {
        setState(() => _isBusy = false);
        return;
      }

      setState(() {
        _result = result;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = loc.exportFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _shareBackup() async {
    final preparation = _preparation;
    if (preparation == null) {
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    final loc = AppLocalizations.of(context)!;

    try {
      final result = await widget.backupFacade.shareBackup(
        preparation: preparation,
        shareText: loc.backupShareText,
      );

      if (!mounted) return;
      setState(() {
        _result = result;
        _step = 3;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = loc.exportFailed(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  String _stepTitle(AppLocalizations loc) {
    return switch (_step) {
      1 => loc.backupWizardStep1Title,
      2 => loc.backupWizardStep2Title,
      3 => loc.backupWizardStep3Title,
      _ => loc.backupWizardStep1Title,
    };
  }

  Widget _buildStepContent(AppLocalizations loc) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_step == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.backupWizardStep1Body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _passphraseController,
            obscureText: true,
            decoration: InputDecoration(hintText: loc.backupPassphraseHint),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _confirmPassphraseController,
            obscureText: true,
            decoration:
                InputDecoration(hintText: loc.backupPassphraseConfirmHint),
          ),
        ],
      );
    }

    if (_step == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            loc.backupWizardStep2Body,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_preparation != null)
            Text(
              loc.backupWizardFilename(_preparation!.fileName),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isBusy ? null : _saveToDownloads,
              icon: const Icon(Icons.download_rounded),
              label: Text(loc.backupWizardDestinationDownloads),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _shareBackup,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text(loc.backupWizardDestinationShare),
            ),
          ),
        ],
      );
    }

    final fileName = _result?.fileName ?? _preparation?.fileName ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                loc.backupWizardSuccessBody,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          loc.backupWizardFilename(fileName),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildActions(AppLocalizations loc) {
    if (_step == 1) {
      return [
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
        FilledButton(
          onPressed: _isBusy ? null : _createBackupDraft,
          child: _isBusy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(loc.backupWizardCreateAction),
        ),
      ];
    }

    if (_step == 2) {
      return [
        TextButton(
          onPressed: _isBusy ? null : () => setState(() => _step = 1),
          child: Text(loc.backupWizardBackAction),
        ),
        TextButton(
          onPressed: _isBusy ? null : () => Navigator.pop(context),
          child: Text(loc.cancel),
        ),
      ];
    }

    return [
      FilledButton(
        onPressed: () => Navigator.pop(context, _result),
        child: Text(loc.backupWizardDoneAction),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: Text(loc.backupWizardTitle),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.backupWizardProgress(_step, 3),
                style: textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _stepTitle(loc),
                style: textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildStepContent(loc),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: _buildActions(loc),
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
