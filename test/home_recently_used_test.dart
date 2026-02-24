import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/screens/home_screen.dart';
import 'package:offline_pass_manager/services/database_service.dart';

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
}

PasswordModel _entry({
  required String id,
  required String title,
  required String username,
}) {
  return PasswordModel(
    id: id,
    title: title,
    username: username,
    password: 'secret',
    category: 'General',
    createdDate: DateTime(2026, 1, 1),
  );
}

Future<void> _pumpHome(WidgetTester tester, PasswordProvider provider) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PasswordProvider>.value(
      value: provider,
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recently used section orders entries by latest access timestamp',
      (WidgetTester tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'recentAccessMap': jsonEncode(<String, int>{
        'id-1': now - 1000,
        'id-2': now,
      }),
      'hideRecentlyUsed': false,
    });

    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[
        _entry(id: 'id-1', title: 'GitHub', username: 'a@ex.com'),
        _entry(id: 'id-2', title: 'Reddit', username: 'b@ex.com'),
      ]),
    );
    await provider.init();
    await _pumpHome(tester, provider);

    expect(find.text('Recently Used'), findsOneWidget);
    final redditY = tester.getTopLeft(find.text('Reddit')).dy;
    final githubY = tester.getTopLeft(find.text('GitHub')).dy;
    expect(redditY, lessThan(githubY));
  });

  testWidgets('hide toggle keeps entries visible in all entries list',
      (WidgetTester tester) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    SharedPreferences.setMockInitialValues(<String, Object>{
      'recentAccessMap': jsonEncode(<String, int>{
        'id-1': now,
      }),
      'hideRecentlyUsed': false,
    });

    final provider = PasswordProvider(
      dbService: _FakeDatabaseService(<PasswordModel>[
        _entry(id: 'id-1', title: 'GitHub', username: 'a@ex.com'),
      ]),
    );
    await provider.init();
    await _pumpHome(tester, provider);

    expect(find.text('Recently Used'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);

    await tester.tap(find.text('Hide'));
    await tester.pumpAndSettle();

    expect(find.text('Show'), findsOneWidget);
    expect(find.text('All Entries'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });
}
