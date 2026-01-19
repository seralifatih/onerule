import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Proje adınıza göre import yolunu kontrol edin
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../constants/password_categories.dart';
import '../models/password_model.dart';
import '../providers/password_provider.dart';
import '../widgets/add_password_sheet.dart';
import 'settings_screen.dart';
import '../services/app_facade.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final LockFacade _lockFacade = LockFacade();

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

    return Scaffold(
      // --- APP BAR ---
      appBar: AppBar(
        title: Text(loc.myVaultTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()));
            },
          ),
        ],
      ),

      // --- BODY ---
      body: Column(
        children: [
          // 1. ARAMA VE FİLTRELEME ALANI
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
            ),
            child: Column(
              children: [
                // Modern Arama Kutusu
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: loc.searchPasswordsHint,
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    prefixIcon: Icon(Icons.search,
                        color: Theme.of(context).colorScheme.primary),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: provider.search,
                ),
                const SizedBox(height: 16),

                // Kategori Filtreleri (Yatay Liste)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Selector<PasswordProvider, String>(
                    selector: (_, provider) => provider.selectedCategory,
                    builder: (context, selectedCategory, _) {
                      return Row(
                        children:
                            PasswordCategories.filterCategories.map((category) {
                          final isSelected = selectedCategory == category;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              label: Text(
                                  PasswordCategories.labelFor(loc, category)),
                              selected: isSelected,
                              onSelected: (bool selected) {
                                if (selected) {
                                  provider.filterByCategory(category);
                                  provider.search(_searchController.text);
                                }
                              },
                              backgroundColor:
                                  Theme.of(context).colorScheme.surface,
                              selectedColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.2),
                              checkmarkColor:
                                  Theme.of(context).colorScheme.primary,
                              labelStyle: TextStyle(
                                color: isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent),
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
          ),

          // 2. ŞİFRE LİSTESİ
          Expanded(
            child: Selector<PasswordProvider, List<PasswordModel>>(
              selector: (_, provider) => provider.passwords,
              builder: (context, passwords, _) {
                if (passwords.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_open_rounded,
                            size: 80, color: Colors.white.withOpacity(0.05)),
                        const SizedBox(height: 16),
                        Text(
                          loc.noPasswordsFound,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 16),
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

      // --- FAB ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddEditSheet(context, null),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
        elevation: 10,
        label: Text(loc.newPassword,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
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
          child: AddPasswordSheet(passwordToEdit: password)),
    );
  }

  // --- LİSTE ELEMANI (SWIPE) ---
  Widget _buildPasswordTile(
      BuildContext context, PasswordModel password, PasswordProvider provider) {
    final loc = AppLocalizations.of(context)!;

    return Dismissible(
      key: Key(password.id),
      // Hem sağa hem sola kaydırmaya izin ver
      direction: DismissDirection.horizontal,

      // SOLA KAYDIRMA (SİLME) -> KIRMIZI
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8), // Koyu kırmızı
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.delete_forever, color: Colors.white, size: 28),
      ),

      // SAĞA KAYDIRMA (DÜZENLEME) -> YEŞİL
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.8), // Koyu yeşil
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.edit, color: Colors.white, size: 28),
      ),

      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // --- SOLDAN SAĞA (SİLME) ---
          return await showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(ctx).colorScheme.surface,
              title: Text(loc.deletePasswordTitle),
              content: Text(loc.deletePasswordMessage),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(loc.cancel)),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.8)),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(loc.delete),
                ),
              ],
            ),
          );
        } else {
          // --- SAĞDAN SOLA (DÜZENLEME) ---
          // Silme işlemini iptal et (false dön) ve düzenleme ekranını aç
          _openAddEditSheet(context, password);
          return false;
        }
      },

      onDismissed: (direction) {
        // Sadece silme yönü (startToEnd) onaylandığında burası çalışır
        if (direction == DismissDirection.startToEnd) {
          provider.deletePassword(password.id);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(loc.passwordDeleted)));
        }
      },

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          // Sol İkon Kutusu
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(PasswordCategories.iconFor(password.category),
                color: Theme.of(context).colorScheme.primary),
          ),

          title: Text(password.title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white)),

          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(password.username,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              const SizedBox(height: 8),
              // Kategori Etiketi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  PasswordCategories.labelFor(loc, password.category)
                      .toUpperCase(),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.secondary),
                ),
              ),
            ],
          ),

          // Kopyala Butonu
          trailing: IconButton(
            icon: Icon(Icons.copy_rounded, color: Colors.grey.shade600),
            onPressed: () {
              _lockFacade.copyPasswordToClipboard(
                context: context,
                password: password.password,
                title: password.title,
              );
            },
          ),

          onTap: () => _openAddEditSheet(context, password),
        ),
      ),
    );
  }
}
