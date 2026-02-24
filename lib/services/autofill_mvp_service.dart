import 'package:flutter/services.dart';
import '../features/autofill/autofill_feature_flag.dart';

enum AutofillMvpAvailability {
  disabledByFlag,
  unsupportedPlatform,
  nativeScaffoldDisabled,
  available,
}

abstract class AutofillMvpBridge {
  Future<bool> isPlatformSupported();
  Future<bool> isNativeScaffoldEnabled();
  Future<bool> isAutofillEnabled();
  Future<void> openSystemAutofillSettings();
  Future<void> syncCredentialSnapshot(String payload);
  Future<void> setSessionKey(String sessionKeyBase64);
  Future<void> clearSessionKey();
}

class MethodChannelAutofillMvpBridge implements AutofillMvpBridge {
  static const MethodChannel _channel = MethodChannel('onerule/autofill_mvp');

  @override
  Future<bool> isPlatformSupported() async {
    final result =
        await _channel.invokeMethod<bool>('isPlatformAutofillSupported');
    return result ?? false;
  }

  @override
  Future<bool> isNativeScaffoldEnabled() async {
    final result = await _channel.invokeMethod<bool>('isAutofillMvpEnabled');
    return result ?? false;
  }

  @override
  Future<bool> isAutofillEnabled() async {
    final result = await _channel.invokeMethod<bool>('isAutofillEnabled');
    return result ?? false;
  }

  @override
  Future<void> openSystemAutofillSettings() async {
    await _channel.invokeMethod<void>('openAutofillSettings');
  }

  @override
  Future<void> syncCredentialSnapshot(String payload) async {
    await _channel.invokeMethod<void>(
      'syncAutofillCredentialSnapshot',
      <String, Object?>{'payload': payload},
    );
  }

  @override
  Future<void> setSessionKey(String sessionKeyBase64) async {
    await _channel.invokeMethod<void>(
      'setAutofillSessionKey',
      <String, Object?>{'sessionKeyBase64': sessionKeyBase64},
    );
  }

  @override
  Future<void> clearSessionKey() async {
    await _channel.invokeMethod<void>('clearAutofillSessionKey');
  }
}

class AutofillMvpService {
  AutofillMvpService({
    AutofillFeatureFlag? featureFlag,
    AutofillMvpBridge? bridge,
  })  : _featureFlag = featureFlag ?? const AutofillFeatureFlag(),
        _bridge = bridge ?? MethodChannelAutofillMvpBridge();

  final AutofillFeatureFlag _featureFlag;
  final AutofillMvpBridge _bridge;

  Future<AutofillMvpAvailability> availability() async {
    if (!_featureFlag.isEnabled) {
      return AutofillMvpAvailability.disabledByFlag;
    }
    if (!await _bridge.isPlatformSupported()) {
      return AutofillMvpAvailability.unsupportedPlatform;
    }
    if (!await _bridge.isNativeScaffoldEnabled()) {
      return AutofillMvpAvailability.nativeScaffoldDisabled;
    }
    return AutofillMvpAvailability.available;
  }

  Future<bool> openSettingsIfAvailable() async {
    final state = await availability();
    if (state != AutofillMvpAvailability.available) {
      return false;
    }
    await _bridge.openSystemAutofillSettings();
    return true;
  }

  Future<bool> isEnabledInSystem() async {
    final state = await availability();
    if (state != AutofillMvpAvailability.available) {
      return false;
    }
    return _bridge.isAutofillEnabled();
  }

  Future<void> syncCredentialSnapshot({
    required String payload,
    required String sessionKeyBase64,
  }) async {
    final state = await availability();
    if (state != AutofillMvpAvailability.available) {
      return;
    }
    await _bridge.setSessionKey(sessionKeyBase64);
    await _bridge.syncCredentialSnapshot(payload);
  }

  Future<void> clearSessionKey() async {
    final state = await availability();
    if (state != AutofillMvpAvailability.available) {
      return;
    }
    await _bridge.clearSessionKey();
  }
}
