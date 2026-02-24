import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Future<List<PasswordModel>> getAllPasswordsDecrypted() async =>
      getAllPasswords();

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

Future<void> _pumpHome(
  WidgetTester tester, {
  required PasswordProvider provider,
  LockFacade? lockFacade,
}) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PasswordProvider>.value(
      value: provider,
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(lockFacade: lockFacade),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
      'home cards expose always-visible copy username and password actions', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();

    final fakeLockFacade = _FakeLockFacade();
    await _pumpHome(tester, provider: provider, lockFacade: fakeLockFacade);

    final usernameButton =
        find.byKey(const ValueKey<String>('copy-username-copy-1'));
    final passwordButton =
        find.byKey(const ValueKey<String>('copy-password-copy-1'));

    expect(usernameButton, findsOneWidget);
    expect(passwordButton, findsOneWidget);

    await tester.tap(usernameButton);
    await tester.pumpAndSettle();
    await tester.tap(passwordButton);
    await tester.pumpAndSettle();

    expect(fakeLockFacade.usernameCopyCalls, 1);
    expect(fakeLockFacade.passwordCopyCalls, 1);
    expect(
      find.bySemanticsLabel('Copy username for Github'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Copy password for Github'),
      findsOneWidget,
    );
  });

  testWidgets('swipe right instantly copies password and shows countdown chip',
      (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();

    final fakeLockFacade = _FakeLockFacade();
    await _pumpHome(tester, provider: provider, lockFacade: fakeLockFacade);

    final card = find.byKey(const ValueKey<String>('vault-card-copy-1'));
    expect(card, findsOneWidget);

    await tester.drag(card, const Offset(220, 0));
    await tester.pumpAndSettle();

    expect(fakeLockFacade.passwordCopyCalls, 1);
    expect(find.textContaining('Copied • Clears in '), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Copied • Clears in 28s'), findsOneWidget);
  });

  testWidgets('swipe left reveals edit and hold-to-delete actions', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();
    await _pumpHome(tester, provider: provider);

    final card = find.byKey(const ValueKey<String>('vault-card-copy-1'));
    await tester.drag(card, const Offset(-220, 0));
    await tester.pumpAndSettle();

    final editAction = find.byKey(const ValueKey<String>('edit-action-copy-1'));
    final deleteAction =
        find.byKey(const ValueKey<String>('delete-action-copy-1'));

    expect(editAction, findsOneWidget);
    expect(deleteAction, findsOneWidget);

    await tester.tap(deleteAction);
    await tester.pumpAndSettle();
    expect(find.text('Github'), findsOneWidget);
    expect(find.text('Hold Delete to confirm.'), findsOneWidget);

    await tester.longPress(deleteAction);
    await tester.pumpAndSettle();
    expect(find.text('Github'), findsNothing);
  });

  testWidgets('swipe-left edit action opens edit sheet', (
    WidgetTester tester,
  ) async {
    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[_entry()]),
    );
    await provider.init();
    await _pumpHome(tester, provider: provider);

    final card = find.byKey(const ValueKey<String>('vault-card-copy-1'));
    await tester.drag(card, const Offset(-220, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('edit-action-copy-1')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPasswordSheet), findsOneWidget);
  });
}
