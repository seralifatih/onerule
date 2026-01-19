import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Dil Modları için Enum
enum LanguageMode { system, en, tr, de }

class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'languageMode';
  // Varsayılan: Sistem (Auto)
  LanguageMode _currentMode = LanguageMode.system;

  LanguageMode get currentMode => _currentMode;

  // MaterialApp'ın anlayacağı Locale çıktısı
  // Eğer 'system' seçiliyse NULL döner, böylece Flutter cihaz dilini kullanır.
  Locale? get locale {
    switch (_currentMode) {
      case LanguageMode.en:
        return const Locale('en');
      case LanguageMode.tr:
        return const Locale('tr');
      case LanguageMode.de:
        return const Locale('de');
      case LanguageMode.system:
        return null; // <--- SİHİR BURADA (Flutter otomatik algılar)
    }
  }

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    if (stored != null) {
      _currentMode = _modeFromString(stored);
    }
    notifyListeners();
  }

  Future<void> setLanguage(LanguageMode mode) async {
    _currentMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, _modeToString(mode));
  }

  LanguageMode _modeFromString(String value) {
    switch (value) {
      case 'en':
        return LanguageMode.en;
      case 'tr':
        return LanguageMode.tr;
      case 'de':
        return LanguageMode.de;
      case 'system':
        return LanguageMode.system;
      default:
        return LanguageMode.system;
    }
  }

  String _modeToString(LanguageMode mode) {
    switch (mode) {
      case LanguageMode.en:
        return 'en';
      case LanguageMode.tr:
        return 'tr';
      case LanguageMode.de:
        return 'de';
      case LanguageMode.system:
        return 'system';
    }
  }
}
