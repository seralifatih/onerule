import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
  late final LockFacade _lockFacade;
  final AnalyticsService _analytics = AnalyticsService.instance;

  @override
  void initState() {
    super.initState();
    _lockFacade = widget.lockFacade ?? LockFacade();
  }

  @override
  void dispose() {
    _lockFacade.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.myVaultTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<PasswordProvider>(
        builder: (context, provider, _) {
          final passwords = provider.passwords;
          final contentState = _resolveContentState(
            provider: provider,
            visibleItemsCount: passwords.length,
          );

          return Column(
            children: [
              _buildHeaderSection(
                context: context,
                provider: provider,
                visibleItemsCount: passwords.length,
              ),
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
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: AppElevation.medium,
          label: Text(
            loc.newPassword,
            style: textTheme.labelLarge,
          ),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  _HomeContentState _resolveContentState({
    required PasswordProvider provider,
    required int visibleItemsCount,
  }) {
    if (provider.isLoading) {
      return _HomeContentState.loading;
    }
    if (provider.hasActiveRefinement && visibleItemsCount == 0) {
      return _HomeContentState.noResults;
    }
    if (provider.totalPasswordsCount == 0) {
      return _HomeContentState.emptyVault;
    }
    return _HomeContentState.list;
  }

  Widget _buildHeaderSection({
    required BuildContext context,
    required PasswordProvider provider,
    required int visibleItemsCount,
  }) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final hasActiveRefinement = provider.hasActiveRefinement;
    final isPrivacyMode = provider.isPanicMode;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md + AppSpacing.xs / 2,
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
          _buildVaultStatusIndicator(
            context: context,
            isPrivacyMode: isPrivacyMode,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _searchController,
            style: textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface),
            cursorColor: colorScheme.primary,
            decoration: InputDecoration(
              hintText: loc.searchPasswordsHint,
              hintStyle: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
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
              suffixIcon: hasActiveRefinement
                  ? Semantics(
                      button: true,
                      label: loc.clearSearchFiltersLabel,
                      child: IconButton(
                        tooltip: loc.clearSearchFiltersLabel,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _clearSearchAndFilters(provider),
                      ),
                    )
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
            ),
            onChanged: (query) {
              provider.search(query);
              _analytics.searchQueryChanged(queryLength: query.length);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$visibleItemsCount of ${provider.totalPasswordsCount}',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildFilterRow(context: context, provider: provider, loc: loc),
        ],
      ),
    );
  }

Widget _buildVaultStatusIndicator({
  required BuildContext context,
  required bool isPrivacyMode,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final loc = AppLocalizations.of(context)!;
  final normalLabel = loc.vaultLabel;
  final privacyModeLabel = loc.privacyModeLabel;
  final icon =
      isPrivacyMode ? Icons.shield_rounded : Icons.lock_open_rounded;
  final label = isPrivacyMode ? privacyModeLabel : normalLabel;

  return Semantics(
    label: label,
    readOnly: true,
    child: ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: AppSpacing.md,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
      selectedColor: colorScheme.primary.withValues(alpha: 0.2),
      checkmarkColor: colorScheme.primary,
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.xlarge - 4),
        side: BorderSide(
          color: selected ? colorScheme.primary : Colors.transparent,
        ),
      ),
    );
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
            top: AppSpacing.sm + AppSpacing.xs / 2,
            bottom: AppSpacing.giant + AppSpacing.giant + AppSpacing.lg,
          ),
          itemBuilder: (context, index) {
            final password = passwords[index];
            return _buildPasswordTile(context, password, provider);
          },
        );
    }
  }

  void _applyCategoryFilter(PasswordProvider provider, String category) {
    provider.filterByCategory(category);
    provider.search(_searchController.text);
  }

  void _clearSearchAndFilters(PasswordProvider provider) {
    _searchController.clear();
    provider.filterByCategory(PasswordCategories.all);
    provider.search('');
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
    final currentScale = media.textScaler.scale(1.0);
    final clampedScale = currentScale.clamp(1.0, 1.15).toDouble();

    return Dismissible(
      key: Key(password.id),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: semanticColors.destructive.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.xl),
        child: Icon(
          Icons.delete_forever,
          color: colorScheme.onError,
          size: AppSpacing.xl + AppSpacing.xs,
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: semanticColors.success.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        child: Icon(
          Icons.edit,
          color: colorScheme.onPrimary,
          size: AppSpacing.xl + AppSpacing.xs,
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          return await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Theme.of(ctx).colorScheme.surface,
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
                            semanticColors.destructive.withValues(alpha: 0.8),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(loc.delete),
                    ),
                  ],
                ),
              ) ??
              false;
        }

        _openAddEditSheet(context, password);
        return false;
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          provider.deletePassword(password.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(loc.passwordDeleted)),
          );
        }
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
            border: Border.all(color: colorScheme.outlineVariant, width: 1),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: AppSpacing.sm,
                offset: const Offset(0, AppSpacing.xs / 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
              child: Icon(
                PasswordCategories.iconFor(password.category),
                color: colorScheme.primary,
              ),
            ),
            title: Text(
              password.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Text(
                  password.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm - AppSpacing.xs / 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer
                            .withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(AppRadius.small - 2),
                      ),
                      child: Text(
                        PasswordCategories.labelFor(loc, password.category)
                            .toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (password.lastModified != null)
                      Flexible(
                        child: Text(
                          'Updated ${_shortDate(password.lastModified!)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  iconSize: 21,
                  icon: Icon(
                    Icons.alternate_email_rounded,
                    size: 21,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: loc.usernameEmailLabel,
                  onPressed: () {
                    _lockFacade.copyUsernameToClipboard(
                      context: context,
                      username: password.username,
                      title: password.title,
                    );
                  },
                ),
                IconButton(
                  iconSize: 21,
                  icon: Icon(
                    Icons.copy_rounded,
                    size: 21,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  tooltip: loc.passwordLabel,
                  onPressed: () {
                    _lockFacade.copyPasswordToClipboard(
                      context: context,
                      password: password.password,
                      title: password.title,
                    );
                  },
                ),
              ],
            ),
            onTap: () => _openAddEditSheet(context, password),
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

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

class EmptyVaultState extends StatelessWidget {
  const EmptyVaultState({super.key, required this.onAddItem});

  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: AppSpacing.giant + AppSpacing.xl,
              color: colorScheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              loc.noPasswordsFound,
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Your vault is ready. Add your first item when you want.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onAddItem,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ],
        ),
      ),
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
              'No matches found',
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
