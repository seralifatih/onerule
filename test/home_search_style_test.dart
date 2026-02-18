import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/screens/home_screen.dart';
import 'package:offline_pass_manager/services/database_service.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> init() async {}

  @override
  List<PasswordModel> getAllPasswords() => <PasswordModel>[];

  @override
  Future<void> addPassword(PasswordModel password) async {}

  @override
  Future<void> deletePassword(String id) async {}

  @override
  Future<void> updatePassword(PasswordModel password) async {}

  @override
  Future<void> deleteAllPasswords() async {}

  @override
  Future<void> reencryptBox(List<int> newKey) async {}
}

ThemeData _lightTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF0284C7),
      secondary: Color(0xFF6366F1),
      surface: Colors.white,
      onSurface: Color(0xFF1E293B),
    ),
  );
}

ThemeData _darkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFF818CF8),
      surface: Color(0xFF1E293B),
      onSurface: Colors.white,
    ),
  );
}

Widget _buildApp(ThemeMode mode) {
  final provider = PasswordProvider(dbService: _FakeDatabaseService());

  return ChangeNotifierProvider<PasswordProvider>.value(
    value: provider,
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _lightTheme(),
      darkTheme: _darkTheme(),
      themeMode: mode,
      home: const HomeScreen(),
    ),
  );
}

void _expectSearchFieldStyle({
  required WidgetTester tester,
  required ThemeData expectedTheme,
}) {
  final textField = tester.widget<TextField>(find.byType(TextField).first);
  final decoration = textField.decoration!;

  expect(textField.style?.color, expectedTheme.colorScheme.onSurface);
  expect(textField.cursorColor, expectedTheme.colorScheme.primary);
  expect(
    decoration.fillColor,
    expectedTheme.colorScheme.surfaceContainerHighest,
  );
  expect(
    decoration.hintStyle?.color,
    expectedTheme.colorScheme.onSurface.withValues(alpha: 0.65),
  );
}

void main() {
  testWidgets('search field uses high-contrast tokens in light theme', (
    WidgetTester tester,
  ) async {
    final lightTheme = _lightTheme();

    await tester.pumpWidget(_buildApp(ThemeMode.light));
    await tester.pumpAndSettle();

    _expectSearchFieldStyle(tester: tester, expectedTheme: lightTheme);
  });

  testWidgets('search field uses high-contrast tokens in dark theme', (
    WidgetTester tester,
  ) async {
    final darkTheme = _darkTheme();

    await tester.pumpWidget(_buildApp(ThemeMode.dark));
    await tester.pumpAndSettle();

    _expectSearchFieldStyle(tester: tester, expectedTheme: darkTheme);
  });
}
