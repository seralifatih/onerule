import 'package:flutter/material.dart';

import '../services/credential_provider.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class AutofillSetupScreen extends StatefulWidget {
  const AutofillSetupScreen({super.key, this.credentialProvider});

  final CredentialProvider? credentialProvider;

  @override
  State<AutofillSetupScreen> createState() => _AutofillSetupScreenState();
}

class _AutofillSetupScreenState extends State<AutofillSetupScreen>
    with WidgetsBindingObserver {
  late final CredentialProvider _credentialProvider;
  bool _isLoading = true;
  bool _isSupported = false;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _credentialProvider =
        widget.credentialProvider ?? PlatformCredentialProvider();
    _refreshStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshStatus();
    }
  }

  Future<void> _refreshStatus() async {
    setState(() => _isLoading = true);
    final isSupported = await _credentialProvider.isSupported();
    final isEnabled =
        isSupported ? await _credentialProvider.isEnabled() : false;
    if (!mounted) return;
    setState(() {
      _isSupported = isSupported;
      _isEnabled = isEnabled;
      _isLoading = false;
    });
  }

  Future<void> _openSystemSettings() async {
    await _credentialProvider.openSetup();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Select OneRule as your Autofill provider in system settings.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>() ??
        AppTheme.fallbackSemanticColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Autofill Setup')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: _isEnabled
                        ? semanticColors.success.withValues(alpha: 0.12)
                        : semanticColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isEnabled
                            ? Icons.check_circle_outline
                            : Icons.info_outline,
                        color: _isEnabled
                            ? semanticColors.success
                            : semanticColors.warning,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _isEnabled
                              ? 'Autofill is enabled for OneRule.'
                              : 'Autofill is not enabled yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (!_isSupported)
                  Text(
                    'This device does not support Android Autofill API 26+ or Autofill is disabled by build config.',
                    style: textTheme.bodyMedium,
                  )
                else ...[
                  Text(
                    'Use OneRule to fill credentials in apps and browsers.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _step(
                    context,
                    number: '1',
                    title: 'Open Autofill settings',
                    body:
                        'Tap the button below to open Android Autofill settings.',
                  ),
                  _step(
                    context,
                    number: '2',
                    title: 'Select OneRule',
                    body: 'Choose OneRule as the default Autofill service.',
                  ),
                  _step(
                    context,
                    number: '3',
                    title: 'Return to verify',
                    body:
                        'Come back here and confirm status changed to enabled.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _openSystemSettings,
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Open Autofill settings'),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _refreshStatus,
                      child: const Text('Refresh status'),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _step(
    BuildContext context, {
    required String number,
    required String title,
    required String body,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              number,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(body, style: textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
