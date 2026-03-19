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
import 'password_generator_screen.dart';
import 'settings_screen.dart';
import '../services/app_facade.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

enum _HomeContentState { loading, emptyVault, noResults, list }

enum _PasswordStrength { veryWeak, weak, strong, excellent }

_PasswordStrength _calcStrength(String password) {
  int score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 14) score++;
  if (RegExp(r'[A-Z]').hasMatch(password) &&
      RegExp(r'[a-z]').hasMatch(password)) {
    score++;
  }
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#\$%^&*()\-_=+\[\]{}|;:,.<>?]').hasMatch(password)) score++;
  if (score <= 1) return _PasswordStrength.veryWeak;
  if (score == 2) return _PasswordStrength.weak;
  if (score == 3) return _PasswordStrength.strong;
  return _PasswordStrength.excellent;
}

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

  DateTime? _lastBackupAt;
  bool _backupBannerDismissed = false;
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: _buildAppBar(context),
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
              if (provider.isPanicMode) _buildPanicActiveBanner(context),
              if (!provider.isPanicMode && _showAutofillSetupCard)
                _buildAutofillSetupBanner(context),
              if (!provider.isPanicMode && _shouldShowBackupBanner)
                _buildBackupBanner(context),
              if (!provider.isPanicMode &&
                  _showPanicModeBanner &&
                  provider.totalPasswordsCount > 0)
                _buildPanicOnboardingBanner(context),
              _buildHeaderSection(
                context: context,
                provider: provider,
                hasActiveRefinement: hasActiveRefinement,
                visibleItemsCount: passwords.length,
              ),
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
          return _ObsidianFAB(
            onPressed: () {
              _analytics.primaryCtaTap(
                ctaId: 'home_new_password',
                screen: 'home',
              );
              _openAddEditPage(context, null);
            },
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppBar(
      backgroundColor: colorScheme.surface,
      elevation: 0,
      titleSpacing: AppSpacing.lg,
      title: Row(
        children: [
          Icon(Icons.shield_rounded, color: colorScheme.primary, size: 26),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'The Vault',
            style: textTheme.titleLarge?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              fontSize: 22,
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.md),
          child: IconButton(
            icon: const Icon(Icons.settings),
            iconSize: 22,
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.surfaceContainerLow,
              foregroundColor: colorScheme.onSurfaceVariant,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              fixedSize: const Size(40, 40),
            ),
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
        ),
      ],
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow.withValues(alpha: 0.92),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 40,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.lock_outline_rounded,
                label: 'Vault',
                isActive: true,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.key_rounded,
                label: 'Generate',
                isActive: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordGeneratorScreen(),
                  ),
                ),
              ),
              _NavItem(
                icon: Icons.health_and_safety_outlined,
                label: 'Health',
                isActive: false,
                onTap: () {},
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                label: 'Settings',
                isActive: false,
                onTap: () async {
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
        ),
      ),
    );
  }

  // ── Banners ───────────────────────────────────────────────────────────────

  Widget _buildPanicActiveBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final loc = AppLocalizations.of(context)!;

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

  Widget _buildBackupBanner(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isNeverBacked = _lastBackupAt == null;

    return Container(
      width: double.infinity,
      color: colorScheme.primaryContainer.withValues(alpha: 0.15),
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
                color: colorScheme.onSurface,
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
                size: 16, color: colorScheme.onSurfaceVariant),
            padding: const EdgeInsets.all(AppSpacing.xs),
            constraints: const BoxConstraints(),
            onPressed: () => setState(() => _backupBannerDismissed = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPanicOnboardingBanner(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final semanticColors = Theme.of(context).extension<AppSemanticColors>() ??
        AppTheme.fallbackSemanticColors;
    final contentColor = semanticColors.warning;

    return Container(
      width: double.infinity,
      color: semanticColors.warning.withValues(alpha: 0.12),
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
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            cursorColor: colorScheme.primary,
            decoration: InputDecoration(
              hintText: loc.searchPasswordsHint,
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.45),
              ),
              prefixIcon:
                  Icon(Icons.search_rounded, color: colorScheme.onSurfaceVariant),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xlarge),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xlarge),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.xlarge),
                borderSide: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              suffixIcon: hasSearchQuery
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clearSearchQuery,
                    )
                  : hasActiveRefinement
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () =>
                              _clearSearchAndFilters(provider),
                        )
                      : total > 0
                          ? Padding(
                              padding:
                                  const EdgeInsets.only(right: AppSpacing.md),
                              child: Center(
                                widthFactor: 1,
                                child: Text(
                                  '$visibleItemsCount / $total',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : null,
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AppSpacing.md),
          // Filter chips
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primary
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
          border: selected
              ? null
              : Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          PasswordCategories.labelFor(loc, category),
          style: textTheme.labelMedium?.copyWith(
            color:
                selected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
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
            _openAddEditPage(context, null);
          },
        );
      case _HomeContentState.noResults:
        return NoResultsState(onClear: () => _clearSearchAndFilters(provider));
      case _HomeContentState.list:
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.giant + AppSpacing.giant + AppSpacing.lg,
          ),
          children: [
            if (recentPasswords.isNotEmpty) ...[
              _buildSectionHeader(
                context: context,
                label: 'Recently Used',
                count: provider.totalPasswordsCount,
                trailing: TextButton.icon(
                  onPressed: () => _setHideRecentlyUsed(!_hideRecentlyUsed),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: Icon(
                    _hideRecentlyUsed
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 14,
                  ),
                  label: Text(
                    _hideRecentlyUsed ? 'Show' : 'Hide',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              if (!_hideRecentlyUsed)
                ...recentPasswords.map(
                  (item) => _buildPasswordCard(context, item, provider),
                ),
              if (passwords.isNotEmpty && !_hideRecentlyUsed)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.sm,
                  ),
                  child: Divider(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.3),
                    height: 1,
                  ),
                ),
            ],
            if (passwords.isNotEmpty &&
                (recentPasswords.isEmpty || _hideRecentlyUsed))
              _buildSectionHeader(
                context: context,
                label: 'All Entries',
                count: provider.totalPasswordsCount,
              ),
            ...passwords
                .map((item) => _buildPasswordCard(context, item, provider)),
          ],
        );
    }
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String label,
    int? count,
    Widget? trailing,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm, 0, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (count != null)
            Text(
              '$count Items Total',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.0,
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

  void _openAddEditPage(BuildContext context, PasswordModel? password) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPasswordSheet(passwordToEdit: password),
      ),
    );
  }

  void _openPasswordDetails(BuildContext context, PasswordModel password) {
    _markEntryAccessed(password.id);
    _openAddEditPage(context, password);
  }

  // ── Password card ─────────────────────────────────────────────────────────

  Widget _buildPasswordCard(
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hold Delete to confirm.')),
          );
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

// ── Bottom nav item ───────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: isActive
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Obsidian FAB ──────────────────────────────────────────────────────────────

class _ObsidianFAB extends StatelessWidget {
  const _ObsidianFAB({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colorScheme.primary, colorScheme.primaryContainer],
          ),
          borderRadius: BorderRadius.circular(AppRadius.xlarge),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(Icons.add_rounded, color: colorScheme.onPrimary, size: 28),
      ),
    );
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
    final strength = _calcStrength(widget.password.password);
    final lastModified =
        widget.password.lastModified ?? widget.password.createdDate;
    final daysDiff = DateTime.now().difference(lastModified).inDays;
    final lastUpdatedText = daysDiff == 0
        ? 'Updated today'
        : daysDiff == 1
            ? 'Updated yesterday'
            : 'Updated ${daysDiff}d ago';

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
                      borderRadius:
                          BorderRadius.circular(AppRadius.xlarge),
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
                          'Copy',
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
                      borderRadius:
                          BorderRadius.circular(AppRadius.xlarge),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs),
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
                                    .withValues(alpha: 0.22),
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
                    color: colorScheme.surfaceContainer,
                    borderRadius:
                        BorderRadius.circular(AppRadius.xlarge),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top row: icon + title + strength ────────────────
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.large),
                            ),
                            child: Icon(
                              PasswordCategories.iconFor(
                                  widget.password.category),
                              color: colorScheme.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.password.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.maskedUsername,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurface
                                        .withValues(alpha: 0.85),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Strength indicator dots
                          _StrengthDots(
                            strength: strength,
                            colorScheme: colorScheme,
                          ),
                        ],
                      ),

                      if (hasCopyFeedback) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer
                                .withValues(alpha: 0.3),
                            borderRadius:
                                BorderRadius.circular(AppRadius.small),
                          ),
                          child: Text(
                            countdown > 0
                                ? 'Copied · clears in ${countdown}s'
                                : 'Copied',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],

                      // ── Bottom row: timestamp + actions ──────────────────
                      const SizedBox(height: AppSpacing.md),
                      Divider(
                        height: 1,
                        color: colorScheme.outlineVariant
                            .withValues(alpha: 0.25),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastUpdatedText,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.8,
                                fontSize: 10,
                              ),
                            ),
                          ),
                          _CardActionButton(
                            buttonKey: ValueKey<String>(
                              'copy-password-${widget.password.id}',
                            ),
                            icon: Icons.copy_rounded,
                            tooltip: 'Copy password',
                            semanticLabel:
                                'Copy password for ${widget.password.title}',
                            onPressed: widget.onCopyPassword,
                            colorScheme: colorScheme,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          _CardActionButton(
                            buttonKey: ValueKey<String>(
                              'copy-username-${widget.password.id}',
                            ),
                            icon: Icons.alternate_email_rounded,
                            tooltip: 'Copy username',
                            semanticLabel:
                                'Copy username for ${widget.password.title}',
                            onPressed: widget.onCopyUsername,
                            colorScheme: colorScheme,
                          ),
                        ],
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

// ── Strength dots indicator ───────────────────────────────────────────────────

class _StrengthDots extends StatelessWidget {
  const _StrengthDots({
    required this.strength,
    required this.colorScheme,
  });

  final _PasswordStrength strength;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final (activeDots, label, color) = switch (strength) {
      _PasswordStrength.veryWeak => (
          1,
          'Weak',
          colorScheme.error,
        ),
      _PasswordStrength.weak => (
          2,
          'Fair',
          const Color(0xFFD7383B),
        ),
      _PasswordStrength.strong => (
          3,
          'Strong',
          colorScheme.primary,
        ),
      _PasswordStrength.excellent => (
          4,
          'Excellent',
          colorScheme.tertiary,
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (i) {
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < activeDots
                    ? color
                    : colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ── Card action button ────────────────────────────────────────────────────────

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    this.buttonKey,
    required this.icon,
    required this.tooltip,
    this.semanticLabel,
    required this.onPressed,
    required this.colorScheme,
  });

  final Key? buttonKey;
  final IconData icon;
  final String tooltip;
  final String? semanticLabel;
  final VoidCallback onPressed;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(
          key: buttonKey,
          onTap: onPressed,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.medium),
            ),
            child: Icon(
              icon,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
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
          CircularProgressIndicator(color: colorScheme.primary),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: colors.cardSlate,
                        borderRadius:
                            BorderRadius.circular(AppRadius.xlarge),
                        border: Border.all(
                            color: colors.subtleBorder.withValues(alpha: 0.5)),
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
                        fontWeight: FontWeight.w700,
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
                      GestureDetector(
                        onTap: onAddItem,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xl,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primaryContainer,
                              ],
                            ),
                            borderRadius:
                                BorderRadius.circular(AppRadius.large),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Text(
                            'Add First Item',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl + AppSpacing.lg),
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
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No results',
              style: textTheme.titleLarge
                  ?.copyWith(color: colorScheme.onSurface),
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
