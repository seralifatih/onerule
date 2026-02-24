import 'package:flutter_test/flutter_test.dart';

import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/services/app_facade.dart';
import 'package:offline_pass_manager/services/biometric_service.dart';
import 'package:offline_pass_manager/services/database_service.dart';
import 'package:offline_pass_manager/services/secure_storage_service.dart';

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

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({
    required this.available,
    required this.authenticated,
  });

  final bool available;
  final bool authenticated;

  int authenticateCalls = 0;

  @override
  Future<bool> isBiometricsAvailable() async => available;

  @override
  Future<bool> authenticate({required String localizedReason}) async {
    authenticateCalls += 1;
    return authenticated;
  }

  @override
  Future<BiometricAuthResult> authenticateDetailed({
    required String localizedReason,
  }) async {
    authenticateCalls += 1;
    return BiometricAuthResult(authenticated: authenticated);
  }
}

class _FakeSecureStorageService extends SecureStorageService {
  _FakeSecureStorageService({required this.canRestoreSessionKey})
      : super.forTesting();

  final bool canRestoreSessionKey;

  int restoreCalls = 0;
  int checkMasterPinCalls = 0;

  @override
  Future<bool> restoreSessionKeyForBiometric() async {
    restoreCalls += 1;
    return canRestoreSessionKey;
  }

  @override
  Future<bool> checkMasterPin(String inputPin) async {
    checkMasterPinCalls += 1;
    return false;
  }
}

void main() {
  test('attemptBiometricUnlock success restores session directly', () async {
    final storage = _FakeSecureStorageService(canRestoreSessionKey: true);
    final biometrics =
        _FakeBiometricService(available: true, authenticated: true);
    final facade =
        AuthFacade(storageService: storage, biometricService: biometrics);
    final provider = PasswordProvider(dbService: _FakeDatabaseService());

    final outcome = await facade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: 'test',
    );

    expect(outcome, BiometricUnlockOutcome.success);
    expect(biometrics.authenticateCalls, 1);
    expect(storage.restoreCalls, 1);
    expect(storage.checkMasterPinCalls, 0);
  });

  test('attemptBiometricUnlock failure returns fallback outcome', () async {
    final storage = _FakeSecureStorageService(canRestoreSessionKey: true);
    final biometrics =
        _FakeBiometricService(available: true, authenticated: false);
    final facade =
        AuthFacade(storageService: storage, biometricService: biometrics);
    final provider = PasswordProvider(dbService: _FakeDatabaseService());

    final outcome = await facade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: 'test',
    );

    expect(outcome, BiometricUnlockOutcome.failedOrCanceled);
    expect(biometrics.authenticateCalls, 1);
    expect(storage.restoreCalls, 0);
  });

  test('attemptBiometricUnlock restore failure returns explicit outcome', () async {
    final storage = _FakeSecureStorageService(canRestoreSessionKey: false);
    final biometrics =
        _FakeBiometricService(available: true, authenticated: true);
    final facade =
        AuthFacade(storageService: storage, biometricService: biometrics);
    final provider = PasswordProvider(dbService: _FakeDatabaseService());

    final outcome = await facade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: 'test',
    );

    expect(outcome, BiometricUnlockOutcome.successButRestoreFailed);
    expect(biometrics.authenticateCalls, 1);
    expect(storage.restoreCalls, 1);
  });

  test('attemptBiometricUnlock unavailable returns fallback outcome', () async {
    final storage = _FakeSecureStorageService(canRestoreSessionKey: true);
    final biometrics =
        _FakeBiometricService(available: false, authenticated: false);
    final facade =
        AuthFacade(storageService: storage, biometricService: biometrics);
    final provider = PasswordProvider(dbService: _FakeDatabaseService());

    final outcome = await facade.attemptBiometricUnlock(
      provider: provider,
      localizedReason: 'test',
    );

    expect(outcome, BiometricUnlockOutcome.unavailable);
    expect(biometrics.authenticateCalls, 0);
    expect(storage.restoreCalls, 0);
  });
}
