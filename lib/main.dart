import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';

import 'providers/language_provider.dart';
import 'providers/password_provider.dart';
import 'providers/security_settings_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_facade.dart';
import 'services/backup_reminder_service.dart';
import 'services/credential_provider.dart';
import 'services/local_log_service.dart';
import 'services/secure_storage_service.dart';
import 'theme/app_theme.dart';
import 'theme/app_spacing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalLogService.instance.initializeGlobalErrorHandlers();
  await BackupReminderService.instance.initialize();

  // Enable mobile screen protections.
  if (Platform.isAndroid || Platform.isIOS) {
    await ScreenProtector.preventScreenshotOn();
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.protectDataLeakageWithBlur();

    ScreenProtector.addListener(() {}, (isCaptured) {
      if (isCaptured) {
        ScreenProtector.protectDataLeakageWithBlur();
      }
    });
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PasswordProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => SecuritySettingsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'OneRule',
      debugShowCheckedModeBanner: false,
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      themeMode: themeProvider.themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const LifecycleManager(child: LoginScreen()),
    );
  }
}

class LifecycleManager extends StatefulWidget {
  const LifecycleManager({super.key, required this.child});

  final Widget child;

  @override
  State<LifecycleManager> createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager>
    with WidgetsBindingObserver {
  DateTime? _lastPausedTime;
  final LockFacade _lockFacade = LockFacade();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lockFacade.dispose();
    if (Platform.isAndroid || Platform.isIOS) {
      ScreenProtector.removeListener();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lockFacade.handleLifecycleState(state);
    final storage = SecureStorageService();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _lastPausedTime;
      _lastPausedTime = null;
      if (pausedAt == null) return;

      if (!storage.hasSessionKey) {
        return;
      }

      var timeoutSeconds =
          context.read<SecuritySettingsProvider>().autoLockTimeoutSeconds;
      if (timeoutSeconds <= 0) {
        timeoutSeconds = SecuritySettingsProvider.defaultAutoLockTimeoutSeconds;
      }
      final diff = DateTime.now().difference(pausedAt);
      if (diff.inSeconds > timeoutSeconds) {
        storage.clearSessionKey();
        unawaited(PlatformCredentialProvider().onVaultLocked());
        unawaited(context.read<PasswordProvider>().lockForSession());
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final provider = context.read<PasswordProvider>();

    try {
      if (!provider.isPanicMode) {
        await _initVaultWithRetry(provider);
      }
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[Initialization] init failed: $error');
        debugPrint('$stackTrace');
      }
      if (!mounted) return;

      final action = await _showInitErrorDialog();
      if (!mounted) return;

      if (action == _InitErrorAction.retry) {
        _initialize();
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  Future<void> _initVaultWithRetry(PasswordProvider provider) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final timeoutSeconds = attempt == 0 ? 12 : 20;
        if (kDebugMode) {
          debugPrint(
            '[Initialization] provider.init attempt=${attempt + 1} timeout=${timeoutSeconds}s',
          );
        }
        await provider.init().timeout(Duration(seconds: timeoutSeconds));
        if (kDebugMode) {
          debugPrint('[Initialization] provider.init success');
        }
        return;
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('[Initialization] provider.init attempt failed: $error');
        }
      }
    }

    throw lastError ?? Exception('Vault initialization failed');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Future<_InitErrorAction?> _showInitErrorDialog() async {
    final loc = AppLocalizations.of(context)!;

    return showDialog<_InitErrorAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(loc.initErrorTitle),
        content: Text(loc.initErrorBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _InitErrorAction.retry),
            child: Text(loc.retry),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _InitErrorAction.goToLogin),
            child: Text(loc.goToLogin),
          ),
        ],
      ),
    );
  }
}

enum _InitErrorAction { retry, goToLogin }
