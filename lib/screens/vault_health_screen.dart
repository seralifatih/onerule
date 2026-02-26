import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../services/vault_health_service.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

class VaultHealthScreen extends StatefulWidget {
  const VaultHealthScreen({super.key});

  @override
  State<VaultHealthScreen> createState() => _VaultHealthScreenState();
}

class _VaultHealthScreenState extends State<VaultHealthScreen> {
  final VaultHealthService _service = VaultHealthService();
  Future<VaultHealthReport>? _reportFuture;
  String _lastSignature = '';

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<PasswordProvider>().passwords;
    _ensureFuture(entries);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Icon(
          Icons.health_and_safety_outlined,
          color: colorScheme.onSurface,
        ),
        title: const Text('Vault Health'),
      ),
      body: FutureBuilder<VaultHealthReport>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildMessageState(
              context,
              icon: Icons.error_outline_rounded,
              title: 'Unable to analyze vault',
              body: 'Try again after reopening this screen.',
            );
          }

          if (!snapshot.hasData) {
            return _buildLoadingState(context);
          }

          final report = snapshot.data!;
          final buckets = report.buckets;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            children: [
              _buildScoreCard(context, report),
              const SizedBox(height: AppSpacing.lg),
              _buildStatsRow(context, report),
              const SizedBox(height: AppSpacing.lg),
              ...buckets.map(
                (bucket) => _buildIssueTile(
                  context,
                  bucket: bucket,
                ),
              ),
              if (report.totalEntries == 0)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xl),
                  child: _buildMessageState(
                    context,
                    icon: Icons.vpn_key_off_outlined,
                    title: 'No entries yet',
                    body: 'Add entries to see health insights.',
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _ensureFuture(List<PasswordModel> entries) {
    final signature = _buildSignature(entries);
    if (_reportFuture == null || _lastSignature != signature) {
      _lastSignature = signature;
      _reportFuture = _service.analyze(entries);
    }
  }

  String _buildSignature(List<PasswordModel> entries) {
    return entries.map((entry) {
      return '${entry.id}:${entry.password.hashCode}:'
          '${entry.lastModified?.millisecondsSinceEpoch ?? 0}:'
          '${entry.createdDate.millisecondsSinceEpoch}';
    }).join('|');
  }

  Widget _buildScoreCard(BuildContext context, VaultHealthReport report) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>() ??
        AppTheme.fallbackSemanticColors;
    final score = report.score;
    final ringColor = score >= 80
        ? semanticColors.success
        : score >= 60
            ? semanticColors.warning
            : semanticColors.destructive;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.06),
            blurRadius: AppElevation.low * 2,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 92,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 8,
                  backgroundColor: colorScheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(ringColor),
                ),
                Text(
                  '$score',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Security Score',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Score from 0 to 100 based on weak, duplicate, and stale credentials.',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, VaultHealthReport report) {
    return Row(
      children: [
        Expanded(
          child: _StatChip(label: 'Weak', value: report.weakCount),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(label: 'Duplicates', value: report.duplicateCount),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatChip(label: 'Stale', value: report.staleCount),
        ),
      ],
    );
  }

  Widget _buildIssueTile(
    BuildContext context, {
    required VaultHealthIssueBucket bucket,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final disabled = bucket.count == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.large),
        border: Border.all(
          color: disabled ? colorScheme.outlineVariant : colorScheme.primary,
          width: disabled ? 1 : 1.2,
        ),
      ),
      child: ListTile(
        title: Text(bucket.title),
        subtitle: Text(bucket.description),
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          foregroundColor: colorScheme.onPrimaryContainer,
          child: Text('${bucket.count}'),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        enabled: !disabled,
        onTap: disabled
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VaultHealthIssueListScreen(bucket: bucket),
                  ),
                );
              },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return _buildMessageState(
      context,
      icon: Icons.health_and_safety_outlined,
      title: 'Analyzing vault health',
      body: 'Checking weak, duplicate, and stale credentials...',
      trailing: const Padding(
        padding: EdgeInsets.only(top: AppSpacing.md),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMessageState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadius.large),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 32, color: colorScheme.primary),
              const SizedBox(height: AppSpacing.sm),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                body,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class VaultHealthIssueListScreen extends StatelessWidget {
  const VaultHealthIssueListScreen({super.key, required this.bucket});

  final VaultHealthIssueBucket bucket;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(bucket.title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: bucket.entries.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final entry = bucket.entries[index];
          return Container(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.large),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: ListTile(
              leading: Icon(
                Icons.vpn_key_rounded,
                color: colorScheme.primary,
              ),
              title: Text(
                entry.title,
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                _maskUsername(entry.username),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _maskUsername(String username) {
    final normalized = username.trim();
    if (normalized.isEmpty) return '****';

    final atIndex = normalized.indexOf('@');
    if (atIndex > 0 && atIndex < normalized.length - 1) {
      final local = normalized.substring(0, atIndex);
      final domain = normalized.substring(atIndex + 1);
      final localMaskLength = local.length > 1 ? local.length - 1 : 1;
      final localMasked = '${local[0]}${'*' * localMaskLength}';
      return '$localMasked@$domain';
    }

    if (normalized.length <= 2) {
      return '*' * normalized.length;
    }
    return '${normalized[0]}${'*' * (normalized.length - 2)}${normalized[normalized.length - 1]}';
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
