import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../providers/password_provider.dart';
import '../services/app_facade.dart';
import 'login_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/language_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthFacade _authFacade = AuthFacade();
  final BackupFacade _backupFacade = BackupFacade();

  bool _biometricEnabled = false;
  bool _hardwareAvailable = false; // Cihazda parmak izi var mı?

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    bool enabled = await _authFacade.isBiometricEnabled();
    bool available = await _authFacade.isBiometricsAvailable();

    // GÜNCELLEME: Cihaz desteklemiyorsa veritabanındaki ayarı ARTIK DEĞİŞTİRMİYORUZ.
    // Böylece kullanıcı telefon değiştirirse tercihi (true/false) korunur.
    // UI tarafında switch zaten pasif (disabled) olacak.

    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _hardwareAvailable = available; // Donanım durumunu kaydet
      });
    }
  }

  // --- DİALOG FONKSİYONLARI ---
  void _showVerifyCurrentPinDialog() {
    final verifyController = TextEditingController();
    final loc = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(loc.verify),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(loc.verifyCurrentPinDescription),
          const SizedBox(height: 10),
          TextField(
              controller: verifyController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: const InputDecoration(
                  hintText: "••••••",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline))),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(loc.cancel)),
          FilledButton(
              onPressed: () async {
                bool isValid =
                    await _authFacade.verifyMasterPin(verifyController.text);

                // GÜVENLİK: İşlem biter bitmez controller'ı temizle
                verifyController.clear();

                if (isValid && mounted) {
                  Navigator.pop(context);
                  _showSetNewPinDialog();
                } else if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(loc.wrongPin),
                      backgroundColor: Colors.red));
                }
              },
              child: Text(loc.verify))
        ],
      ),
    );
  }

  void _showSetNewPinDialog() {
    final newPinController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(loc.setNewPinTitle),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(loc.setNewPinDescription),
                  const SizedBox(height: 10),
                  TextField(
                      controller: newPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: "••••••",
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.key))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel)),
                  FilledButton(
                      onPressed: () async {
                        final newPin = newPinController.text;
                        final provider = Provider.of<PasswordProvider>(context,
                            listen: false);
                        try {
                          await _authFacade.changeMasterPin(
                            context: context,
                            newPin: newPin,
                            provider: provider,
                          );

                          // GÜVENLİK: PIN değişti, belleği temizle
                          newPinController.clear();

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.pinChangeSuccess)));
                          }
                        } on AuthException catch (_) {
                          // Hata durumunda da temizle
                          newPinController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(loc.pinChangeFailed),
                                backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: Text(loc.save))
                ]));
  }

  void _showSetPanicPinDialog() {
    final panicController = TextEditingController();
    final loc = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(loc.setPanicPin),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(loc.enterPanicPin),
                  const SizedBox(height: 10),
                  TextField(
                      controller: panicController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: true,
                      decoration: const InputDecoration(
                          hintText: "••••••", border: OutlineInputBorder()))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(loc.cancel)),
                  FilledButton(
                      style:
                          FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () async {
                        try {
                          await _authFacade.setPanicPin(
                            context: context,
                            panicPin: panicController.text,
                          );

                          // GÜVENLİK: Panik PIN'i bellekte tutma
                          panicController.clear();

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(loc.panicPinSet)));
                          }
                        } on AuthException catch (e) {
                          panicController.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(e.message),
                                backgroundColor: Colors.red));
                          }
                        }
                      },
                      child: Text(loc.save))
                ]));
  }

  void _logout() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
      body: ListView(
        children: [
          const SizedBox(height: 20),

          // --- DİL SEÇİMİ ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(loc.language,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<LanguageMode>(
                    segments: [
                      ButtonSegment(
                        value: LanguageMode.system,
                        label: Text(loc.auto),
                        icon: const Icon(Icons.settings_system_daydream),
                      ),
                      ButtonSegment(
                        value: LanguageMode.en,
                        label: Text(loc.english),
                        icon: const Text("🇺🇸"),
                      ),
                      ButtonSegment(
                        value: LanguageMode.tr,
                        label: Text(loc.turkish),
                        icon: const Text("🇹🇷"),
                      ),
                      ButtonSegment(
                        value: LanguageMode.de,
                        label: const Text("Deutsch"),
                        icon: const Text("🇩🇪"),
                      ),
                    ],
                    selected: {languageProvider.currentMode},
                    onSelectionChanged: (Set<LanguageMode> newSelection) {
                      languageProvider.setLanguage(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // --- TEMA SEÇİCİ ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(loc.appearance,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(loc.auto),
                        icon: const Icon(Icons.brightness_auto),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(loc.light),
                        icon: const Icon(Icons.wb_sunny),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(loc.dark),
                        icon: const Icon(Icons.dark_mode),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (Set<ThemeMode> newSelection) {
                      themeProvider.setTheme(newSelection.first);
                    },
                    style: ButtonStyle(
                      visualDensity: VisualDensity.comfortable,
                      shape: MaterialStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.lock_reset, color: Colors.blueGrey),
            title: Text(loc.changeMasterPin),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showVerifyCurrentPinDialog,
          ),

          // --- BİYOMETRİK GİRİŞ ---
          SwitchListTile(
            secondary: Icon(Icons.fingerprint,
                color: _hardwareAvailable ? Colors.teal : Colors.grey),
            title: Text(loc.biometricLogin),
            subtitle: Text(_hardwareAvailable
                ? loc.biometricAvailable
                : loc.biometricUnavailable),
            value: _biometricEnabled,
            // Donanım yoksa (available=false) onChanged NULL olur -> Tıklanamaz.
            // Ama yukarıdaki 'value' sayesinde kullanıcının tercihi (açıksa) açık görünür.
            onChanged: _hardwareAvailable
                ? (val) async {
                    await _authFacade.setBiometricEnabled(val);
                    setState(() => _biometricEnabled = val);
                  }
                : null,
          ),

          ListTile(
            leading:
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
            title: Text(loc.setPanicPin),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showSetPanicPinDialog,
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(loc.dataManagement,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.grey)),
          ),

          ListTile(
            leading: const Icon(Icons.upload_file, color: Colors.purple),
            title: Text(loc.exportPasswords),
            onTap: () async {
              final provider =
                  Provider.of<PasswordProvider>(context, listen: false);
              await _backupFacade.exportPasswords(context, provider);
            },
          ),

          ListTile(
            leading: const Icon(Icons.download_for_offline, color: Colors.teal),
            title: Text(loc.importPasswords),
            onTap: () async {
              final provider =
                  Provider.of<PasswordProvider>(context, listen: false);
              await _backupFacade.importPasswords(context, provider);
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: Text(loc.deleteAllData,
                style: const TextStyle(color: Colors.redAccent)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(loc.deleteAllTitle),
                  content: Text(loc.deleteAllDescription),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(loc.cancel)),
                    TextButton(
                      onPressed: () async {
                        await Provider.of<PasswordProvider>(context,
                                listen: false)
                            .deleteAllPasswords();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.allPasswordsDeleted)),
                          );
                        }
                      },
                      child: Text(loc.delete,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),

          const Divider(),

          Padding(
            padding: const EdgeInsets.all(20.0),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout),
              label: Text(loc.logout),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _logout,
            ),
          ),
        ],
      ),
    );
  }
}
