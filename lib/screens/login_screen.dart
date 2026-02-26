import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/password_provider.dart';
import '../services/analytics_service.dart';
import '../services/app_facade.dart';
import '../services/backup_reminder_service.dart';
import '../theme/app_elevation.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

// ── Design tokens for the auth gradient surface ───────────────────────────────
// All text/icons on the dark gradient MUST use these instead of colorScheme.onPrimary,
// which resolves to dark navy on a cyan primary — invisible on dark backgrounds.
const _kOnGradient = Colors.white;
const _kOnGradientMid = Color(0xCCFFFFFF); // 80%
const _kOnGradientSub = Color(0xA3FFFFFF); // 64%
const _kOnGradientHint = Color(0x66FFFFFF); // 40%
const _kOnGradientFaint = Color(0x33FFFFFF); // 20%
const _kErrorColor = Color(0xFFFF6B6B);
const _kWarningText = Color(0xFFFFE6BF);
const _kWarningBorder = Color(0x73F59E0B);
const _kWarningBg = Color(0x24F59E0B);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authFacade});

  final AuthFacade? authFacade;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  static const int _pinLength = 6;
  static const int _minPinLength = 4;

  final TextEditingController _pinController = TextEditingController();
  final FocusNode _pinFocusNode = FocusNode();
  late final AuthFacade _authFacade;
  final AnalyticsService _analytics = AnalyticsService.instance;

  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;

  bool _isFirstTime = true;
  bool _isLoading = true;
  bool _showPinEntry = true;
  bool _biometricInProgress = false;
  bool _isAuthenticating = false;
  bool _usePinRequested = false;
  bool _isBiometricEnabled = false;

  int _onboardingStep = 0; // 0: welcome, 1: security, 2: pin setup, 3: panic
  bool _pinAcknowledged = false;
  bool _showPanicPinSetup = false;
  final TextEditingController _panicPinController = TextEditingController();

  String _errorMessage = '';
  String _pinInfoMessage = '';

  @override
  void initState() {
    super.initState();
    _authFacade = widget.authFacade ?? AuthFacade();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _pinController.addListener(() {
      if (_pinController.text.length == _pinLength && !_isFirstTime) {
        _submit();
      }
      if (mounted) setState(() {});
    });

    _checkStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _panicPinController.dispose();
    _pinFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Auth logic (unchanged) ──────────────────────────────────────────────────

  Future<void> _checkStatus() async {
    final hasPin = await _authFacade.hasMasterPin();
    final bioEnabled = await _authFacade.isBiometricEnabled();
    final bioAvailable = hasPin && bioEnabled
        ? await _authFacade.isBiometricsAvailable()
        : false;
    final canCheck =
        hasPin && bioEnabled ? await _authFacade.canCheckBiometrics() : false;
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
      _isBiometricEnabled = bioEnabled && bioAvailable;
      _showPinEntry = !hasPin || !bioEnabled || !bioAvailable;
      _biometricInProgress = hasPin && bioEnabled && bioAvailable;
      _isAuthenticating = false;
      _usePinRequested = false;
      _pinInfoMessage = '';

      if (_isFirstTime) {
        _onboardingStep = 0;
        _pinAcknowledged = false;
        _showPanicPinSetup = false;
        _errorMessage = '';
      }
    });

    if (_isFirstTime) {
      _pinController.clear();
      return;
    }

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

    if (kDebugMode) debugPrint('[Login] biometricResult=${outcome.name}');
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

    final pinInfoMessage =
        outcome == BiometricUnlockOutcome.successButRestoreFailed
            ? AppLocalizations.of(context)!.usePinToFinishUnlocking
            : '';

    await _analytics.pinPromptShownAfterBiometric(reason: outcome.name);

    setState(() {
      _isAuthenticating = false;
      _biometricInProgress = false;
      _showPinEntry = true;
      _pinInfoMessage = pinInfoMessage;
    });

    _pinFocusNode.requestFocus();
  }

  void _usePinInstead() {
    setState(() {
      _usePinRequested = true;
      _biometricInProgress = false;
      _showPinEntry = true;
      _errorMessage = '';
      _pinInfoMessage = '';
    });
    _pinFocusNode.requestFocus();
  }

  void _goToOnboardingStep(int step) {
    setState(() {
      _onboardingStep = step.clamp(0, 3);
      _errorMessage = '';
    });

    if (_onboardingStep == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _pinFocusNode.requestFocus();
      });
    }
  }

  Future<void> _submitFirstTimePin() async {
    final input = _pinController.text;
    if (input.length < _minPinLength) {
      setState(() => _errorMessage = 'PIN must be at least 4 digits');
      return;
    }
    if (!_pinAcknowledged || _isAuthenticating) return;

    final provider = context.read<PasswordProvider>();
    final biometricEnabled = await _authFacade.isBiometricEnabled();
    await _analytics.primaryCtaTap(
        ctaId: 'onboarding_continue', screen: 'onboarding');
    await _analytics.unlockAttempt(
        method: 'pin', biometricEnabled: biometricEnabled);
    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      await _authFacade.loginWithPin(
        context: context,
        pin: input,
        isFirstTime: true,
        provider: provider,
      );
      unawaited(
        BackupReminderService.instance
            .recordVaultCreationAndSchedule()
            .catchError((_) {}),
      );
      _pinController.clear();
      setState(() {
        _isAuthenticating = false;
        _showPanicPinSetup = false;
      });
      _goToOnboardingStep(3);
    } on AuthException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = e.message;
        _isAuthenticating = false;
      });
    }
  }

  Future<void> _setPanicPinNow() async {
    final panicPin = _panicPinController.text;
    if (panicPin.length < _minPinLength || _isAuthenticating) {
      setState(() => _errorMessage = 'PIN must be at least 4 digits');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = '';
    });

    try {
      await _authFacade.setPanicPin(
        context: context,
        panicPin: panicPin,
      );
      _panicPinController.clear();
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticating = false;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _submit() async {
    final input = _pinController.text;
    if (input.length < _minPinLength) return;

    final provider = context.read<PasswordProvider>();
    final biometricEnabled = await _authFacade.isBiometricEnabled();
    await _analytics.unlockAttempt(
        method: 'pin', biometricEnabled: biometricEnabled);
    if (!mounted) return;

    try {
      await _authFacade.loginWithPin(
        context: context,
        pin: input,
        isFirstTime: false,
        provider: provider,
      );
      _pinController.clear();
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
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

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semanticColors =
        theme.extension<AppSemanticColors>() ?? AppTheme.fallbackSemanticColors;

    final gradient = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          semanticColors.authGradientStart,
          semanticColors.authGradientEnd,
        ],
      ),
    );

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: gradient,
          child: const Center(
            child: CircularProgressIndicator(color: _kOnGradient),
          ),
        ),
      );
    }

    final shouldFocusPin = (!_isFirstTime && _showPinEntry) ||
        (_isFirstTime && _onboardingStep == 2);

    return Scaffold(
      body: Container(
        decoration: gradient,
        child: GestureDetector(
          onTap: shouldFocusPin ? () => _pinFocusNode.requestFocus() : null,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl + AppSpacing.md,
                  vertical: AppSpacing.xl,
                ),
                child: _isFirstTime
                    ? _buildOnboardingView(colorScheme, theme.textTheme)
                    : _buildMainView(colorScheme, theme.textTheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Onboarding router ───────────────────────────────────────────────────────

  Widget _buildOnboardingView(ColorScheme colorScheme, TextTheme textTheme) {
    switch (_onboardingStep) {
      case 0:
        return _buildWelcomeStep(colorScheme, textTheme);
      case 1:
        return _buildSecurityStep(colorScheme, textTheme);
      case 2:
        return _buildPinSetupStep(colorScheme, textTheme);
      case 3:
        return _buildPanicModeStep(colorScheme, textTheme);
      default:
        return _buildWelcomeStep(colorScheme, textTheme);
    }
  }

  // ── Step 0: Welcome ─────────────────────────────────────────────────────────

  Widget _buildWelcomeStep(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        _buildAppIcon(colorScheme),
        const SizedBox(height: AppSpacing.giant),
        Text(
          'Welcome to OneRule',
          textAlign: TextAlign.center,
          style: textTheme.headlineMedium?.copyWith(
            color: _kOnGradient,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Your offline vault with panic mode protection.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: _kOnGradientSub,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.lock_person_rounded,
          title: 'Offline vault',
          body:
              'Your vault stays on this device. OneRule does not require an account.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.warning_amber_rounded,
          title: 'Panic mode',
          body:
              'A separate panic PIN can open a decoy flow when you need plausible deniability.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildPrimaryButton(
          textTheme: textTheme,
          colorScheme: colorScheme,
          label: 'Continue',
          onPressed: () => _goToOnboardingStep(1),
        ),
      ],
    );
  }

  // ── Step 1: Security ────────────────────────────────────────────────────────

  Widget _buildSecurityStep(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        const Icon(Icons.shield_outlined, size: 64, color: _kOnGradient),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Security basics',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: _kOnGradient,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'No cloud. No accounts. Your encryption keys stay local.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: _kOnGradientSub,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.cloud_off_rounded,
          title: 'No cloud sync',
          body:
              'OneRule does not upload your vault. Data at rest is local-only.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.account_circle_outlined,
          title: 'No account system',
          body:
              'There is no account login or password reset service in the app.',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.enhanced_encryption_rounded,
          title: 'Encrypted vault',
          body:
              'Your PIN derives the key that unlocks the SQLCipher vault and field encryption.',
        ),
        const SizedBox(height: AppSpacing.xl),
        _buildNavRow(
          textTheme: textTheme,
          colorScheme: colorScheme,
          onBack: () => _goToOnboardingStep(0),
          onContinue: () => _goToOnboardingStep(2),
        ),
      ],
    );
  }

  // ── Step 2: PIN setup ───────────────────────────────────────────────────────

  Widget _buildPinSetupStep(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        const Icon(Icons.key_rounded, size: 64, color: _kOnGradient),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Set your Master PIN',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: _kOnGradient,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Use at least 4 digits. 6 digits is recommended.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: _kOnGradientSub),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildPinBoxes(colorScheme),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _errorMessage.isNotEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    _errorMessage,
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: _kErrorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              : const SizedBox(height: 0),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Warning card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: _kWarningBg,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(color: _kWarningBorder, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.warning_amber_rounded,
                    size: 16, color: Color(0xFFF59E0B)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'If you forget this PIN, your data cannot be recovered by anyone — including the developer. Write it down.',
                  style: textTheme.bodySmall?.copyWith(
                    color: _kWarningText,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Acknowledgment checkbox
        InkWell(
          onTap: () => setState(() => _pinAcknowledged = !_pinAcknowledged),
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs, horizontal: 2),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                    color: _pinAcknowledged ? _kOnGradient : _kOnGradientFaint,
                    border: Border.all(
                      color: _pinAcknowledged ? _kOnGradient : _kOnGradientHint,
                      width: 1.5,
                    ),
                  ),
                  child: _pinAcknowledged
                      ? Icon(Icons.check_rounded,
                          size: 14, color: colorScheme.primary)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'I understand — if I forget my PIN, my vault cannot be recovered.',
                    style: textTheme.bodySmall?.copyWith(
                      color: _kOnGradientMid,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        _buildNavRow(
          textTheme: textTheme,
          colorScheme: colorScheme,
          onBack: _isAuthenticating ? null : () => _goToOnboardingStep(1),
          onContinue: _pinController.text.length >= _minPinLength &&
                  _pinAcknowledged &&
                  !_isAuthenticating
              ? _submitFirstTimePin
              : null,
          continueLabel: 'Continue',
          isLoading: _isAuthenticating,
        ),
      ],
    );
  }

  // ── Step 3: Panic Mode ──────────────────────────────────────────────────────

  Widget _buildPanicModeStep(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      children: [
        const Icon(Icons.visibility_off_rounded, size: 64, color: _kOnGradient),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Panic Mode',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: _kOnGradient,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Set an optional decoy PIN. If someone forces a login, enter it to open a harmless decoy vault instead.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: _kOnGradientSub,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _buildInfoCard(
          textTheme: textTheme,
          icon: Icons.tips_and_updates_outlined,
          title: 'How it works',
          body:
              'Use a different PIN than your real one. Real PIN → your vault. Decoy PIN → panic mode.',
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'You can set or change this later in Settings → Panic PIN.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: _kOnGradientSub),
        ),
        const SizedBox(height: AppSpacing.xl),
        if (_showPanicPinSetup) ...[
          // Panic PIN field
          TextField(
            controller: _panicPinController,
            keyboardType: TextInputType.number,
            maxLength: _pinLength,
            obscureText: true,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: _kOnGradient, letterSpacing: 4),
            cursorColor: _kOnGradient,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Enter decoy PIN',
              hintStyle: const TextStyle(color: _kOnGradientHint),
              filled: true,
              fillColor: _kOnGradientFaint,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide: const BorderSide(color: _kOnGradientHint, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                borderSide:
                    const BorderSide(color: _kOnGradientMid, width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: _kErrorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _panicPinController.text.length >= _minPinLength &&
                      !_isAuthenticating
                  ? _setPanicPinNow
                  : null,
              style: FilledButton.styleFrom(
                elevation: AppElevation.high,
                shadowColor: colorScheme.primary.withValues(alpha: 0.4),
              ),
              child: _isAuthenticating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kOnGradient),
                    )
                  : Text('Save and Continue', style: textTheme.labelLarge),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isAuthenticating
                ? null
                : () => setState(() {
                      _showPanicPinSetup = false;
                      _panicPinController.clear();
                      _errorMessage = '';
                    }),
            style: TextButton.styleFrom(foregroundColor: _kOnGradientSub),
            child: const Text('Back'),
          ),
        ] else ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _showPanicPinSetup = true;
                      _errorMessage = '';
                    }),
                    style: FilledButton.styleFrom(
                      elevation: AppElevation.high,
                      shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                    ),
                    child: const Text('Set up now'),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _goToHome,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _kOnGradientHint),
                      foregroundColor: _kOnGradientSub,
                    ),
                    child: const Text('Skip'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── Return-visit unlock view ────────────────────────────────────────────────

  Widget _buildMainView(ColorScheme colorScheme, TextTheme textTheme) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAppIcon(colorScheme),
        const SizedBox(height: AppSpacing.giant),
        Text(
          loc.appTitle,
          style: textTheme.headlineMedium?.copyWith(
            color: _kOnGradient,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          loc.enterPinToDecrypt,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: _kOnGradientSub,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.giant),
        if (_showPinEntry) ...[
          if (_pinInfoMessage.isNotEmpty) ...[
            Text(
              _pinInfoMessage,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(color: _kOnGradientMid),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _buildPinBoxes(colorScheme),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: _errorMessage.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.md),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: _kErrorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : const SizedBox(height: 0),
          ),
        ] else if (_biometricInProgress) ...[
          _buildBiometricWaiting(loc, colorScheme, textTheme),
        ],
        if (_showPinEntry && _isBiometricEnabled)
          _buildBiometricShortcut(loc, colorScheme, textTheme),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  // ── Shared sub-widgets ──────────────────────────────────────────────────────

  /// Info card used throughout onboarding steps.
  Widget _buildInfoCard({
    required TextTheme textTheme,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _kOnGradientFaint,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: _kOnGradientHint, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kOnGradientSub),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelMedium?.copyWith(
                    color: _kOnGradient,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: _kOnGradientSub,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Full-width primary button.
  Widget _buildPrimaryButton({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          elevation: AppElevation.high,
          shadowColor: colorScheme.primary.withValues(alpha: 0.4),
        ),
        child: Text(label, style: textTheme.labelLarge),
      ),
    );
  }

  /// Back + Continue row used in steps 1 and 2.
  Widget _buildNavRow({
    required TextTheme textTheme,
    required ColorScheme colorScheme,
    VoidCallback? onBack,
    VoidCallback? onContinue,
    String continueLabel = 'Continue',
    bool isLoading = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 52,
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _kOnGradientHint),
                foregroundColor: _kOnGradientSub,
              ),
              child: const Text('Back'),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: onContinue,
              style: FilledButton.styleFrom(
                elevation: AppElevation.high,
                shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                disabledBackgroundColor: _kOnGradientFaint,
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _kOnGradient),
                    )
                  : Text(continueLabel, style: textTheme.labelLarge),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppIcon(ColorScheme colorScheme) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surface.withValues(alpha: 0.98),
            colorScheme.surface.withValues(alpha: 0.88),
          ],
        ),
        border: Border.all(
          color: colors.accentCyan.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.accentCyan.withValues(alpha: 0.35),
            blurRadius: AppSpacing.xl + AppSpacing.sm,
            spreadRadius: AppSpacing.xs + 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: AppSpacing.giant + AppSpacing.giant / 2 + AppSpacing.xs,
          height: AppSpacing.giant + AppSpacing.giant / 2 + AppSpacing.xs,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.lock_person_rounded,
            size: AppSpacing.giant + AppSpacing.giant / 2 + AppSpacing.xs,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPinBoxes(ColorScheme colorScheme) {
    final currentLength = _pinController.text.length;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeAnimation.value == 0
            ? 0.0
            : 8.0 *
                (0.5 - (_shakeAnimation.value - 0.5).abs()) *
                (_shakeAnimation.value < 0.5 ? 1 : -1);
        return Transform.translate(offset: Offset(dx * 4, 0), child: child);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (index) {
              final isFilled = index < currentLength;
              final isActive =
                  index == currentLength && currentLength < _pinLength;
              final scale = isFilled ? 1.0 : (isActive ? 0.92 : 0.82);

              return AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? _kOnGradientHint : _kOnGradientFaint,
                    border: Border.all(
                      color: isActive
                          ? _kOnGradient
                          : isFilled
                              ? _kOnGradientMid
                              : _kOnGradientHint,
                      width: isActive ? 1.8 : 1.2,
                    ),
                  ),
                  child: Center(
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      scale: isFilled ? 1 : 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _kOnGradient,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          // Invisible input capture
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              keyboardType: TextInputType.number,
              maxLength: _pinLength,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(counterText: ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricWaiting(
    AppLocalizations loc,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child:
              CircularProgressIndicator(color: _kOnGradient, strokeWidth: 2.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Waiting for biometric...',
          style: textTheme.bodyMedium?.copyWith(color: _kOnGradientMid),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: _usePinInstead,
          style: TextButton.styleFrom(foregroundColor: _kOnGradientSub),
          child: Text(loc.enterPin),
        ),
      ],
    );
  }

  Widget _buildBiometricShortcut(
    AppLocalizations loc,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _tryBiometricLogin,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                elevation: AppElevation.medium,
                shadowColor: colorScheme.primary.withValues(alpha: 0.35),
              ),
              icon: const Icon(Icons.fingerprint_rounded, size: 22),
              label: Text(loc.tapToUseBiometrics, style: textTheme.labelLarge),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Biometric unlock is available on this device',
            style: textTheme.bodySmall?.copyWith(color: _kOnGradientHint),
          ),
        ],
      ),
    );
  }
}
