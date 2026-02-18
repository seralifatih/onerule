import 'package:flutter_test/flutter_test.dart';

import 'package:offline_pass_manager/services/analytics_service.dart';

class _FakeDispatcher implements AnalyticsDispatcher {
  final List<String> eventNames = <String>[];
  final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];

  @override
  Future<void> dispatch(String eventName, Map<String, Object?> payload) async {
    eventNames.add(eventName);
    payloads.add(payload);
  }
}

void main() {
  test('typed analytics methods dispatch expected event names', () async {
    final dispatcher = _FakeDispatcher();
    final analytics = AnalyticsService(dispatcher: dispatcher);

    await analytics.credentialUpdateSubmitted();
    await analytics.credentialUpdateReflectedInList(
      totalItems: 3,
      selectedCategory: 'All',
    );
    await analytics.vaultDeleteAllTriggered();
    await analytics.vaultDeleteAllListEmptyConfirmed(isEmpty: true);
    await analytics.unlockAttempt(method: 'pin', biometricEnabled: true);
    await analytics.biometricPromptShown();
    await analytics.biometricSuccess();
    await analytics.pinPromptShownAfterBiometric(reason: 'failedOrCanceled');
    await analytics.searchQueryChanged(queryLength: 4);
    await analytics.primaryCtaTap(ctaId: 'home_new_password', screen: 'home');

    expect(dispatcher.eventNames, <String>[
      'credential_update_submitted',
      'credential_update_reflected_in_list',
      'vault_delete_all_triggered',
      'vault_delete_all_list_empty_confirmed',
      'unlock_attempt',
      'biometric_prompt_shown',
      'biometric_success',
      'pin_prompt_shown_after_biometric',
      'search_query_changed',
      'primary_cta_tap',
    ]);

    expect(dispatcher.payloads[1]['total_items'], 3);
    expect(dispatcher.payloads[1]['selected_category'], 'All');
    expect(dispatcher.payloads[4]['method'], 'pin');
    expect(dispatcher.payloads[4]['biometric_enabled'], true);
    expect(dispatcher.payloads[7]['reason'], 'failedOrCanceled');
    expect(dispatcher.payloads[8]['query_length'], 4);
    expect(dispatcher.payloads[9]['cta_id'], 'home_new_password');
    expect(dispatcher.payloads[9]['screen'], 'home');
  });
}
