import 'package:flutter_test/flutter_test.dart';
import 'package:offline_pass_manager/features/autofill/autofill_feature_flag.dart';
import 'package:offline_pass_manager/services/autofill_mvp_service.dart';

class _FakeBridge implements AutofillMvpBridge {
  _FakeBridge({
    required this.supported,
    required this.nativeEnabled,
  });

  final bool supported;
  final bool nativeEnabled;
  int openCalls = 0;

  @override
  Future<bool> isPlatformSupported() async => supported;

  @override
  Future<bool> isNativeScaffoldEnabled() async => nativeEnabled;

  @override
  Future<void> openSystemAutofillSettings() async {
    openCalls += 1;
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
}
