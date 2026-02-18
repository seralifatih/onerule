import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/screens/home_screen.dart';
import 'package:offline_pass_manager/services/app_facade.dart';
import 'package:offline_pass_manager/services/database_service.dart';
import 'package:offline_pass_manager/widgets/add_password_sheet.dart';

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService(this._items);

  final List<PasswordModel> _items;

  @override
  Future<void> init() async {}

  @override
  List<PasswordModel> getAllPasswords() => List<PasswordModel>.from(_items);

  @override
  Future<void> addPassword(PasswordModel password) async {
    _items.add(password);
  }

  @override
  Future<void> deletePassword(String id) async {
    _items.removeWhere((item) => item.id == id);
  }

  @override
  Future<void> updatePassword(PasswordModel password) async {
    final index = _items.indexWhere((item) => item.id == password.id);
    if (index != -1) {
      _items[index] = password;
    }
  }

  @override
  Future<void> deleteAllPasswords() async {
    _items.clear();
  }

  @override
  Future<void> reencryptBox(List<int> newKey) async {}
}

class _FakeLockFacade extends LockFacade {
  int usernameCopyCalls = 0;
  int passwordCopyCalls = 0;

  @override
  void copyUsernameToClipboard({
    required BuildContext context,
    required String username,
    required String title,
  }) {
    usernameCopyCalls += 1;
  }

  @override
  void copyPasswordToClipboard({
    required BuildContext context,
    required String password,
    required String title,
  }) {
    passwordCopyCalls += 1;
  }
}

PasswordModel _entry() {
  return PasswordModel(
    id: 'copy-1',
    title: 'Github',
    username: 'dev@onerule.app',
    password: 'super-secret',
    category: 'General',
    createdDate: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('home tile has username copy action and it is callable', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();

    final fakeLockFacade = _FakeLockFacade();

    await tester.pumpWidget(
      ChangeNotifierProvider<PasswordProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HomeScreen(lockFacade: fakeLockFacade),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.alternate_email_rounded), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.alternate_email_rounded));
    await tester.pump();

    expect(fakeLockFacade.usernameCopyCalls, 1);
    expect(fakeLockFacade.passwordCopyCalls, 0);

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(fakeLockFacade.passwordCopyCalls, 1);
  });

  testWidgets('edit sheet shows separate username and password copy rows', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();

    await tester.pumpWidget(
      ChangeNotifierProvider<PasswordProvider>.value(
        value: provider,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Github'));
    await tester.pumpAndSettle();

    final sheetFinder = find.byType(AddPasswordSheet);
    expect(sheetFinder, findsOneWidget);

    expect(
      find.descendant(of: sheetFinder, matching: find.text('Username / Email')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: sheetFinder, matching: find.text('Password')),
      findsWidgets,
    );

    expect(
      find.descendant(
        of: sheetFinder,
        matching: find.byIcon(Icons.copy_rounded),
      ),
      findsNWidgets(2),
    );
  });
}
