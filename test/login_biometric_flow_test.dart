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

class _FakeAuthFacade extends AuthFacade {
  _FakeAuthFacade({
    required this.biometricOutcome,
    this.biometricsAvailable = true,
  });

  final BiometricUnlockOutcome biometricOutcome;
  final bool biometricsAvailable;

  int biometricAttempts = 0;
  int pinLogins = 0;

  @override
  Future<bool> hasMasterPin() async => true;

  @override
  Future<bool> isBiometricEnabled() async => true;

  @override
  Future<bool> isBiometricsAvailable() async => biometricsAvailable;

  @override
  Future<bool> canCheckBiometrics() async => biometricsAvailable;

  @override
  Future<List<String>> availableBiometrics() async =>
      biometricsAvailable ? <String>['fingerprint'] : const <String>[];

  @override
  Future<BiometricUnlockOutcome> attemptBiometricUnlock({
    required PasswordProvider provider,
    required String localizedReason,
  }) async {
    biometricAttempts += 1;
    return biometricOutcome;
  }

  @override
  Future<void> loginWithPin({
    required BuildContext context,
    required String pin,
    required bool isFirstTime,
    required PasswordProvider provider,
  }) async {
    pinLogins += 1;
  }
}

class _NavigatorSpy extends NavigatorObserver {
  int replaceCount = 0;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    replaceCount += 1;
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }
}

Widget _buildApp(AuthFacade authFacade, _NavigatorSpy observer) {
  return ChangeNotifierProvider<PasswordProvider>(
    create: (_) => PasswordProvider(dbService: _FakeDatabaseService()),
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: <NavigatorObserver>[observer],
      home: LoginScreen(authFacade: authFacade),
    ),
  );
}

void main() {
  testWidgets('biometric success path does not show PIN prompt', (
    WidgetTester tester,
  ) async {
    final auth = _FakeAuthFacade(
      biometricOutcome: BiometricUnlockOutcome.success,
    );
    final observer = _NavigatorSpy();

    await tester.pumpWidget(_buildApp(auth, observer));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(auth.biometricAttempts, 1);
    expect(auth.pinLogins, 0);
    expect(observer.replaceCount, greaterThanOrEqualTo(1));
    expect(find.text('Search passwords...'), findsOneWidget);
  });

  testWidgets('biometric failure path falls back to PIN prompt', (
    WidgetTester tester,
  ) async {
    final auth = _FakeAuthFacade(
      biometricOutcome: BiometricUnlockOutcome.failedOrCanceled,
    );
    final observer = _NavigatorSpy();

    await tester.pumpWidget(_buildApp(auth, observer));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(auth.biometricAttempts, 1);
    expect(observer.replaceCount, 0);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('biometric unavailable path falls back to PIN prompt', (
    WidgetTester tester,
  ) async {
    final auth = _FakeAuthFacade(
      biometricOutcome: BiometricUnlockOutcome.unavailable,
      biometricsAvailable: false,
    );
    final observer = _NavigatorSpy();

    await tester.pumpWidget(_buildApp(auth, observer));
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(auth.biometricAttempts, 0);
    expect(observer.replaceCount, 0);
    expect(find.byType(TextField), findsOneWidget);
  });
}
