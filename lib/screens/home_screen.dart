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
    final provider = context.read<PasswordProvider>();
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

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
      body: Column(
        children: [
          _buildSearchAndFilters(context, provider),
          Expanded(
            child: Selector<PasswordProvider, List<PasswordModel>>(
              selector: (_, value) => value.passwords,
              builder: (context, passwords, _) {
                if (passwords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_open_rounded,
                          size: 80,
                          color: colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.noPasswordsFound,
                          style: TextStyle(
                            color: colorScheme.onSurface.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: passwords.length,
                  padding: const EdgeInsets.only(top: 10, bottom: 100),
                  itemBuilder: (context, index) {
                    final password = passwords[index];
                    return _buildPasswordTile(context, password, provider);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
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
          elevation: 8,
          label: Text(
            loc.newPassword,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    PasswordProvider provider,
  ) {
    final loc = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                loc.searchPasswordsHint,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Selector<PasswordProvider, int>(
                selector: (_, value) => value.passwords.length,
                builder: (_, count, __) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: TextStyle(color: colorScheme.onSurface),
            cursorColor: colorScheme.primary,
            decoration: InputDecoration(
              hintText: loc.searchPasswordsHint,
              hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.65),
              ),
              prefixIcon: Icon(Icons.search, color: colorScheme.primary),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (query) {
              provider.search(query);
              _analytics.searchQueryChanged(queryLength: query.length);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Quick filters',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  provider.filterByCategory(PasswordCategories.all);
                  provider.search('');
                },
                child: const Text('Clear'),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Selector<PasswordProvider, String>(
              selector: (_, value) => value.selectedCategory,
              builder: (context, selectedCategory, _) {
                return Row(
                  children: PasswordCategories.filterCategories.map((category) {
                    final isSelected = selectedCategory == category;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(PasswordCategories.labelFor(loc, category)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (!selected) return;
                          provider.filterByCategory(category);
                          provider.search(_searchController.text);
                        },
                        backgroundColor: colorScheme.surface,
                        selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                        checkmarkColor: colorScheme.primary,
                        labelStyle: TextStyle(
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected
                                ? colorScheme.primary
                                : Colors.transparent,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openAddEditSheet(BuildContext context, PasswordModel? password) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(password.id),
      direction: DismissDirection.horizontal,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.edit, color: Colors.white, size: 28),
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
                        backgroundColor: Colors.red.withValues(alpha: 0.8),
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
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              PasswordCategories.iconFor(password.category),
              color: colorScheme.primary,
            ),
          ),
          title: Text(
            password.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                password.username,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      PasswordCategories.labelFor(loc, password.category)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (password.lastModified != null)
                    Text(
                      'Updated ${_shortDate(password.lastModified!)}',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 11,
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
                icon: Icon(
                  Icons.alternate_email_rounded,
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
                icon: Icon(
                  Icons.copy_rounded,
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
    );
  }

  String _shortDate(DateTime value) {
    final local = value.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}
