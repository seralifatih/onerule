import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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
  String _errorMessage = '';
  String _pinInfoMessage = '';

  // ── First-time setup: acknowledgment step ──────────────────────────────
  // After the user enters their PIN the first time, we show a confirmation
  // step before actually saving. _pendingFirstTimePin holds the entered PIN
  // while the user reads and checks the acknowledgment.
  String? _pendingFirstTimePin;
  bool _showAcknowledgment = false;
  bool _pinAcknowledged = false;

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
      if (_pinController.text.length == 6 && !_isFirstTime) {
        // Auto-submit only on return visits — first-time needs the button
        _submit();
      }
      setState(() {});
    });

    _checkStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _pinFocusNode.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  // ── Auth flow ───────────────────────────────────────────────────────────

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

  // ── First-time PIN flow ─────────────────────────────────────────────────
  // Step 1: user enters PIN and taps "Set PIN"
  // Step 2: acknowledgment screen shown — checkbox must be ticked
  // Step 3: user taps "Confirm & Open Vault" → actual loginWithPin() call

  void _onSetPinTapped() {
    final input = _pinController.text;
    if (input.length < 4) {
      setState(() => _errorMessage = 'PIN must be at least 4 digits');
      return;
    }

    _analytics.primaryCtaTap(ctaId: 'login_set_pin', screen: 'login');

    // Stash the PIN, switch to acknowledgment view
    setState(() {
      _pendingFirstTimePin = input;
      _showAcknowledgment = true;
      _pinAcknowledged = false;
      _errorMessage = '';
    });

    // Dismiss keyboard — user needs to read, not type
    _pinFocusNode.unfocus();
  }

  Future<void> _confirmAndCreateVault() async {
    if (!_pinAcknowledged || _pendingFirstTimePin == null) return;

    final provider = context.read<PasswordProvider>();
    final biometricEnabled = await _authFacade.isBiometricEnabled();
    await _analytics.unlockAttempt(
        method: 'pin', biometricEnabled: biometricEnabled);
    if (!mounted) return;

    try {
      await _authFacade.loginWithPin(
        context: context,
        pin: _pendingFirstTimePin!,
        isFirstTime: true,
        provider: provider,
      );
      _pinController.clear();
      _pendingFirstTimePin = null;
      _goToHome();
    } on AuthException catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _errorMessage = e.message;
        _showAcknowledgment = false;
        _pendingFirstTimePin = null;
        _pinController.clear();
      });
    }
  }

  // ── Return-visit PIN submit ─────────────────────────────────────────────

  Future<void> _submit() async {
    final input = _pinController.text;
    if (input.length < 4) return;

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

  // ── Build ────────────────────────────────────────────────────────────────

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
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: gradient,
        child: GestureDetector(
          onTap: (_showPinEntry && !_showAcknowledgment)
              ? () => _pinFocusNode.requestFocus()
              : null,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl + AppSpacing.md,
                  vertical: AppSpacing.xl,
                ),
                child: _showAcknowledgment
                    ? _buildAcknowledgmentView(colorScheme, theme.textTheme)
                    : _buildMainView(colorScheme, theme.textTheme),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main PIN entry view ─────────────────────────────────────────────────

  Widget _buildMainView(ColorScheme colorScheme, TextTheme textTheme) {
    final loc = AppLocalizations.of(context)!;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildAppIcon(colorScheme),
        const SizedBox(height: AppSpacing.giant),
        Text(
          _isFirstTime ? loc.createMasterPinTitle : loc.appTitle,
          style: textTheme.headlineMedium?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          _isFirstTime ? loc.createMasterPinSubtitle : loc.enterPinToDecrypt,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.65),
            height: 1.5,
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
                        color: const Color(0xFFFF6B6B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : const SizedBox(height: 0),
          ),

          const SizedBox(height: AppSpacing.xl + AppSpacing.md),

          // First-time: show "Set PIN" button always so user knows to tap
          // Return visits: button hidden — auto-submit on 6 digits
          if (_isFirstTime)
            SizedBox(
              width: double.infinity,
              height: AppSpacing.giant + AppSpacing.lg - 1,
              child: FilledButton(
                onPressed:
                    _pinController.text.length >= 4 ? _onSetPinTapped : null,
                style: FilledButton.styleFrom(
                  elevation: AppElevation.high,
                  shadowColor: colorScheme.primary.withValues(alpha: 0.4),
                  disabledBackgroundColor:
                      colorScheme.onPrimary.withValues(alpha: 0.15),
                ),
                child: Text(
                  loc.setMasterPinAction,
                  style: textTheme.labelLarge?.copyWith(letterSpacing: 1),
                ),
              ),
            ),
        ] else if (_biometricInProgress) ...[
          _buildBiometricWaiting(loc, colorScheme, textTheme),
        ],
        if (!_isFirstTime && _showPinEntry && _isBiometricEnabled)
          _buildBiometricShortcut(loc, colorScheme, textTheme),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  // ── Acknowledgment view ─────────────────────────────────────────────────

  Widget _buildAcknowledgmentView(
      ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Warning icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.key_rounded,
              size: 36,
              color: Color(0xFFF59E0B),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        Text(
          'Remember your PIN',
          textAlign: TextAlign.center,
          style: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.3,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Warning cards
        _buildWarningCard(
          colorScheme: colorScheme,
          textTheme: textTheme,
          icon: Icons.lock_rounded,
          title: 'Your PIN encrypts everything',
          body:
              'It is used to encrypt your vault. Without it, your data cannot be decrypted by anyone — including the developer.',
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildWarningCard(
          colorScheme: colorScheme,
          textTheme: textTheme,
          icon: Icons.cloud_off_rounded,
          title: 'No recovery option exists',
          body:
              'OneRule is 100% offline. There is no account, no cloud backup, and no password reset. If you forget your PIN, your vault is permanently inaccessible.',
        ),

        const SizedBox(height: AppSpacing.sm),

        _buildWarningCard(
          colorScheme: colorScheme,
          textTheme: textTheme,
          icon: Icons.note_alt_outlined,
          title: 'Write it down somewhere safe',
          body:
              'Store your PIN in a secure physical location — a notebook, a safe, or a trusted place only you can access.',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Checkbox acknowledgment
        InkWell(
          onTap: () => setState(() => _pinAcknowledged = !_pinAcknowledged),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: _pinAcknowledged
                        ? colorScheme.onPrimary
                        : Colors.transparent,
                    border: Border.all(
                      color: _pinAcknowledged
                          ? colorScheme.onPrimary
                          : colorScheme.onPrimary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: _pinAcknowledged
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: colorScheme.primary,
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'I understand that if I forget my PIN, my vault cannot be recovered.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Confirm button — disabled until checkbox ticked
        SizedBox(
          width: double.infinity,
          height: AppSpacing.giant + AppSpacing.lg - 1,
          child: FilledButton(
            onPressed: _pinAcknowledged ? _confirmAndCreateVault : null,
            style: FilledButton.styleFrom(
              elevation: AppElevation.high,
              shadowColor: colorScheme.primary.withValues(alpha: 0.4),
              disabledBackgroundColor:
                  colorScheme.onPrimary.withValues(alpha: 0.12),
            ),
            child: Text(
              'Confirm & Open Vault',
              style: textTheme.labelLarge?.copyWith(letterSpacing: 0.5),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Go back — let user change their PIN
        TextButton(
          onPressed: () {
            setState(() {
              _showAcknowledgment = false;
              _pendingFirstTimePin = null;
              _pinAcknowledged = false;
              _pinController.clear();
            });
            _pinFocusNode.requestFocus();
          },
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.onPrimary.withValues(alpha: 0.6),
          ),
          child: const Text('← Change PIN'),
        ),

        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  Widget _buildWarningCard({
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: colorScheme.onPrimary.withValues(alpha: 0.12),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: colorScheme.onPrimary.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.65),
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

  // ── Shared sub-widgets ───────────────────────────────────────────────────

  Widget _buildAppIcon(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg + AppSpacing.xs),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: AppSpacing.xl,
            spreadRadius: AppSpacing.xs,
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/icon/app_icon.png',
          width: AppSpacing.giant + AppSpacing.giant / 2,
          height: AppSpacing.giant + AppSpacing.giant / 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(
            Icons.lock_person_rounded,
            size: AppSpacing.giant + AppSpacing.giant / 2,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPinBoxes(ColorScheme colorScheme) {
    const pinLength = 6;
    final currentLength = _pinController.text.length;

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final dx = _shakeAnimation.value == 0
            ? 0.0
            : 8.0 *
                (0.5 - (_shakeAnimation.value - 0.5).abs()) *
                (_shakeAnimation.value < 0.5 ? 1 : -1);
        return Transform.translate(
          offset: Offset(dx * 4, 0),
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(pinLength, (index) {
              final isFilled = index < currentLength;
              final isActive = index == currentLength;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                width: 44,
                height: 54,
                decoration: BoxDecoration(
                  color: isFilled
                      ? colorScheme.onPrimary.withValues(alpha: 0.2)
                      : colorScheme.onPrimary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(
                    color: isActive
                        ? colorScheme.onPrimary.withValues(alpha: 0.8)
                        : isFilled
                            ? colorScheme.onPrimary.withValues(alpha: 0.4)
                            : colorScheme.onPrimary.withValues(alpha: 0.15),
                    width: isActive ? 2 : 1.5,
                  ),
                ),
                child: Center(
                  child: isFilled
                      ? Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          ),
                        )
                      : null,
                ),
              );
            }),
          ),
          Opacity(
            opacity: 0,
            child: TextField(
              controller: _pinController,
              focusNode: _pinFocusNode,
              keyboardType: TextInputType.number,
              maxLength: pinLength,
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
              CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Waiting for biometric…',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onPrimary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: _usePinInstead,
          style: TextButton.styleFrom(foregroundColor: colorScheme.onPrimary),
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
          Material(
            color: colorScheme.onPrimary.withValues(alpha: 0.1),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _tryBiometricLogin,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Icon(
                  Icons.fingerprint,
                  size: AppSpacing.giant,
                  color: colorScheme.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            loc.tapToUseBiometrics,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}
