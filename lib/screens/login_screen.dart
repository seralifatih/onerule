import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import '../main.dart';
import 'package:provider/provider.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

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
  bool _isAuthenticating = false;
  bool _usePinRequested = false;
  String _errorMessage = '';
  String _pinInfoMessage = '';

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
    final bioAvailable = hasPin && bioEnabled
        ? await _authFacade.isBiometricsAvailable()
        : false;
    final canCheck = hasPin && bioEnabled
        ? await _authFacade.canCheckBiometrics()
        : false;
    final availableBiometrics = hasPin && bioEnabled
        ? await _authFacade.availableBiometrics()
        : const <String>[];

    if (kDebugMode) {
      debugPrint('[Login] biometricEnabled=$bioEnabled');
      debugPrint('[Login] canCheckBiometrics=$canCheck');
      debugPrint('[Login] availableBiometrics=$availableBiometrics');
      debugPrint('[Login] biometricsAvailable=$bioAvailable');
    }

    if (!mounted) return;

    setState(() {
      _isFirstTime = !hasPin;
      _isLoading = false;
      _showPinEntry = !hasPin || !bioEnabled || !bioAvailable;
      _biometricInProgress = hasPin && bioEnabled && bioAvailable;
      _isAuthenticating = false;
      _usePinRequested = false;
      _pinInfoMessage = '';
    });

    if (hasPin && bioEnabled && bioAvailable) {
      await _tryBiometricLogin(skipAvailabilityCheck: true);
    }
  }

  Future<void> _tryBiometricLogin({bool skipAvailabilityCheck = false}) async {
    if (_isAuthenticating) return;
    if (!skipAvailabilityCheck) {
      final available = await _authFacade.isBiometricsAvailable();
      if (!mounted) return;
      if (!available) {
        if (kDebugMode) {
          debugPrint('[Login] biometricsAvailable=false (manual attempt)');
        }
        setState(() {
          _biometricInProgress = false;
          _showPinEntry = true;
        });
        return;
      }
    }

    setState(() {
      _biometricInProgress = true;
      _showPinEntry = false;
      _isAuthenticating = true;
      _usePinRequested = false;
      _errorMessage = '';
      _pinInfoMessage = '';
    });
    final provider = context.read<PasswordProvider>();
    final localizedReason = AppLocalizations.of(context)!.biometricPrompt;

    await _analytics.unlockAttempt(method: 'biometric', biometricEnabled: true);
    await _analytics.biometricPromptShown();
    final outcome = await _authFacade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: localizedReason,
    );

    if (kDebugMode) {
      debugPrint('[Login] biometricAuthenticateResult=${outcome.name}');
    }

    if (!mounted) return;

    if (outcome == BiometricUnlockOutcome.success) {
      if (!_usePinRequested) {
        await _analytics.biometricSuccess();
        _goToHome();
        return;
      }
      setState(() {
        _isAuthenticating = false;
        _biometricInProgress = false;
        _showPinEntry = true;
      });
      return;
    }

    final pinInfoMessage = outcome == BiometricUnlockOutcome.successButRestoreFailed
        ? AppLocalizations.of(context)!.usePinToFinishUnlocking
        : '';

    await _analytics.pinPromptShownAfterBiometric(reason: outcome.name);

    setState(() {
      _isAuthenticating = false;
      _biometricInProgress = false;
      _showPinEntry = true;
      _pinInfoMessage = pinInfoMessage;
    });
  }

  void _usePinInstead() {
    setState(() {
      _usePinRequested = true;
      _biometricInProgress = false;
      _showPinEntry = true;
      _errorMessage = '';
      _pinInfoMessage = '';
    });
  }

  Future<void> _submit() async {
    final provider = context.read<PasswordProvider>();
    final input = _pinController.text;
    final biometricEnabled = await _authFacade.isBiometricEnabled();
    await _analytics.unlockAttempt(
      method: 'pin',
      biometricEnabled: biometricEnabled,
    );
    if (!mounted) return;

    try {
      await _authFacade.loginWithPin(
        context: context,
        pin: input,
        isFirstTime: _isFirstTime,
        provider: provider,
      );

      _pinController.clear();
      _pinInfoMessage = '';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final semanticColors =
        theme.extension<AppSemanticColors>() ?? AppTheme.fallbackSemanticColors;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final pinTextStyle = (textTheme.displayLarge ??
            textTheme.headlineMedium ??
            const TextStyle(fontSize: 32, fontWeight: FontWeight.w700))
        .copyWith(
      letterSpacing: AppSpacing.sm + AppSpacing.xs / 2,
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.w700,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              semanticColors.authGradientStart,
              semanticColors.authGradientEnd,
            ],
          ),
        ),
        child: DefaultTextStyle(
          style: (textTheme.bodyMedium ?? const TextStyle()).copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.9),
          ),
          child: IconTheme(
            data: IconThemeData(
              color: colorScheme.onPrimary.withValues(alpha: 0.85),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl + AppSpacing.md / 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: AppSpacing.xl - AppSpacing.xs,
                        spreadRadius: AppSpacing.sm - AppSpacing.xs + 1,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: AppSpacing.giant + AppSpacing.giant / 2,
                  ),
                ),
                const SizedBox(height: AppSpacing.giant),
                Text(
                  _isFirstTime ? loc.createMasterPinTitle : loc.appTitle,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm + AppSpacing.xs / 2),
                Text(
                  _isFirstTime
                      ? loc.createMasterPinSubtitle
                      : loc.enterPinToDecrypt,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: AppSpacing.giant),
                if (_showPinEntry) ...[
                  if (_pinInfoMessage.isNotEmpty) ...[
                    Text(
                      _pinInfoMessage,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  TextField(
                    controller: _pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    cursorColor: colorScheme.onPrimary,
                    style: pinTextStyle,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '',
                      hintStyle: pinTextStyle.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.45),
                      ),
                      filled: true,
                      fillColor: colorScheme.onPrimary.withValues(alpha: 0.12),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      errorText:
                          _errorMessage.isNotEmpty ? _errorMessage : null,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.xlarge - 4),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.xlarge - 4),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
                          width: 2,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: AppSpacing.xl + AppSpacing.md / 2),
                  SizedBox(
                    width: double.infinity,
                    height: AppSpacing.giant + AppSpacing.lg - 1,
                    child: FilledButton(
                      onPressed: () {
                        _analytics.primaryCtaTap(
                          ctaId: 'login_unlock',
                          screen: 'login',
                        );
                        _submit();
                      },
                      style: FilledButton.styleFrom(
                        elevation: AppElevation.high,
                        shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        _isFirstTime ? loc.setMasterPinAction : loc.unlockVault,
                        style: textTheme.labelLarge?.copyWith(
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ] else if (_biometricInProgress) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: AppSpacing.md),
                  TextButton(
                    onPressed: _usePinInstead,
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onPrimary,
                    ),
                    child: Text(loc.enterPin),
                  ),
                ],
                if (!_isFirstTime) ...[
                  const SizedBox(height: AppSpacing.xl),
                  FutureBuilder<bool>(
                    future: _authFacade.isBiometricEnabled(),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) {
                        return GestureDetector(
                          onTap: _tryBiometricLogin,
                          child: Column(
                            children: [
                              const Icon(
                                Icons.fingerprint,
                                size: AppSpacing.giant,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                loc.tapToUseBiometrics,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onPrimary
                                      .withValues(alpha: 0.7),
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
        ),
      ),
    );
  }
}
