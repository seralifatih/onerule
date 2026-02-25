import 'package:flutter_test/flutter_test.dart';

import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/providers/password_provider.dart';
import 'package:offline_pass_manager/services/analytics_service.dart';
import 'package:offline_pass_manager/services/credential_provider.dart';
import 'package:offline_pass_manager/services/database_service.dart';

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService(this._entries);

  final List<PasswordModel> _entries;

  @override
  Future<void> init() async {}

  @override
  List<PasswordModel> getAllPasswords() => List<PasswordModel>.from(_entries);

  @override
  Future<List<PasswordModel>> getAllPasswordsDecrypted() async =>
      getAllPasswords();

  @override
  Future<void> addPassword(PasswordModel password) async {
    _entries.add(password);
  }

  @override
  Future<void> deletePassword(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
  }

  @override
  Future<void> updatePassword(PasswordModel password) async {
    final index = _entries.indexWhere((entry) => entry.id == password.id);
    if (index != -1) {
      _entries[index] = password;
    }
  }

  @override
  Future<void> deleteAllPasswords() async {
    _entries.clear();
  }

  @override
  Future<void> reencryptBox(List<int> newKey) async {}
}

class _NoopCredentialProvider implements CredentialProvider {
  @override
  Future<void> onVaultLocked() async {}

  @override
  Future<void> onVaultUnlocked(List<PasswordModel> entries) async {}

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<void> openSetup() async {}

  @override
  Future<bool> isSupported() async => false;
}

void main() {
  test('panic mode does not wipe vault data persisted in database', () async {
    final db = _FakeDatabaseService(<PasswordModel>[
      PasswordModel(
        id: 'entry-1',
        title: 'Email',
        username: 'user@example.com',
        password: 'secret-value',
        category: 'General',
        createdDate: DateTime(2026, 1, 1),
      ),
    ]);

    final provider = PasswordProvider(
      dbService: db,
      analytics: AnalyticsService(),
      credentialProvider: _NoopCredentialProvider(),
    );

    await provider.init();
    expect(provider.passwords.length, 1);
    expect(provider.totalPasswordsCount, 1);

    provider.enterPanicMode();
    expect(provider.isPanicMode, isTrue);
    expect(provider.passwords, isEmpty);
    expect(provider.totalPasswordsCount, 0);

    expect(db.getAllPasswords().length, 1);

    provider.exitPanicMode();
    await provider.init();

    expect(provider.isPanicMode, isFalse);
    expect(provider.passwords.length, 1);
    expect(provider.passwords.first.title, 'Email');
  });
}
