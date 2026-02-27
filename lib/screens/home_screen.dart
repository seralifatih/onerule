import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../providers/security_settings_provider.dart';
import '../services/analytics_service.dart';
import '../services/credential_provider.dart';
import '../services/recently_used_service.dart';
import '../widgets/add_password_sheet.dart';
import 'autofill_setup_screen.dart';
import 'settings_screen.dart';
import '../services/app_facade.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

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
  final CredentialProvider _credentialProvider = PlatformCredentialProvider();

  // Backup banner state
  DateTime? _lastBackupAt;
  bool _backupBannerDismissed = false;

  // Panic Mode onboarding banner state
  bool _showPanicModeBanner = false;
  bool _showAutofillSetupCard = false;
  final Map<String, int> _copyCountdownById = <String, int>{};
  final Map<String, Timer> _copyCountdownTimers = <String, Timer>{};
  final RecentlyUsedService _recentlyUsedService = RecentlyUsedService();
  bool _hideRecentlyUsed = false;
  List<String> _recentlyUsedIds = const <String>[];
  late final List<PasswordModel> _decoyPasswords = _buildDecoyPasswords();

  @override
  void initState() {
    super.initState();
    _lockFacade = widget.lockFacade ?? LockFacade();
    _loadBackupStatus();
    _loadPanicBannerStatus();
    _refreshAutofillStatus();
    _loadRecentlyUsedPreferences();
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

    setState(() => _showPanicModeBanner = !hasPanic);
  }

  Future<void> _dismissPanicBannerPermanently() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('panicBannerDismissed', true);
    if (!mounted) return;
    setState(() => _showPanicModeBanner = false);
  }

  Future<void> _loadRecentlyUsedPreferences() async {
    final provider = context.read<PasswordProvider>();
    final hidden = await _recentlyUsedService.isHidden();
    final ids = await _recentlyUsedService.getTopIds(
      allowedIds: provider.passwords.map((item) => item.id).toSet(),
      limit: 5,
    );
    if (!mounted) return;
    setState(() {
      _hideRecentlyUsed = hidden;
      _recentlyUsedIds = ids;
    });
  }

  Future<void> _markEntryAccessed(String passwordId) async {
    final provider = context.read<PasswordProvider>();
    await _recentlyUsedService.markAccessed(passwordId);
    final ids = await _recentlyUsedService.getTopIds(
      allowedIds: provider.passwords.map((item) => item.id).toSet(),
      limit: 5,
    );
    if (!mounted) return;
    setState(() => _recentlyUsedIds = ids);
  }

  Future<void> _setHideRecentlyUsed(bool hidden) async {
    await _recentlyUsedService.setHidden(hidden);
    if (!mounted) return;
    setState(() => _hideRecentlyUsed = hidden);
  }

  Future<void> _refreshAutofillStatus() async {
    final supported = await _credentialProvider.isSupported();
    if (!supported) {
      if (!mounted) return;
      setState(() => _showAutofillSetupCard = false);
      return;
    }
    final enabled = await _credentialProvider.isEnabled();
    if (!mounted) return;
    setState(() => _showAutofillSetupCard = !enabled);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final timer in _copyCountdownTimers.values) {
      timer.cancel();
    }
    _copyCountdownTimers.clear();
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
              _refreshAutofillStatus();
            },
          ),
        ],
      ),
      body: Consumer<PasswordProvider>(
        builder: (context, provider, _) {
          final sourcePasswords =
              provider.isPanicMode ? _decoyPasswords : provider.passwords;
          final passwords = _buildVisiblePasswords(sourcePasswords);
          final hasActiveRefinement =
              _searchQuery.isNotEmpty || provider.hasActiveCategoryFilter;
          final contentState = _resolveContentState(
            provider: provider,
            hasActiveRefinement: hasActiveRefinement,
            visibleItemsCount: passwords.length,
          );
          final recentById = <String, PasswordModel>{
            for (final item in passwords) item.id: item,
          };
          final recentItems = _recentlyUsedIds
              .map((id) => recentById[id])
              .whereType<PasswordModel>()
              .take(5)
              .toList(growable: false);
          final recentIds = recentItems.map((item) => item.id).toSet();
          final remainingItems = _hideRecentlyUsed
              ? passwords
              : passwords
                  .where((item) => !recentIds.contains(item.id))
                  .toList(growable: false);

          return Column(
            children: [
              // ── Panic mode active warning ────────────────────────────────
              if (provider.isPanicMode) _buildPanicActiveBanner(context),

              if (!provider.isPanicMode && _showAutofillSetupCard)
                _buildAutofillSetupBanner(context),

              // ── Backup reminder ──────────────────────────────────────────
              if (!provider.isPanicMode && _shouldShowBackupBanner)
                _buildBackupBanner(context),

              // ── Panic Mode onboarding ────────────────────────────────────
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
                  passwords: remainingItems,
                  recentPasswords: recentItems,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<PasswordProvider>(
        builder: (context, provider, _) {
          if (provider.isPanicMode) return const SizedBox.shrink();
          return SafeArea(
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
          );
        },
      ),
    );
  }

  // ── Panic mode ACTIVE banner ──────────────────────────────────────────────

  Widget _buildPanicActiveBanner(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.75),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.privacy_tip_rounded, size: 16, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${loc.privacyModeLabel}: ${loc.privacyModeHelperText}',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutofillSetupBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.78),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_outlined, size: 16, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Autofill not enabled for OneRule',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w600,
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
                MaterialPageRoute(
                  builder: (context) => const AutofillSetupScreen(),
                ),
              );
              _refreshAutofillStatus();
            },
            child: Text(
              'Set up',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w700,
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
      color: colorScheme.primaryContainer.withValues(alpha: 0.8),
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
                fontWeight: FontWeight.w700,
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
                color: colorScheme.onPrimaryContainer,
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
    // FIX: Use warning color for text/icons — readable on both light and dark
    // amber background without relying on onSurface which varies by theme.
    final contentColor = semanticColors.warning;

    return Container(
      width: double.infinity,
      color: semanticColors.warning.withValues(alpha: 0.14),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 16, color: contentColor),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Set up Panic PIN',
                  style: textTheme.labelSmall?.copyWith(
                    color: contentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Opens a decoy vault if someone forces you to unlock.',
                  style: textTheme.bodySmall?.copyWith(
                    color: contentColor.withValues(alpha: 0.8),
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
                color: contentColor,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: contentColor,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded,
                size: 16, color: contentColor.withValues(alpha: 0.7)),
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
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.md),
                              child: Text(
                                '$visibleItemsCount / $total',
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
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
      selectedColor: colorScheme.primary.withValues(alpha: 0.25),
      checkmarkColor: colorScheme.primary,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurface,
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
    required List<PasswordModel> recentPasswords,
  }) {
    switch (state) {
      case _HomeContentState.loading:
        return const LoadingState();
      case _HomeContentState.emptyVault:
        return EmptyVaultState(
          isPanicMode: provider.isPanicMode,
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
        return ListView(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.giant + AppSpacing.giant + AppSpacing.lg,
          ),
          children: [
            if (recentPasswords.isNotEmpty) ...[
              _buildSectionHeader(
                context: context,
                label: 'Recently Used',
                trailing: TextButton.icon(
                  onPressed: () => _setHideRecentlyUsed(!_hideRecentlyUsed),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _hideRecentlyUsed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 15,
                  ),
                  label: Text(
                    _hideRecentlyUsed ? 'Show' : 'Hide',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              if (!_hideRecentlyUsed)
                ...recentPasswords.map(
                  (item) => _buildPasswordTile(context, item, provider),
                ),
              // ── Divider between sections ─────────────────────────────────
              if (passwords.isNotEmpty && !_hideRecentlyUsed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                    height: 1,
                  ),
                ),
            ],
            if (passwords.isNotEmpty)
              _buildSectionHeader(
                context: context,
                label: 'All Entries',
              ),
            ...passwords
                .map((item) => _buildPasswordTile(context, item, provider)),
          ],
        );
    }
  }

  /// Consistent section label used for "Recently Used" and "All Entries".
  Widget _buildSectionHeader({
    required BuildContext context,
    required String label,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                // FIX: use labelSmall + onSurfaceVariant for section labels
                // instead of labelLarge + onSurface — less dominant,
                // clearer hierarchy vs card titles.
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
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

  void _openPasswordDetails(BuildContext context, PasswordModel password) {
    _markEntryAccessed(password.id);
    _openAddEditSheet(context, password);
  }

  // ── Password card ─────────────────────────────────────────────────────────

  Widget _buildPasswordTile(
    BuildContext context,
    PasswordModel password,
    PasswordProvider provider,
  ) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final semanticColors =
        theme.extension<AppSemanticColors>() ?? AppTheme.fallbackSemanticColors;
    final media = MediaQuery.of(context);
    final clampedScale =
        media.textScaler.scale(1.0).clamp(1.0, 1.15).toDouble();

    final isReadOnlyDecoy = provider.isPanicMode;
    final countdownSeconds = _copyCountdownById[password.id];
    return MediaQuery(
      data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
      child: _VaultPasswordCard(
        key: ValueKey<String>('vault-card-${password.id}'),
        password: password,
        maskedUsername: _maskUsername(password.username),
        countdownSeconds: countdownSeconds,
        semanticColors: semanticColors,
        onOpen: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _openPasswordDetails(context, password),
        onCopyUsername: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _copyUsernameFromCard(password),
        onCopyPassword: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _copyPasswordFromCard(password),
        onQuickCopyPassword: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _copyPasswordFromCard(password),
        onEdit: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _openPasswordDetails(context, password),
        onDeleteTap: () {
          if (isReadOnlyDecoy) {
            _showPrivacyModeReadOnlyMessage(context);
            return;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
              const SnackBar(content: Text('Hold Delete to confirm.')));
        },
        onDeleteHold: isReadOnlyDecoy
            ? () => _showPrivacyModeReadOnlyMessage(context)
            : () => _deletePasswordWithHold(
                  context: context,
                  provider: provider,
                  password: password,
                  loc: loc,
                ),
      ),
    );
  }

  void _showPrivacyModeReadOnlyMessage(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.privacyModeHelperText)),
    );
  }

  List<PasswordModel> _buildDecoyPasswords() {
    final now = DateTime.now();
    return <PasswordModel>[
      PasswordModel(
        id: 'decoy-1',
        title: 'MailHub',
        username: 'alex.m@protonmail.com',
        password: 'tT6!fQ2#vR9',
        category: PasswordCategories.work,
        createdDate: now.subtract(const Duration(days: 12)),
      ),
      PasswordModel(
        id: 'decoy-2',
        title: 'StreamBox',
        username: 'alex_media',
        password: 'W9!pL3#sK2@x',
        category: PasswordCategories.social,
        createdDate: now.subtract(const Duration(days: 19)),
      ),
      PasswordModel(
        id: 'decoy-3',
        title: 'NorthBank',
        username: 'alex.wallet',
        password: 'B8@qN4!yZ1%u',
        category: PasswordCategories.finance,
        createdDate: now.subtract(const Duration(days: 33)),
      ),
      PasswordModel(
        id: 'decoy-4',
        title: 'QuickCart',
        username: 'alex.buy',
        password: 'M2#dV7!kR5^p',
        category: PasswordCategories.shopping,
        createdDate: now.subtract(const Duration(days: 45)),
      ),
      PasswordModel(
        id: 'decoy-5',
        title: 'ForumSpace',
        username: 'amember84',
        password: 'R4!xH8@jT6\$w',
        category: PasswordCategories.other,
        createdDate: now.subtract(const Duration(days: 61)),
      ),
    ];
  }

  Future<void> _deletePasswordWithHold({
    required BuildContext context,
    required PasswordProvider provider,
    required PasswordModel password,
    required AppLocalizations loc,
  }) async {
    await provider.deletePassword(password.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.passwordDeleted)),
    );
  }

  Future<void> _copyUsernameFromCard(PasswordModel password) async {
    _lockFacade.copyUsernameToClipboard(
      context: context,
      username: password.username,
      title: password.title,
    );
    await _markEntryAccessed(password.id);
    _startCopyFeedback(password.id);
  }

  Future<void> _copyPasswordFromCard(PasswordModel password) async {
    _lockFacade.copyPasswordToClipboard(
      context: context,
      password: password.password,
      title: password.title,
    );
    await _markEntryAccessed(password.id);
    _startCopyFeedback(password.id);
  }

  void _startCopyFeedback(String passwordId) {
    final countdownSeconds = _readClipboardAutoClearSeconds();
    _copyCountdownTimers[passwordId]?.cancel();

    if (countdownSeconds <= 0) {
      if (!mounted) return;
      setState(() => _copyCountdownById[passwordId] = 0);
      _copyCountdownTimers[passwordId] = Timer(
        const Duration(seconds: 2),
        () {
          if (!mounted) return;
          setState(() => _copyCountdownById.remove(passwordId));
          _copyCountdownTimers.remove(passwordId);
        },
      );
      return;
    }

    if (!mounted) return;
    setState(() => _copyCountdownById[passwordId] = countdownSeconds);
    _copyCountdownTimers[passwordId] = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final current = _copyCountdownById[passwordId];
        if (current == null || current <= 1) {
          timer.cancel();
          setState(() => _copyCountdownById.remove(passwordId));
          _copyCountdownTimers.remove(passwordId);
          return;
        }
        setState(() => _copyCountdownById[passwordId] = current - 1);
      },
    );
  }

  int _readClipboardAutoClearSeconds() {
    try {
      final provider = context.read<SecuritySettingsProvider>();
      return provider.clipboardAutoClearSeconds;
    } catch (_) {
      return SecuritySettingsProvider.defaultClipboardAutoClearSeconds;
    }
  }

  String _maskUsername(String username) {
    final normalized = username.trim();
    if (normalized.isEmpty) return '••••';

    final atIndex = normalized.indexOf('@');
    if (atIndex > 0 && atIndex < normalized.length - 1) {
      final local = normalized.substring(0, atIndex);
      final domain = normalized.substring(atIndex + 1);
      final localMaskLength = local.length > 1 ? local.length - 1 : 1;
      final localMasked = '${local[0]}${'•' * localMaskLength}';
      return '$localMasked@$domain';
    }

    if (normalized.length <= 2) return '•' * normalized.length;
    return '${normalized[0]}${'•' * (normalized.length - 2)}${normalized[normalized.length - 1]}';
  }
}

// ── Vault password card ───────────────────────────────────────────────────────

class _VaultPasswordCard extends StatefulWidget {
  const _VaultPasswordCard({
    super.key,
    required this.password,
    required this.maskedUsername,
    required this.countdownSeconds,
    required this.semanticColors,
    required this.onOpen,
    required this.onCopyUsername,
    required this.onCopyPassword,
    required this.onQuickCopyPassword,
    required this.onEdit,
    required this.onDeleteTap,
    required this.onDeleteHold,
  });

  final PasswordModel password;
  final String maskedUsername;
  final int? countdownSeconds;
  final AppSemanticColors semanticColors;
  final VoidCallback onOpen;
  final VoidCallback onCopyUsername;
  final VoidCallback onCopyPassword;
  final VoidCallback onQuickCopyPassword;
  final VoidCallback onEdit;
  final VoidCallback onDeleteTap;
  final VoidCallback onDeleteHold;

  @override
  State<_VaultPasswordCard> createState() => _VaultPasswordCardState();
}

class _VaultPasswordCardState extends State<_VaultPasswordCard> {
  static const double _maxRightSwipe = 96;
  static const double _maxLeftSwipe = -148;
  static const double _rightCopyThreshold = 64;
  static const double _leftRevealThreshold = -56;

  double _dragOffset = 0;

  void _closeActions() {
    if (_dragOffset == 0) return;
    setState(() => _dragOffset = 0);
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    final next = (_dragOffset + details.delta.dx).clamp(
      _maxLeftSwipe,
      _maxRightSwipe,
    );
    setState(() => _dragOffset = next);
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (_dragOffset >= _rightCopyThreshold) {
      widget.onQuickCopyPassword();
      setState(() => _dragOffset = 0);
      return;
    }
    if (_dragOffset <= _leftRevealThreshold) {
      setState(() => _dragOffset = _maxLeftSwipe);
      return;
    }
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasCopyFeedback = widget.countdownSeconds != null;
    final countdown = widget.countdownSeconds ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      // FIX: remove fixed height — let content determine height.
      // Fixed 92 clips copy countdown + large text scale.
      constraints: const BoxConstraints(minHeight: 80),
      child: Stack(
        children: [
          // ── Background action layer ──────────────────────────────────────
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: AppSpacing.lg),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.copy_rounded,
                            color: colorScheme.primary, size: 18),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Copy password',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 148,
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.semanticColors.destructive
                          .withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: ValueKey<String>(
                              'edit-action-${widget.password.id}'),
                          tooltip: 'Edit ${widget.password.title}',
                          icon: Icon(Icons.edit_outlined,
                              color: colorScheme.onSurface),
                          constraints: const BoxConstraints.tightFor(
                              width: 48, height: 48),
                          onPressed: () {
                            _closeActions();
                            widget.onEdit();
                          },
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Semantics(
                          button: true,
                          label: 'Hold to delete ${widget.password.title}',
                          hint: 'Long press to confirm delete.',
                          child: GestureDetector(
                            onTap: widget.onDeleteTap,
                            onLongPress: () {
                              _closeActions();
                              widget.onDeleteHold();
                            },
                            child: Container(
                              key: ValueKey<String>(
                                  'delete-action-${widget.password.id}'),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: widget.semanticColors.destructive
                                    .withValues(alpha: 0.18),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                              ),
                              child: Icon(
                                Icons.delete_outline_rounded,
                                color: widget.semanticColors.destructive,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Draggable card ───────────────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: GestureDetector(
              onHorizontalDragUpdate: _handleHorizontalDragUpdate,
              onHorizontalDragEnd: _handleHorizontalDragEnd,
              onTap: () {
                if (_dragOffset != 0) {
                  _closeActions();
                  return;
                }
                widget.onOpen();
              },
              child: Semantics(
                button: true,
                label:
                    '${widget.password.title}, masked username ${widget.maskedUsername}',
                hint:
                    'Swipe right to copy password. Swipe left to reveal edit and delete.',
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.large),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.10),
                        blurRadius: AppSpacing.md,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Row(
                    children: [
                      // Category icon
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer
                              .withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Icon(
                          PasswordCategories.iconFor(widget.password.category),
                          color: colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),

                      // Title + username + copy feedback
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.password.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.serviceName?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.maskedUsername,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              // FIX: onSurfaceVariant for username — visually
                              // subdued vs title, clearer hierarchy.
                              style: textTheme.usernameMasked?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (hasCopyFeedback) ...[
                              const SizedBox(height: AppSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.small),
                                ),
                                child: Text(
                                  countdown > 0
                                      ? 'Copied · clears in ${countdown}s'
                                      : 'Copied',
                                  style: textTheme.metadata?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Action buttons
                      // FIX: subtler styling — ghost buttons instead of
                      // filled primaryContainer, which competed with the card.
                      _CopyActionButton(
                        key: ValueKey<String>(
                            'copy-username-${widget.password.id}'),
                        icon: Icons.alternate_email_rounded,
                        semanticLabel:
                            'Copy username for ${widget.password.title}',
                        tooltip: 'Copy username',
                        onPressed: widget.onCopyUsername,
                      ),
                      _CopyActionButton(
                        key: ValueKey<String>(
                            'copy-password-${widget.password.id}'),
                        icon: Icons.copy_rounded,
                        semanticLabel:
                            'Copy password for ${widget.password.title}',
                        tooltip: 'Copy password',
                        onPressed: widget.onCopyPassword,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Copy action button ────────────────────────────────────────────────────────

class _CopyActionButton extends StatelessWidget {
  const _CopyActionButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        // FIX: ghost style — transparent bg, primary foreground.
        // Previous filled primaryContainer at 0.9 alpha was too dominant.
        style: IconButton.styleFrom(
          backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.35),
          foregroundColor: colorScheme.primary,
        ),
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

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
            style: textTheme.bodyMedium
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class EmptyVaultState extends StatelessWidget {
  const EmptyVaultState({
    super.key,
    required this.onAddItem,
    this.isPanicMode = false,
  });

  final VoidCallback onAddItem;
  final bool isPanicMode;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final colors = context.appColors;

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
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.cardSlate,
                        borderRadius: BorderRadius.circular(AppRadius.large),
                        border: Border.all(color: colors.subtleBorder),
                      ),
                      child: SvgPicture.asset(
                        'assets/illustrations/empty_vault.svg',
                        width: 172,
                        height: 132,
                        fit: BoxFit.contain,
                        semanticsLabel: 'Empty vault illustration',
                        placeholderBuilder: (_) => Icon(
                          Icons.lock_outline_rounded,
                          size: 64,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      isPanicMode ? loc.privacyModeLabel : loc.noPasswordsFound,
                      textAlign: TextAlign.center,
                      style: textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isPanicMode
                          ? loc.privacyModeHelperText
                          : 'Your vault is encrypted and ready.\nAdd your first item to get started.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.55,
                      ),
                    ),
                    if (!isPanicMode) ...[
                      const SizedBox(height: AppSpacing.xl),
                      FilledButton.icon(
                        onPressed: onAddItem,
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
                    ],
                    const SizedBox(height: AppSpacing.xl + AppSpacing.lg),
                    // FIX: updated hint to match actual swipe behavior
                    // (swipe left reveals actions, not direct delete)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.swipe_rounded,
                          size: 13,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'Swipe cards to copy or reveal actions',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            color: colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.5),
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
              color: colorScheme.onSurface.withValues(alpha: 0.45),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No results',
              style:
                  textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Try a different search or reset your filters.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
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
