import 'package:flutter/material.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authFacade});

  final AuthFacade? authFacade;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  late final AuthFacade _authFacade;
  final AnalyticsService _analytics = AnalyticsService.instance;

  bool _isFirstTime = true;
  bool _isLoading = true;
  bool _showPinEntry = true;
  bool _biometricInProgress = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _authFacade = widget.authFacade ?? AuthFacade();
    _checkStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final hasPin = await _authFacade.hasMasterPin();
    final bioEnabled = await _authFacade.isBiometricEnabled();

    if (!mounted) return;

    setState(() {
      _isFirstTime = !hasPin;
      _isLoading = false;
      _showPinEntry = !hasPin || !bioEnabled;
      _biometricInProgress = hasPin && bioEnabled;
    });

    if (hasPin && bioEnabled) {
      await _tryBiometricLogin();
    }
  }

  Future<void> _tryBiometricLogin() async {
    if (_biometricInProgress && !_showPinEntry) {
      // Continue current attempt.
    } else {
      setState(() {
        _biometricInProgress = true;
        _errorMessage = '';
      });
    }

    await _analytics.unlockAttempt(method: 'biometric', biometricEnabled: true);
    await _analytics.biometricPromptShown();

    final provider = Provider.of<PasswordProvider>(context, listen: false);
    final outcome = await _authFacade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: AppLocalizations.of(context)!.biometricPrompt,
    );

    if (!mounted) return;

    if (outcome == BiometricUnlockOutcome.success) {
      await _analytics.biometricSuccess();
      _goToHome();
      return;
    }

    await _analytics.pinPromptShownAfterBiometric(reason: outcome.name);

    setState(() {
      _biometricInProgress = false;
      _showPinEntry = true;
    });
  }

  Future<void> _submit() async {
    final input = _pinController.text;
    final biometricEnabled = await _authFacade.isBiometricEnabled();
    await _analytics.unlockAttempt(
      method: 'pin',
      biometricEnabled: biometricEnabled,
    );

    try {
      final provider = Provider.of<PasswordProvider>(context, listen: false);
      await _authFacade.loginWithPin(
        context: context,
        pin: input,
        isFirstTime: _isFirstTime,
        provider: provider,
      );

      _pinController.clear();
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _pinController.clear();
      });
    }
  }

  void _goToHome() {
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
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
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.lock_person_rounded,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  _isFirstTime ? loc.createMasterPinTitle : loc.appTitle,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
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
                if (_showPinEntry) ...[
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
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '* * * * * *',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade700,
                        letterSpacing: 10,
                      ),
                      filled: true,
                      fillColor: Colors.black26,
                      errorText:
                          _errorMessage.isNotEmpty ? _errorMessage : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      onPressed: () {
                        _analytics.primaryCtaTap(
                          ctaId: 'login_unlock',
                          screen: 'login',
                        );
                        _submit();
                      },
                      style: FilledButton.styleFrom(
                        elevation: 10,
                        shadowColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.4),
                      ),
                      child: Text(
                        _isFirstTime ? loc.setMasterPinAction : loc.unlockVault,
                        style: const TextStyle(fontSize: 16, letterSpacing: 1),
                      ),
                    ),
                  ),
                ] else if (_biometricInProgress) ...[
                  const CircularProgressIndicator(),
                ],
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
                              Icon(
                                Icons.fingerprint,
                                size: 40,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                loc.tapToUseBiometrics,
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
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
