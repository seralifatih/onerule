import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:offline_pass_manager/l10n/app_localizations.dart';

import 'models/password_model.dart';
import 'providers/password_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_facade.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(PasswordModelAdapter());

  // --- EKRAN GÜVENLİĞİ (Sadece Mobil) ---
  if (Platform.isAndroid || Platform.isIOS) {
    // Screenshot engelleme
    await ScreenProtector.preventScreenshotOn();

    // App switcher blur + ekran kaydı koruması
    await ScreenProtector.protectDataLeakageOn();
    await ScreenProtector.protectDataLeakageWithBlur();

    // iOS için ekran kaydı dinleyicisi
    ScreenProtector.addListener(() {}, (isCaptured) {
      if (isCaptured) {
        ScreenProtector.protectDataLeakageWithBlur();
      }
    });
  }
  // --------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PasswordProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
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

      // 🌍 Localization
      locale: languageProvider.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,

      themeMode: themeProvider.themeMode,

      // 🌞 Light Theme
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0284C7),
          secondary: Color(0xFF6366F1),
          surface: Colors.white,
          onSurface: Color(0xFF1E293B),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF0284C7), width: 2),
          ),
        ),
      ),

      // 🌙 Dark Theme
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF818CF8),
          surface: Color(0xFF1E293B),
          onSurface: Colors.white,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 2),
          ),
        ),
      ),

      home: const LifecycleManager(child: LoginScreen()),
    );
  }
}

// 🔐 App lifecycle lock manager
class LifecycleManager extends StatefulWidget {
  final Widget child;
  const LifecycleManager({super.key, required this.child});

  @override
  State<LifecycleManager> createState() => _LifecycleManagerState();
}

class _LifecycleManagerState extends State<LifecycleManager>
    with WidgetsBindingObserver {
  DateTime? _lastPausedTime;
  final int _lockTimeoutSeconds = 60;
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
    // Listener'ı sadece mobilde kaldır
    if (Platform.isAndroid || Platform.isIOS) {
      ScreenProtector.removeListener();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lockFacade.handleLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      _lastPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _lastPausedTime != null) {
      final diff = DateTime.now().difference(_lastPausedTime!);
      // Eğer süre aşılmışsa Login ekranına at
      if (diff.inSeconds > _lockTimeoutSeconds) {
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

// ⏳ Initialization Screen
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
      // Panik modunda değilse verileri yükle
      if (!provider.isPanicMode) {
        await provider.init().timeout(const Duration(seconds: 5));
      }
    } catch (_) {
      if (!mounted) return;

      // Hata durumunda kullanıcıya sor
      final action = await _showInitErrorDialog();
      if (!mounted) return;

      if (action == _InitErrorAction.retry) {
        _initialize(); // Tekrar dene
        return;
      }

      // Vazgeçerse Login ekranına dön
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (!mounted) return;

    // Her şey yolundaysa Home ekranına git
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Future<_InitErrorAction?> _showInitErrorDialog() async {
    // Context null check yapmaya gerek yok, mounted kontrolü yukarıda var
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
