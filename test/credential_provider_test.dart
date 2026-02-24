import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/features/autofill/autofill_feature_flag.dart';
import 'package:offline_pass_manager/models/password_model.dart';
import 'package:offline_pass_manager/services/autofill_mvp_service.dart';
import 'package:offline_pass_manager/services/credential_provider.dart';
import 'package:offline_pass_manager/services/secure_storage_service.dart';

class _FakeAutofillBridge implements AutofillMvpBridge {
  _FakeAutofillBridge({
    required this.platformSupported,
    required this.nativeEnabled,
    required this.autofillEnabled,
  });

  final bool platformSupported;
  final bool nativeEnabled;
  final bool autofillEnabled;

  String? lastPayload;
  String? lastSessionKeyBase64;
  int clearSessionCalls = 0;

  @override
  Future<bool> isPlatformSupported() async => platformSupported;

  @override
  Future<bool> isNativeScaffoldEnabled() async => nativeEnabled;

  @override
  Future<bool> isAutofillEnabled() async => autofillEnabled;

  @override
  Future<void> openSystemAutofillSettings() async {}

  @override
  Future<void> syncCredentialSnapshot(String payload) async {
    lastPayload = payload;
  }

  @override
  Future<void> setSessionKey(String sessionKeyBase64) async {
    lastSessionKeyBase64 = sessionKeyBase64;
  }

  @override
  Future<void> clearSessionKey() async {
    clearSessionCalls += 1;
  }
}

void main() {
  test('AndroidCredentialProvider syncs encrypted snapshot on unlock',
      () async {
    final bridge = _FakeAutofillBridge(
      platformSupported: true,
      nativeEnabled: true,
      autofillEnabled: true,
    );
    final autofillService = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );
    final storage = SecureStorageService.forTesting();
    storage.setSessionKey(List<int>.generate(32, (index) => index + 1));

    final provider = AndroidCredentialProvider(
      autofillService: autofillService,
      secureStorageService: storage,
    );

    await provider.onVaultUnlocked(
      <PasswordModel>[
        PasswordModel(
          id: 'id-1',
          title: 'GitHub',
          username: 'alice@example.com',
          password: 'secret-pass',
          url: 'https://github.com/login',
          createdDate: DateTime.utc(2026, 2, 24),
        ),
      ],
    );

    expect(bridge.lastSessionKeyBase64, isNotNull);
    expect(bridge.lastPayload, isNotNull);
    expect(bridge.lastPayload!.contains('secret-pass'), isFalse);
    expect(bridge.lastPayload!.contains('alice@example.com'), isFalse);

    final decoded = jsonDecode(bridge.lastPayload!) as Map<String, dynamic>;
    final credentials = decoded['credentials'] as List<dynamic>;
    expect(credentials.length, 1);
    final first = credentials.first as Map<String, dynamic>;
    expect(first['domains'], contains('github.com'));
    expect(first['displayNameEnc'], isNot('GitHub'));
    expect(first['usernameEnc'], isNot('alice@example.com'));
    expect(first['passwordEnc'], isNot('secret-pass'));
  });

  test('AndroidCredentialProvider clears native autofill session on lock',
      () async {
    final bridge = _FakeAutofillBridge(
      platformSupported: true,
      nativeEnabled: true,
      autofillEnabled: true,
    );
    final autofillService = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );
    final provider = AndroidCredentialProvider(
      autofillService: autofillService,
      secureStorageService: SecureStorageService.forTesting(),
    );

    await provider.onVaultLocked();
    expect(bridge.clearSessionCalls, 1);
  });

  test('AndroidCredentialProvider support/enabled status reflects bridge',
      () async {
    final bridge = _FakeAutofillBridge(
      platformSupported: true,
      nativeEnabled: true,
      autofillEnabled: false,
    );
    final autofillService = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );
    final provider = AndroidCredentialProvider(
      autofillService: autofillService,
      secureStorageService: SecureStorageService.forTesting(),
    );

    expect(await provider.isSupported(), isTrue);
    expect(await provider.isEnabled(), isFalse);
  });
}
