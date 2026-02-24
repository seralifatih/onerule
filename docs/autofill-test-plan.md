# Android Autofill Test Plan

Version: 2026-02-24
Scope: OneRule Android AutofillService (API 26+) + Flutter sync bridge.

## Preconditions

1. Build with Autofill enabled (default in this repo).
2. Install on Android 8.0+ device/emulator.
3. Create/unlock vault and add at least 4 entries with URLs:
   - `https://accounts.google.com`
   - `https://facebook.com`
   - `https://instagram.com`
   - `https://reddit.com`
4. Confirm Home shows no "Autofill not enabled" card after setup.

## Automated Checks (CI-friendly)

1. `flutter test test/autofill_mvp_service_test.dart`
   - Validates feature-guard behavior and native bridge method wiring.
2. `flutter test test/credential_provider_test.dart`
   - Verifies encrypted snapshot sync and session clear behavior.

## Manual Verification Matrix

### 1) Setup wizard flow

1. Open Home.
2. Confirm persistent card appears: `Autofill not enabled for OneRule`.
3. Tap `Set up`.
4. In setup screen, tap `Open Autofill settings`.
5. Select `OneRule` as Autofill provider.
6. Return to app.
7. Confirm setup screen status switches to enabled.
8. Confirm Home card is hidden.

Expected: card remains visible until provider is enabled, then disappears.

### 2) Chrome (web domain heuristic)

1. Open Chrome and navigate to `https://accounts.google.com`.
2. Tap username field, then password field.
3. Select OneRule suggestion dataset.

Expected:
- Dataset appears for Google-domain credential.
- Username/password fill correctly.
- No plaintext values appear in app logs.

### 3) Facebook app (package/domain heuristic)

1. Open Facebook app login screen.
2. Focus username/password fields.
3. Select suggested OneRule credential.

Expected:
- Suggestion appears from package/domain mapping.
- Correct credential fills both fields.

### 4) Instagram app

1. Open Instagram login screen.
2. Focus login fields.
3. Select suggested OneRule credential.

Expected:
- Suggestion appears.
- Fill succeeds for username/password.

### 5) Reddit app

1. Open Reddit login screen.
2. Focus login fields.
3. Select suggested OneRule credential.

Expected:
- Suggestion appears.
- Fill succeeds.

## Negative / Security Validation

### A) Vault locked / no session key

1. Force app lock (logout or auto-lock timeout).
2. Open any login form in supported app.

Expected:
- No OneRule suggestion returned (service has no session key).

### B) Tamper detection

1. Corrupt encrypted autofill snapshot in native secure store (dev/debug path).
2. Trigger autofill request.

Expected:
- Autofill hard-fails with authentication/decryption failure.
- No partial plaintext fill is returned.

### C) Wrong PIN

1. Enter wrong PIN in OneRule.
2. Trigger autofill request from Chrome/app.

Expected:
- Session key is not set.
- No credential suggestions.

## Logging Expectations

- Allowed logs: request context metadata (package, domain, counts), non-sensitive errors.
- Forbidden logs: plaintext usernames/passwords, decrypted content, ciphertext blobs, session keys.
