# QA Smoke Report - OneRule

Date: 2026-02-25
QA Owner: Senior Mobile QA + Release Validation (Codex run)
Scope: SQLCipher storage, crypto migrations, onboarding, UI changes, notifications, backup/restore, Buy Me a Coffee, privacy controls.

## Devices / Targets
- Android Emulator: `Pixel_7` AVD (Blocked: emulator failed to boot)
- Real Android Device: Not connected (`adb devices` empty)
- Additional runtime smoke target used: Windows desktop (`flutter run -d windows --no-resident`)

## Build Types Validated
- `flutter build apk --debug` -> PASS (`build/app/outputs/flutter-apk/app-debug.apk`)
- `flutter build apk --release` -> PASS (`build/app/outputs/flutter-apk/app-release.apk`)

## Baseline Command Results (Step 0)
- `flutter --version` -> PASS (`Flutter 3.38.7`, stable, Dart `3.10.7`)
- `flutter clean` -> PASS
- `flutter pub get` -> PASS
- `flutter analyze` -> PASS (no issues)
- `flutter test` -> PASS (all tests passed)

## Checklist by Requested Steps

### Step 1 - Build validation
- PASS: Debug APK build succeeds.
- PASS: Release APK build succeeds.
- Note: A parallel debug+release build attempt produced a Gradle race in `local_auth_android`; sequential builds are clean and reproducible.

### Step 2 - Runtime smoke (fresh install)
- Android fresh-install runtime: BLOCKED (no bootable Android target in this environment).
- Evidence from deterministic automated tests:
  - PASS: First-run onboarding + required messaging: [test/onboarding_flow_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/onboarding_flow_test.dart:103)
  - PASS: "I understand" checkbox gating: [test/onboarding_flow_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/onboarding_flow_test.dart:140)
  - PASS: Panic intro skip path: [test/onboarding_flow_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/onboarding_flow_test.dart:175)
  - PASS: Panic intro setup path: [test/onboarding_flow_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/onboarding_flow_test.dart:200)
  - PASS: Copy actions + countdown chip behavior: [test/home_copy_actions_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/home_copy_actions_test.dart:151)
  - PASS: Recently Used ordering/hide behavior: [test/home_recently_used_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/home_recently_used_test.dart:60)
  - PASS: Search field contrast (light/dark): [test/home_search_style_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/home_search_style_test.dart:102)

### Step 3 - Persistence & SQLCipher integrity
- PASS: Vault create/add/read round-trip: [test/crypto_storage_integration_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/crypto_storage_integration_test.dart:32)
- PASS: Wrong PIN denies read without partial leakage: [test/crypto_storage_integration_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/crypto_storage_integration_test.dart:58)
- PASS: Tamper detection hard-fails: [test/crypto_storage_integration_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/crypto_storage_integration_test.dart:95)
- PASS: Legacy CBC -> GCM migration works: [test/crypto_storage_integration_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/crypto_storage_integration_test.dart:145)
- PASS: No obvious sensitive debug logging found by grep (only migration lifecycle log line in DB service).

### Step 4 - Backup & Restore
- PASS: Encrypted backup round-trip and tamper handling: [test/backup_service_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/backup_service_test.dart:8)
- PASS: Filename format `OneRule_backup_YYYY_MM_DD.enc`: [test/backup_service_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/backup_service_test.dart:142)
- PASS: Wrong PIN error classification: [test/backup_service_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/backup_service_test.dart:150)
- PASS: Corrupt file error classification: [test/backup_service_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/backup_service_test.dart:184)
- PASS (code audit): backup writes use encrypted payload only in backup service write paths.
- BLOCKED: Android clear-app-data + restore manual loop could not be executed without Android runtime target.

### Step 5 - Notifications
- PASS (code audit): backup reminder permission handling exists on Android/iOS/macOS: [backup_reminder_service.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/services/backup_reminder_service.dart:237)
- PASS (code audit): single reminder id + scheduled flag logic prevents duplicate scheduling state drift: [backup_reminder_service.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/services/backup_reminder_service.dart:124)
- PASS (code audit): reminder can be disabled via settings toggle and `cancelReminder()`: [settings_screen.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/screens/settings_screen.dart:908)
- BLOCKED: Runtime notification delivery/permission prompts not executed on Android device/emulator.

### Step 6 - Panic Mode
- PASS: Onboarding panic skip/setup verified by widget tests.
- PASS: New deterministic integrity test confirms panic mode does not wipe persisted vault data: [test/panic_mode_integrity_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/panic_mode_integrity_test.dart:66)
- BLOCKED: Manual decoy PIN live flow on Android hardware not executed due unavailable Android runtime target.

### Step 7 - Buy Me a Coffee verification
- PASS (code audit): Support section present with link constant in one app location: [settings_screen.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/screens/settings_screen.dart:42)
- PASS (code audit): URL is correct and opens externally (`LaunchMode.externalApplication`): [settings_screen.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/screens/settings_screen.dart:86)
- PASS (code audit): offline/launch failure path handled with snackbar (no crash path): [settings_screen.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/screens/settings_screen.dart:89)
- PASS (code audit): no analytics call wired to support-link tap.
- BLOCKED: Manual offline-device tap validation not executed on Android runtime target.

### Step 8 - Crash logging & privacy audit
- PASS: Crash report opt-in default OFF: [security_settings_provider.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/providers/security_settings_provider.dart:15)
- PASS: Crash logs stored locally (application support directory), not uploaded automatically: [local_log_service.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/services/local_log_service.dart:121)
- PASS: Export requires opt-in toggle (`shareCrashReportsEnabled`): [local_log_service.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/services/local_log_service.dart:91)
- PASS: Redaction rules exist for secrets and entry fields: [local_log_service.dart](C:/Users/fatih/Desktop/Programming/onerule/lib/services/local_log_service.dart:180)
- PASS (code audit): no obvious secret-bearing debug prints found.

### Step 9 - UI regression sweep
- PASS: keyboard safe-area CTA coverage: [test/add_password_sheet_safe_area_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/add_password_sheet_safe_area_test.dart:1)
- PASS: dark/light search contrast tests pass.
- PASS: Windows runtime no-resident launch smoke successful.
- BLOCKED: Android small/large device manual visual sweep not possible (emulator unavailable).

## Bugs Found
1. **QA-BLOCKER-001 (Environment/CI setup blocker)**
   - Severity: High for release sign-off
   - Issue: Android emulator `Pixel_7` fails to boot.
   - Repro:
     1. Run `flutter emulators --launch Pixel_7`
     2. Emulator exits with code 1.
     3. Direct emulator run shows: `Broken AVD system path` / missing `system-images` for configured AVD.
   - Impact: Blocks required Android runtime smoke verification (fresh install, notifications, offline link behavior, decoy PIN live run).

2. **DOC-001 (Fixed in this QA pass)**
   - Severity: Low
   - Issue: Docs referenced backup extension `.onerule` while app behavior uses `.enc` naming.
   - Fix applied in this run.

## Files Changed in This QA Pass
- [docs/qa-smoke-report.md](C:/Users/fatih/Desktop/Programming/onerule/docs/qa-smoke-report.md)
- [test/panic_mode_integrity_test.dart](C:/Users/fatih/Desktop/Programming/onerule/test/panic_mode_integrity_test.dart)
- [README.md](C:/Users/fatih/Desktop/Programming/onerule/README.md)
- [security-architecture.md](C:/Users/fatih/Desktop/Programming/onerule/docs/security-architecture.md)

## Final Recommendation
**FIX BEFORE SHIP**

Reason: compile/build/tests are green, but Android runtime validation goals (fresh install, backup/restore on-device, notifications, offline external-link behavior, panic decoy live path) could not be fully executed because no usable Android runtime target was available in this environment. Release sign-off should wait until this matrix is rerun on:
- 1 Android emulator (bootable AVD), and
- 1 real Android device.
