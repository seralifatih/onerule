import 'package:flutter/foundation.dart';

typedef AnalyticsPayload = Map<String, Object?>;

abstract class AnalyticsDispatcher {
  Future<void> dispatch(String eventName, AnalyticsPayload payload);
}

class DebugAnalyticsDispatcher implements AnalyticsDispatcher {
  @override
  Future<void> dispatch(String eventName, AnalyticsPayload payload) async {
    debugPrint('[analytics] $eventName $payload');
  }
}

class AnalyticsService {
  AnalyticsService({AnalyticsDispatcher? dispatcher})
      : _dispatcher = dispatcher ?? DebugAnalyticsDispatcher();

  static final AnalyticsService instance = AnalyticsService();

  final AnalyticsDispatcher _dispatcher;

  Future<void> credentialUpdateSubmitted() async {
    await _track(_EventNames.credentialUpdateSubmitted);
  }

  Future<void> credentialUpdateReflectedInList({
    required int totalItems,
    required String selectedCategory,
  }) async {
    await _track(_EventNames.credentialUpdateReflectedInList, <String, Object?>{
      'total_items': totalItems,
      'selected_category': selectedCategory,
    });
  }

  Future<void> vaultDeleteAllTriggered() async {
    await _track(_EventNames.vaultDeleteAllTriggered);
  }

  Future<void> vaultDeleteAllListEmptyConfirmed({required bool isEmpty}) async {
    await _track(
        _EventNames.vaultDeleteAllListEmptyConfirmed, <String, Object?>{
      'is_empty': isEmpty,
    });
  }

  Future<void> unlockAttempt({
    required String method,
    required bool biometricEnabled,
  }) async {
    await _track(_EventNames.unlockAttempt, <String, Object?>{
      'method': method,
      'biometric_enabled': biometricEnabled,
    });
  }

  Future<void> biometricPromptShown() async {
    await _track(_EventNames.biometricPromptShown);
  }

  Future<void> biometricSuccess() async {
    await _track(_EventNames.biometricSuccess);
  }

  Future<void> pinPromptShownAfterBiometric({required String reason}) async {
    await _track(_EventNames.pinPromptShownAfterBiometric, <String, Object?>{
      'reason': reason,
    });
  }

  Future<void> searchQueryChanged({required int queryLength}) async {
    await _track(_EventNames.searchQueryChanged, <String, Object?>{
      'query_length': queryLength,
    });
  }

  Future<void> primaryCtaTap({
    required String ctaId,
    required String screen,
  }) async {
    await _track(_EventNames.primaryCtaTap, <String, Object?>{
      'cta_id': ctaId,
      'screen': screen,
    });
  }

  Future<void> _track(String eventName, [AnalyticsPayload payload = const {}]) {
    return _dispatcher.dispatch(eventName, payload);
  }
}

class _EventNames {
  static const String credentialUpdateSubmitted = 'credential_update_submitted';
  static const String credentialUpdateReflectedInList =
      'credential_update_reflected_in_list';
  static const String vaultDeleteAllTriggered = 'vault_delete_all_triggered';
  static const String vaultDeleteAllListEmptyConfirmed =
      'vault_delete_all_list_empty_confirmed';
  static const String unlockAttempt = 'unlock_attempt';
  static const String biometricPromptShown = 'biometric_prompt_shown';
  static const String biometricSuccess = 'biometric_success';
  static const String pinPromptShownAfterBiometric =
      'pin_prompt_shown_after_biometric';
  static const String searchQueryChanged = 'search_query_changed';
  static const String primaryCtaTap = 'primary_cta_tap';
}
