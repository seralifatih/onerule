import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/features/autofill/autofill_feature_flag.dart';
import 'package:offline_pass_manager/services/autofill_mvp_service.dart';

class _FakeBridge implements AutofillMvpBridge {
  _FakeBridge({
    required this.supported,
    required this.nativeEnabled,
    this.autofillEnabled = false,
  });

  final bool supported;
  final bool nativeEnabled;
  final bool autofillEnabled;
  int openCalls = 0;
  int snapshotSyncCalls = 0;
  int sessionSetCalls = 0;
  int sessionClearCalls = 0;

  @override
  Future<bool> isPlatformSupported() async => supported;

  @override
  Future<bool> isNativeScaffoldEnabled() async => nativeEnabled;

  @override
  Future<bool> isAutofillEnabled() async => autofillEnabled;

  @override
  Future<void> openSystemAutofillSettings() async {
    openCalls += 1;
  }

  @override
  Future<void> syncCredentialSnapshot(String payload) async {
    snapshotSyncCalls += 1;
  }

  @override
  Future<void> setSessionKey(String sessionKeyBase64) async {
    sessionSetCalls += 1;
  }

  @override
  Future<void> clearSessionKey() async {
    sessionClearCalls += 1;
  }
}

void main() {
  test('autofill service is disabled when feature flag is off', () async {
    final bridge = _FakeBridge(supported: true, nativeEnabled: true);
    final service = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: false),
      bridge: bridge,
    );

    final state = await service.availability();
    final opened = await service.openSettingsIfAvailable();

    expect(state, AutofillMvpAvailability.disabledByFlag);
    expect(opened, false);
    expect(bridge.openCalls, 0);
  });

  test('autofill service opens settings when all guards pass', () async {
    final bridge = _FakeBridge(supported: true, nativeEnabled: true);
    final service = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );

    final state = await service.availability();
    final opened = await service.openSettingsIfAvailable();

    expect(state, AutofillMvpAvailability.available);
    expect(opened, true);
    expect(bridge.openCalls, 1);
  });

  test('autofill sync writes session key and encrypted snapshot', () async {
    final bridge = _FakeBridge(
      supported: true,
      nativeEnabled: true,
      autofillEnabled: true,
    );
    final service = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );

    await service.syncCredentialSnapshot(
      payload: '{"credentials":[]}',
      sessionKeyBase64: 'ZmFrZV9rZXk',
    );

    expect(bridge.sessionSetCalls, 1);
    expect(bridge.snapshotSyncCalls, 1);
  });

  test('autofill enabled state is delegated to native bridge', () async {
    final bridge = _FakeBridge(
      supported: true,
      nativeEnabled: true,
      autofillEnabled: true,
    );
    final service = AutofillMvpService(
      featureFlag: const AutofillFeatureFlag(overrideEnabled: true),
      bridge: bridge,
    );

    final enabled = await service.isEnabledInSystem();
    expect(enabled, true);
  });
}
