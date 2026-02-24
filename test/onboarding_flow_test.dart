import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:offline_pass_manager/l10n/app_localizations.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/screens/login_screen.dart';
import 'package:offline_pass_manager/services/app_facade.dart';
import 'package:offline_pass_manager/services/database_service.dart';

class _FakeDatabaseService extends DatabaseService {
  @override
  Future<void> init() async {}

  @override
  List<PasswordModel> getAllPasswords() => <PasswordModel>[];

  @override
  Future<List<PasswordModel>> getAllPasswordsDecrypted() async =>
      getAllPasswords();

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

class _FirstRunAuthFacade extends AuthFacade {
  int loginCalls = 0;
  int panicPinCalls = 0;

  @override
  Future<bool> hasMasterPin() async => false;

  @override
  Future<bool> isBiometricEnabled() async => false;

  @override
  Future<bool> isBiometricsAvailable() async => false;

  @override
  Future<void> loginWithPin({
    required BuildContext context,
    required String pin,
    required bool isFirstTime,
    required PasswordProvider provider,
  }) async {
    loginCalls += 1;
    if (!isFirstTime) {
      throw StateError('Expected first-time PIN setup flow.');
    }
  }

  @override
  Future<void> setPanicPin({
    required BuildContext context,
    required String panicPin,
  }) async {
    panicPinCalls += 1;
  }
}

Widget _buildApp(AuthFacade authFacade) {
  return ChangeNotifierProvider<PasswordProvider>(
    create: (_) => PasswordProvider(dbService: _FakeDatabaseService()),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: LoginScreen(authFacade: authFacade),
    ),
  );
}

Future<void> _goToPinSetupStep(WidgetTester tester) async {
  final continueFinder = find.widgetWithText(FilledButton, 'Continue');
  for (var i = 0; i < 5; i++) {
    if (continueFinder.evaluate().isNotEmpty) {
      break;
    }
    await tester.pump();
  }

  await tester.tap(continueFinder);
  await tester.pumpAndSettle();

  await tester.tap(continueFinder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('first-run onboarding shows 3 screens with required messaging', (
    WidgetTester tester,
  ) async {
    final auth = _FirstRunAuthFacade();

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome to OneRule'), findsOneWidget);
    expect(
      find.text('Your offline vault with panic mode protection.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Security basics'), findsOneWidget);
    expect(
      find.text('No cloud. No accounts. Your encryption keys stay local.'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Set your Master PIN'), findsOneWidget);
    expect(
      find.text(
        'If you forget this PIN, your data cannot be recovered by anyone, including the developer. Write it down.',
      ),
      findsOneWidget,
    );
    expect(find.text('I understand'), findsOneWidget);
  });

  testWidgets('PIN setup Continue is gated by required "I understand" checkbox',
      (
    WidgetTester tester,
  ) async {
    final auth = _FirstRunAuthFacade();

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();
    await tester.pump();

    await _goToPinSetupStep(tester);

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();

    final continueFinder = find.widgetWithText(FilledButton, 'Continue');
    FilledButton continueButton = tester.widget<FilledButton>(continueFinder);
    expect(continueButton.onPressed, isNull);
    expect(auth.loginCalls, 0);

    await tester.tap(find.text('I understand'));
    await tester.pump();

    continueButton = tester.widget<FilledButton>(continueFinder);
    expect(continueButton.onPressed, isNotNull);

    await tester.tap(continueFinder);
    await tester.pumpAndSettle();

    expect(auth.loginCalls, 1);
    expect(find.text('Panic Mode'), findsOneWidget);
    expect(find.text('Set up now'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('panic mode step supports Skip path', (
    WidgetTester tester,
  ) async {
    final auth = _FirstRunAuthFacade();

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();
    await tester.pump();

    await _goToPinSetupStep(tester);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('I understand'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Panic Mode'), findsOneWidget);
    expect(auth.panicPinCalls, 0);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
    await tester.pumpAndSettle();
    expect(auth.panicPinCalls, 0);
  });

  testWidgets('panic mode step supports Set up now path', (
    WidgetTester tester,
  ) async {
    final auth = _FirstRunAuthFacade();

    await tester.pumpWidget(_buildApp(auth));
    await tester.pump();
    await tester.pump();

    await _goToPinSetupStep(tester);
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.text('I understand'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Set up now'));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(FilledButton, 'Save and Continue'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '5678');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save and Continue'));
    await tester.pumpAndSettle();
    expect(auth.panicPinCalls, 1);
  });
}
