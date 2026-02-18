# OneRule P0 Regression Checklist

Use this checklist for closed-testing regression passes before release candidates.

## Test Environment
- Device A: Android (gesture navigation enabled)
- Device B: Android (3-button navigation enabled)
- Biometric enrolled on at least one test device
- Build: latest debug/release-candidate build

## Manual Checklist

### 1) Category edit reflects immediately on Home
- Precondition: At least one vault item exists in `General`.
- Steps:
1. Open Home.
2. Tap an entry to edit.
3. Change category to `Social`.
4. Save update.
5. Return/observe Home list.
- Expected:
1. Item category chip updates to `SOCIAL` without app restart.
2. Old category chip `GENERAL` is not shown for that item.
3. No duplicate stale row appears.

### 2) Delete-all reflects immediately on Home
- Precondition: At least one vault item exists.
- Steps:
1. Open Settings.
2. Tap `Delete all data`.
3. Confirm deletion in dialog.
4. Navigate back to Home.
- Expected:
1. Home shows empty state immediately.
2. No old items remain after returning from Settings.
3. No manual refresh required.

### 3) Biometric success does not request PIN
- Precondition: Biometric login enabled, biometric available, master PIN already set.
- Steps:
1. Launch app on locked state.
2. Accept biometric prompt with successful biometric auth.
- Expected:
1. User is unlocked directly.
2. PIN input is not shown after biometric success.
3. PIN fallback appears only if biometric fails, is canceled, or unavailable.

### 4) Search text visibility in Light and Dark themes
- Precondition: Theme switch available in Settings.
- Steps:
1. Open Home in Light mode.
2. Type a sample query in search bar.
3. Switch to Dark mode.
4. Type a sample query again.
- Expected:
1. Typed text remains clearly visible in both themes.
2. Hint text stays distinguishable from typed text.
3. Cursor remains visible in both themes.

### 5) Bottom CTA not covered by system navigation
- Precondition: Test on gesture-nav and 3-button-nav devices.
- Steps:
1. Open Home and Add Password sheet.
2. Observe primary save CTA with keyboard closed.
3. Focus text field to open keyboard and observe CTA again.
- Expected:
1. CTA is fully visible and tappable with keyboard closed.
2. CTA moves above keyboard when keyboard is open.
3. CTA is not obscured by system nav area on either nav mode.

## Optional Automation Smoke Coverage (Current)

| P0 Path | Automated Coverage | Test File |
|---|---|---|
| Category edit reflects immediately | Yes (widget) | `test/widget_test.dart` |
| Delete-all reflects immediately | Yes (widget) | `test/widget_test.dart` |
| Biometric success skips PIN; fallback shows PIN | Yes (widget) | `test/login_biometric_flow_test.dart` |
| Search visibility style tokens in light/dark | Yes (widget) | `test/home_search_style_test.dart` |
| CTA safe-area + keyboard inset behavior | Yes (widget) | `test/add_password_sheet_safe_area_test.dart` |

## Sign-off Template
- Build tested:
- Devices tested:
- Tester:
- Date:
- Result: Pass / Fail
- Notes / Defects:
