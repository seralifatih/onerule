import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/add_password_sheet.dart';
import 'settings_screen.dart';
import '../services/app_facade.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum _HomeContentState { loading, emptyVault, noResults, list }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.lockFacade});

  final LockFacade? lockFacade;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  late final LockFacade _lockFacade;
  final AnalyticsService _analytics = AnalyticsService.instance;
  final BackupFacade _backupFacade = BackupFacade();

  // Backup banner state
  DateTime? _lastBackupAt;
  bool _backupBannerDismissed = false;

  // Panic Mode onboarding banner state
  bool _showPanicModeBanner = false;
  bool _hasPanicPin = false;

  @override
  void initState() {
    super.initState();
    _lockFacade = widget.lockFacade ?? LockFacade();
    _loadBackupStatus();
    _loadPanicBannerStatus();
  }

  // ── Backup banner ─────────────────────────────────────────────────────────

  Future<void> _loadBackupStatus() async {
    final lastBackupAt = await _backupFacade.getLastBackupAt();
    if (!mounted) return;
    setState(() => _lastBackupAt = lastBackupAt);
  }

  bool get _shouldShowBackupBanner {
    if (_backupBannerDismissed) return false;
    if (_lastBackupAt == null) return true;
    return DateTime.now().difference(_lastBackupAt!).inDays >= 30;
  }

  // ── Panic Mode onboarding banner ──────────────────────────────────────────

  Future<void> _loadPanicBannerStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool('panicBannerDismissed') ?? false;
    if (dismissed) return;

    final authFacade = AuthFacade();
    final hasPanic = await authFacade.hasPanicPin();
    if (!mounted) return;

    setState(() {
      _hasPanicPin = hasPanic;
      _showPanicModeBanner = !hasPanic;
    });
  }

  Future<void> _dismissPanicBannerPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('panicBannerDismissed', true);
    if (!mounted) return;
    setState(() => _showPanicModeBanner = false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _lockFacade.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.lock_rounded, color: colorScheme.onSurface),
        title: Text(loc.myVaultTitle),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actionsIconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
              _loadBackupStatus();
              _loadPanicBannerStatus();
            },
          ),
        ],
      ),
      body: Consumer<PasswordProvider>(
        builder: (context, provider, _) {
          final passwords = _buildVisiblePasswords(provider.passwords);
          final hasActiveRefinement =
              _searchQuery.isNotEmpty || provider.hasActiveCategoryFilter;
          final contentState = _resolveContentState(
            provider: provider,
            hasActiveRefinement: hasActiveRefinement,
            visibleItemsCount: passwords.length,
          );

          return Column(
            children: [
              // ── Panic mode active warning (decoy vault is open) ──────────
              if (provider.isPanicMode) _buildPanicActiveBanner(context),

              // ── Backup reminder ──────────────────────────────────────────
              if (!provider.isPanicMode && _shouldShowBackupBanner)
                _buildBackupBanner(context),

              // ── Panic Mode onboarding (only when vault has items) ────────
              if (!provider.isPanicMode &&
                  _showPanicModeBanner &&
                  provider.totalPasswordsCount > 0)
                _buildPanicOnboardingBanner(context),

              // ── Search + filter header ───────────────────────────────────
              _buildHeaderSection(
                context: context,
                provider: provider,
                hasActiveRefinement: hasActiveRefinement,
                visibleItemsCount: passwords.length,
              ),

              // ── Main content ─────────────────────────────────────────────
              Expanded(
                child: _buildContentByState(
                  context: context,
                  state: contentState,
                  provider: provider,
                  passwords: passwords,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: FloatingActionButton.extended(
          onPressed: () {
            _analytics.primaryCtaTap(
              ctaId: 'home_new_password',
              screen: 'home',
            );
            _openAddEditSheet(context, null);
          },
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: AppElevation.medium,
          label: Text(
            loc.newPassword,
            style: Theme.of(context).textTheme.labelLarge,
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
        ),
      ),
    );
  }

  // ── Panic mode ACTIVE banner ──────────────────────────────────────────────

  Widget _buildPanicActiveBanner(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>() ??
        AppTheme.fallbackSemanticColors;

    return Container(
      width: double.infinity,
      color: semanticColors.warning.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.shield_rounded, size: 16, color: semanticColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Privacy mode active — decoy vault shown',
              style: textTheme.labelSmall?.copyWith(
                color: semanticColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Backup reminder banner ────────────────────────────────────────────────

  Widget _buildBackupBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNeverBacked = _lastBackupAt == null;

    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer.withValues(alpha: 0.5),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.backup_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              isNeverBacked
                  ? 'No backup yet — export your vault in Settings'
                  : 'Last backup was over 30 days ago',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadBackupStatus();
            },
            child: Text(
              'Back up',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 16, color: colorScheme.onPrimaryContainer),
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
            onPressed: () => setState(() => _backupBannerDismissed = true),
          ),
        ],
      ),
    );
  }

  // ── Panic Mode onboarding banner ──────────────────────────────────────────

  Widget _buildPanicOnboardingBanner(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>() ??
        AppTheme.fallbackSemanticColors;

    return Container(
      width: double.infinity,
      color: semanticColors.warning.withValues(alpha: 0.1),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: semanticColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set up Panic PIN',
                  style: textTheme.labelSmall?.copyWith(
                    color: semanticColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Opens a decoy vault if someone forces you to unlock.',
                  style: textTheme.bodySmall?.copyWith(
                    color: semanticColors.warning.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              _loadPanicBannerStatus();
            },
            child: Text(
              'Set up',
              style: textTheme.labelSmall?.copyWith(
                color: semanticColors.warning,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: semanticColors.warning,
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: semanticColors.warning.withValues(alpha: 0.6),
            ),
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
            tooltip: 'Dismiss',
            onPressed: _dismissPanicBannerPermanently,
          ),
        ],
      ),
    );
  }

  // ── Header: search + filters ──────────────────────────────────────────────

  Widget _buildHeaderSection({
    required BuildContext context,
    required PasswordProvider provider,
    required bool hasActiveRefinement,
    required int visibleItemsCount,
  }) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final total = provider.totalPasswordsCount;
    final hasSearchQuery = _searchController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            cursorColor: colorScheme.primary,
            decoration: InputDecoration(
              hintText: loc.searchPasswordsHint,
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              suffixIcon: hasSearchQuery
                  ? Semantics(
                      button: true,
                      label: loc.clearSearchFiltersLabel,
                      child: IconButton(
                        tooltip: loc.clearSearchFiltersLabel,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearSearchQuery,
                      ),
                    )
                  : hasActiveRefinement
                      ? Semantics(
                          button: true,
                          label: loc.clearSearchFiltersLabel,
                          child: IconButton(
                            tooltip: loc.clearSearchFiltersLabel,
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => _clearSearchAndFilters(provider),
                          ),
                        )
                      : total > 0
                      ? Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.md),
                          child: Text(
                            '$visibleItemsCount / $total',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        )
                      : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFilterRow(context: context, provider: provider, loc: loc),
        ],
      ),
    );
  }

  Widget _buildFilterRow({
    required BuildContext context,
    required PasswordProvider provider,
    required AppLocalizations loc,
  }) {
    const categories = PasswordCategories.filterCategories;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: _buildFilterChip(
                context: context,
                loc: loc,
                category: category,
                selected: provider.selectedCategory == category,
                onTap: () => _applyCategoryFilter(provider, category),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required BuildContext context,
    required AppLocalizations loc,
    required String category,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return FilterChip(
      label: Text(PasswordCategories.labelFor(loc, category)),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: colorScheme.surface,
      selectedColor: colorScheme.primary.withValues(alpha: 0.15),
      checkmarkColor: colorScheme.primary,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xlarge - 4),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
        ),
      ),
    );
  }

  // ── Content router ────────────────────────────────────────────────────────

  _HomeContentState _resolveContentState({
    required PasswordProvider provider,
    required bool hasActiveRefinement,
    required int visibleItemsCount,
  }) {
    if (provider.isLoading) return _HomeContentState.loading;
    if (hasActiveRefinement && visibleItemsCount == 0) {
      return _HomeContentState.noResults;
    }
    if (provider.totalPasswordsCount == 0) return _HomeContentState.emptyVault;
    return _HomeContentState.list;
  }

  Widget _buildContentByState({
    required BuildContext context,
    required _HomeContentState state,
    required PasswordProvider provider,
    required List<PasswordModel> passwords,
  }) {
    switch (state) {
      case _HomeContentState.loading:
        return const LoadingState();
      case _HomeContentState.emptyVault:
        return EmptyVaultState(
          onAddItem: () {
            _analytics.primaryCtaTap(
              ctaId: 'home_empty_add_item',
              screen: 'home',
            );
            _openAddEditSheet(context, null);
          },
        );
      case _HomeContentState.noResults:
        return NoResultsState(onClear: () => _clearSearchAndFilters(provider));
      case _HomeContentState.list:
        return ListView.builder(
          itemCount: passwords.length,
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.giant + AppSpacing.giant + AppSpacing.lg,
          ),
          itemBuilder: (context, index) {
            return _buildPasswordTile(context, passwords[index], provider);
          },
        );
    }
  }

  void _applyCategoryFilter(PasswordProvider provider, String category) {
    provider.filterByCategory(category);
  }

  void _clearSearchAndFilters(PasswordProvider provider) {
    _clearSearchQuery();
    provider.filterByCategory(PasswordCategories.all);
  }

  void _clearSearchQuery() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_searchQuery.isEmpty) return;
    setState(() => _searchQuery = '');
    _analytics.searchQueryChanged(queryLength: 0);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      final normalized = query.trim();
      if (_searchQuery == normalized) return;
      setState(() => _searchQuery = normalized);
      _analytics.searchQueryChanged(queryLength: query.length);
    });
  }

  List<PasswordModel> _buildVisiblePasswords(List<PasswordModel> source) {
    final normalizedQuery = _searchQuery.toLowerCase();
    if (normalizedQuery.isEmpty) return source;

    return source.where((password) {
      return password.title.toLowerCase().contains(normalizedQuery) ||
          password.username.toLowerCase().contains(normalizedQuery) ||
          (password.url ?? '').toLowerCase().contains(normalizedQuery) ||
          password.category.toLowerCase().contains(normalizedQuery);
    }).toList(growable: false);
  }

  void _openAddEditSheet(BuildContext context, PasswordModel? password) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xlarge),
          ),
        ),
        child: AddPasswordSheet(passwordToEdit: password),
      ),
    );
  }

  // ── Password card ─────────────────────────────────────────────────────────

  Widget _buildPasswordTile(
    BuildContext context,
    PasswordModel password,
    PasswordProvider provider,
  ) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final semanticColors =
        theme.extension<AppSemanticColors>() ?? AppTheme.fallbackSemanticColors;
    final media = MediaQuery.of(context);
    final clampedScale =
        media.textScaler.scale(1.0).clamp(1.0, 1.15).toDouble();

    return Dismissible(
      key: Key(password.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: semanticColors.destructive.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: Icon(
          Icons.delete_outline_rounded,
          color: colorScheme.onError,
          size: AppSpacing.xl + AppSpacing.xs,
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(loc.deletePasswordTitle),
                content: Text(loc.deletePasswordMessage),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(loc.cancel),
                  ),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          semanticColors.destructive.withValues(alpha: 0.85),
                    ),
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(loc.delete),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        provider.deletePassword(password.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.passwordDeleted)),
        );
      },
      child: MediaQuery(
        data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.large),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.07),
                blurRadius: AppSpacing.md,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.xs,
              top: AppSpacing.sm,
              bottom: AppSpacing.sm,
            ),
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.md - 2),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                PasswordCategories.iconFor(password.category),
                color: colorScheme.primary,
                size: 22,
              ),
            ),
            title: Text(
              password.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  password.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm - 2,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.7),
                        borderRadius:
                            BorderRadius.circular(AppRadius.small - 2),
                      ),
                      child: Text(
                        PasswordCategories.labelFor(loc, password.category)
                            .toUpperCase(),
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontSize: 10,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (password.lastModified != null) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          _localizedShortDate(context, password.lastModified!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            trailing: _buildActionMenu(
              context: context,
              password: password,
              provider: provider,
              loc: loc,
              semanticColors: semanticColors,
            ),
            onTap: () => _openAddEditSheet(context, password),
          ),
        ),
      ),
    );
  }

  // ── Three-dot action menu ─────────────────────────────────────────────────

  Widget _buildActionMenu({
    required BuildContext context,
    required PasswordModel password,
    required PasswordProvider provider,
    required AppLocalizations loc,
    required AppSemanticColors semanticColors,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<_CardAction>(
      icon: Icon(
        Icons.more_vert_rounded,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      onSelected: (action) => _handleCardAction(
        context: context,
        action: action,
        password: password,
        provider: provider,
        loc: loc,
        semanticColors: semanticColors,
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _CardAction.copyUsername,
          child: _menuItem(
            icon: Icons.alternate_email_rounded,
            label: 'Copy username',
            color: colorScheme.onSurface,
          ),
        ),
        PopupMenuItem(
          value: _CardAction.copyPassword,
          child: _menuItem(
            icon: Icons.copy_rounded,
            label: 'Copy password',
            color: colorScheme.onSurface,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _CardAction.edit,
          child: _menuItem(
            icon: Icons.edit_outlined,
            label: loc.update,
            color: colorScheme.onSurface,
          ),
        ),
        PopupMenuItem(
          value: _CardAction.delete,
          child: _menuItem(
            icon: Icons.delete_outline_rounded,
            label: loc.delete,
            color: semanticColors.destructive,
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.md),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }

  Future<void> _handleCardAction({
    required BuildContext context,
    required _CardAction action,
    required PasswordModel password,
    required PasswordProvider provider,
    required AppLocalizations loc,
    required AppSemanticColors semanticColors,
  }) async {
    switch (action) {
      case _CardAction.copyUsername:
        _lockFacade.copyUsernameToClipboard(
          context: context,
          username: password.username,
          title: password.title,
        );
      case _CardAction.copyPassword:
        _lockFacade.copyPasswordToClipboard(
          context: context,
          password: password.password,
          title: password.title,
        );
      case _CardAction.edit:
        _openAddEditSheet(context, password);
      case _CardAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(loc.deletePasswordTitle),
            content: Text(loc.deletePasswordMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(loc.cancel),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      semanticColors.destructive.withValues(alpha: 0.85),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(loc.delete),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          provider.deletePassword(password.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.passwordDeleted)),
          );
        }
    }
  }

  String _localizedShortDate(BuildContext context, DateTime value) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMd(locale).format(value.toLocal());
  }
}

// ── Card action enum ──────────────────────────────────────────────────────────

enum _CardAction { copyUsername, copyPassword, edit, delete }

// ── Supporting state widgets ──────────────────────────────────────────────────

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Loading vault...',
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyVaultState extends StatefulWidget {
  const EmptyVaultState({super.key, required this.onAddItem});

  final VoidCallback onAddItem;

  @override
  State<EmptyVaultState> createState() => _EmptyVaultStateState();
}

class _EmptyVaultStateState extends State<EmptyVaultState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _outerScale;
  late final Animation<double> _outerOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    _pulseController.forward();

    _outerScale = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _outerOpacity = Tween<double>(begin: 0.04, end: 0.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, _) {
                        return SizedBox(
                          width: 140,
                          height: 140,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.scale(
                                scale: _outerScale.value,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: colorScheme.primary
                                        .withValues(alpha: _outerOpacity.value),
                                  ),
                                ),
                              ),
                              Container(
                                width: 108,
                                height: 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.08),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: colorScheme.primaryContainer
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              Icon(Icons.lock_rounded,
                                  size: 36, color: colorScheme.primary),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      loc.noPasswordsFound,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Your vault is encrypted and ready.\nAdd your first item to get started.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton.icon(
                      onPressed: widget.onAddItem,
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('Add First Item'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xl,
                          vertical: AppSpacing.md + AppSpacing.xs / 2,
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl + AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_left_rounded,
                          size: 13,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.4),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Swipe left on any item to delete',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class NoResultsState extends StatelessWidget {
  const NoResultsState({super.key, required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: AppSpacing.giant + AppSpacing.xl,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No results',
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try a different search or reset your filters.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onClear,
              child: const Text('Clear'),
            ),
          ],
        ),
      ),
    );
  }
}
