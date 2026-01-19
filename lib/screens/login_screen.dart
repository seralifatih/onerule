import 'package:flutter/material.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/password_provider.dart';
import '../services/app_facade.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final AuthFacade _authFacade = AuthFacade();

  bool _isFirstTime = true; // İlk kurulum mu?
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  // Durumu kontrol et: Kullanıcı daha önce PIN belirlemiş mi?
  Future<void> _checkStatus() async {
    bool hasPin = await _authFacade.hasMasterPin();
    bool bioEnabled = await _authFacade.isBiometricEnabled(); // Ayarı oku

    setState(() {
      _isFirstTime = !hasPin;
      _isLoading = false;
    });

    // Eğer PIN varsa ve Biyometrik açıksa, hemen tarama başlat
    if (hasPin && bioEnabled) {
      _tryBiometricLogin();
    }
  }

  // Biyometrik giriş denemesi
  Future<void> _tryBiometricLogin() async {
    final provider = Provider.of<PasswordProvider>(context, listen: false);
    final success =
        await _authFacade.biometricLogin(context: context, provider: provider);
    if (success) _goToHome();
  }

  // Giriş butonuna basılınca (PIN ile)
  Future<void> _submit() async {
    String input = _pinController.text;

    try {
      final provider = Provider.of<PasswordProvider>(context, listen: false);
      await _authFacade.loginWithPin(
        context: context,
        pin: input,
        isFirstTime: _isFirstTime,
        provider: provider,
      );

      // GÜVENLİK: Giriş başarılı, PIN'i hemen temizle
      _pinController.clear();

      _goToHome();
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
        // Hata durumunda da temizle
        _pinController.clear();
      });
    }
  }

  void _goToHome() {
    // PIN doğruysa veritabanını yükleyen ekrana yönlendir
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const InitializationScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      // Arka plana hafif bir gradyan ekleyelim
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A),
              Color(0xFF1E1B4B)
            ], // Koyu Lacivertten Mora
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            // Klavye açılınca taşmasın diye
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Modern İkon & Gölge
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(Icons.lock_person_rounded,
                      size: 60, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 40),

                // Başlık
                Text(
                  _isFirstTime ? loc.createMasterPinTitle : loc.appTitle,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  _isFirstTime
                      ? loc.createMasterPinSubtitle
                      : loc.enterPinToDecrypt,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade400),
                ),
                const SizedBox(height: 40),

                // PIN Giriş Kutusu (Daha Şık)
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    counterText: "", // Alttaki karakter sayacını gizle
                    hintText: "••••••",
                    hintStyle: TextStyle(
                        color: Colors.grey.shade700, letterSpacing: 10),
                    filled: true,
                    fillColor: Colors.black26, // Daha koyu iç renk
                    errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2)),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 30),

                // Ana Buton
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      elevation: 10,
                      shadowColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.4),
                    ),
                    child: Text(
                        _isFirstTime ? loc.setMasterPinAction : loc.unlockVault,
                        style: const TextStyle(fontSize: 16, letterSpacing: 1)),
                  ),
                ),

                // Biyometrik Butonu (Modern)
                if (!_isFirstTime) ...[
                  const SizedBox(height: 24),
                  FutureBuilder<bool>(
                    future: _authFacade.isBiometricEnabled(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return GestureDetector(
                          onTap: _tryBiometricLogin,
                          child: Column(
                            children: [
                              Icon(Icons.fingerprint,
                                  size: 40,
                                  color:
                                      Theme.of(context).colorScheme.secondary),
                              const SizedBox(height: 8),
                              Text(loc.tapToUseBiometrics,
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
