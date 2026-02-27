import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/language_provider.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/providers/security_settings_provider.dart';
import 'package:offline_pass_manager/providers/theme_provider.dart';
import 'package:offline_pass_manager/screens/home_screen.dart';
import 'package:offline_pass_manager/services/database_service.dart';

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService(List<PasswordModel> initial)
      : _items = initial.map(_copy).toList();

  final List<PasswordModel> _items;

  static PasswordModel _copy(PasswordModel model) {
    return PasswordModel(
      id: model.id,
      title: model.title,
      username: model.username,
      password: model.password,
      url: model.url,
      createdDate: model.createdDate,
      lastModified: model.lastModified,
      category: model.category,
    );
  }

  @override
  Future<void> init() async {}

  @override
  List<PasswordModel> getAllPasswords() => _items.map(_copy).toList();

  @override
  Future<List<PasswordModel>> getAllPasswordsDecrypted() async =>
      getAllPasswords();

  @override
  Future<void> addPassword(PasswordModel password) async {
    _items.add(_copy(password));
  }

  @override
  Future<void> deletePassword(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> updatePassword(PasswordModel password) async {
    final index = _items.indexWhere((item) => item.id == password.id);
    if (index != -1) {
      _items[index] = _copy(password);
    }
  }

  @override
  Future<void> deleteAllPasswords() async {
    _items.clear();
  }

  @override
  Future<void> reencryptBox(List<int> newKey) async {}
}

Widget _buildTestApp(PasswordProvider passwordProvider) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<PasswordProvider>.value(value: passwordProvider),
      ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider(),
      ),
      ChangeNotifierProvider<SecuritySettingsProvider>(
        create: (_) => SecuritySettingsProvider(),
      ),
    ],
    child: const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: HomeScreen(),
    ),
  );
}

PasswordModel _model({required String id, required String category}) {
  return PasswordModel(
    id: id,
    title: 'GitHub',
    username: 'dev@onerule.app',
    password: 'secret',
    category: category,
    createdDate: DateTime(2026, 1, 1),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Home shows updated title after password update', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService([_model(id: '1', category: 'General')]),
    );
    await provider.init();

    await tester.pumpWidget(_buildTestApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('GitHub Work'), findsNothing);

    final updated = provider.passwords.first;
    updated.title = 'GitHub Work';
    updated.lastModified = DateTime(2026, 1, 2);
    await provider.updatePassword(updated);

    await tester.pumpAndSettle();

    expect(find.text('GitHub Work'), findsOneWidget);
    expect(find.text('GitHub'), findsNothing);
  });

  testWidgets('Delete all from Settings refreshes Home empty state', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService([_model(id: '2', category: 'General')]),
    );
    await provider.init();

    await tester.pumpWidget(_buildTestApp(provider));
    await tester.pumpAndSettle();

    expect(find.text('No passwords found.'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byIcon(Icons.delete_forever),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byIcon(Icons.delete_forever));
    await tester.pumpAndSettle();

    final deleteButton = find
        .descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextButton))
        .last;
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('No passwords found.'), findsOneWidget);
  });
}
