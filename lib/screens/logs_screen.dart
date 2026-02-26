import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../providers/security_settings_provider.dart';
import '../services/local_log_service.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _loading = true;
  String _logs = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await LocalLogService.instance.readLogText();
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _copyLogs() async {
    final loc = AppLocalizations.of(context)!;
    if (_logs.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.viewLogsEmpty)),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: _logs));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.logsCopied)),
    );
  }

  Future<void> _exportLogs() async {
    final shareEnabled =
        context.read<SecuritySettingsProvider>().shareCrashReportsEnabled;
    await LocalLogService.instance.exportLog(
      context,
      shareEnabled: shareEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading:
            Icon(Icons.article_outlined, color: theme.colorScheme.onSurface),
        title: Text(loc.viewLogsTitle),
        actions: [
          IconButton(
            onPressed: _loadLogs,
            tooltip: loc.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _logs.trim().isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest
                                    .withValues(alpha: 0.5),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.large),
                                border: Border.all(
                                  color: theme.colorScheme.outlineVariant,
                                ),
                              ),
                              child: Text(
                                loc.viewLogsEmpty,
                                style: textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.large),
                              border: Border.all(
                                color: theme.colorScheme.outlineVariant,
                              ),
                            ),
                            child: SingleChildScrollView(
                              child: SelectableText(
                                _logs,
                                style: textTheme.bodySmall?.copyWith(
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyLogs,
                          icon: const Icon(Icons.copy_all_rounded),
                          label: Text(loc.copyLogsAction),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _exportLogs,
                          icon: const Icon(Icons.ios_share_rounded),
                          label: Text(loc.exportDebugLogTitle),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
