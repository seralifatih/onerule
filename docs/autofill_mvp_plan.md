# OneRule Android Autofill MVP Plan

## Goal
Deliver a safe, non-breaking Android Autofill MVP scaffold for future full integration without exposing credentials insecurely.

## Scope (MVP Scaffold)
- Add Android Autofill service declaration and service class placeholders.
- Add Flutter-side service/bridge abstraction.
- Gate all incomplete flows behind feature flags (disabled by default).
- Document compliance, security, and UX constraints for production rollout.

## Out of Scope (for this scaffold)
- Real dataset generation from vault records.
- Domain/package trust matching logic.
- Inline suggestions UI and save flow UX.
- End-to-end autofill enrollment UI in Flutter.

---

## Architecture

### Android Components
1. `OneRuleAutofillService` (`AutofillService`)
   - Entry point for `FillRequest` and `SaveRequest`.
   - Current scaffold returns no credential data.
   - Contains TODOs for secure matching and unlock checks.
2. Service manifest + metadata XML
   - Declared in `AndroidManifest.xml`.
   - Bound with `android.permission.BIND_AUTOFILL_SERVICE`.
   - Backed by `@xml/onerule_autofill_service`.
3. `MainActivity` method channel endpoint (`onerule/autofill_mvp`)
   - `isPlatformAutofillSupported`
   - `isAutofillMvpEnabled`
   - `openAutofillSettings`

### Flutter Components
1. `AutofillFeatureFlag`
   - Compile/runtime guard from `ONERULE_AUTOFILL_MVP`.
2. `AutofillMvpService`
   - Typed availability states:
     - `disabledByFlag`
     - `unsupportedPlatform`
     - `nativeScaffoldDisabled`
     - `available`
   - Opens Android autofill settings only when available.
3. `AutofillMvpBridge`
   - Method-channel bridge abstraction for testability and future expansion.

---

## Data Flow (Target Full MVP)
1. User enables Autofill in OneRule settings and Android system settings.
2. Android target app requests autofill.
3. `OneRuleAutofillService.onFillRequest` receives AssistStructure.
4. Service extracts package/web domain hints.
5. Service asks trusted matcher for vault candidates.
6. If vault locked:
   - Require local user auth (biometric/PIN) before exposing datasets.
7. Return redacted label + credential dataset to Android Autofill framework.
8. Android fills target fields.

### Current Scaffold Behavior
- Steps 1-3 possible when feature flag enabled.
- Step 4+ intentionally not implemented.
- Service currently returns no usable fill data.

---

## Permissions, Disclosures, and Policy

### Android Permissions / Declarations
- `android.permission.BIND_AUTOFILL_SERVICE` on service declaration.
- No broad data/network permissions added for autofill.

### User Disclosures (required before production enablement)
- Explain what autofill reads (package/domain + field structure metadata).
- Explain when credentials can be suggested and filled.
- Explain local authentication requirements before showing sensitive data.
- Explain clipboard is not used for autofill transport.

### Play Store Policy Considerations
- Autofill service must be user-initiated and revocable in system settings.
- Avoid deceptive behavior and hidden background collection.
- Privacy policy must explicitly cover autofill processing and retention.
- Minimize data sent off-device; preferred design is fully offline on-device matching.

---

## Security Constraints (Non-Negotiable)
- Never log plaintext usernames/passwords.
- Never return datasets while vault is locked.
- Enforce package/domain trust checks before candidate selection.
- Require explicit user auth when risk level is high (first use/session timeout).
- Keep autofill matching and candidate generation offline unless a future design is approved.
- Disable feature by default until all threat controls are implemented.

---

## Feature Flag Strategy

### Guards
1. Flutter flag: `ONERULE_AUTOFILL_MVP` (default `false`).
2. Android native flag:
   - Gradle property: `oneruleAutofillMvpEnabled` (default `false`).
   - Wired to:
     - `BuildConfig.ONERULE_AUTOFILL_MVP`
     - manifest placeholder `oneRuleAutofillEnabled`.

### Result
- Incomplete autofill flows are not exposed by default.
- Enabling requires explicit build-time configuration.

---

## Open TODOs for Full Integration
- AssistStructure parser and field heuristics.
- Trusted app/domain matching engine.
- Unlock/session broker usable from AutofillService context.
- Secure RemoteViews/inline suggestion UX.
- SaveRequest secure create/update pipeline.
- Autofill-specific telemetry and abuse detection (non-sensitive).
- Settings UI + disclosure text + onboarding.

---

## Implementation Checklist with Effort Estimates
- [x] Feature flag scaffolding (Flutter + Android) — 2-3h
- [x] Android Autofill service placeholder + manifest — 2-4h
- [x] Flutter bridge/service scaffold — 2-3h
- [ ] AssistStructure parsing + field mapping — 1-2 days
- [ ] Trusted package/domain matching — 1-2 days
- [ ] Secure unlock orchestration in service context — 1-2 days
- [ ] Suggestion UI + dataset construction — 1-2 days
- [ ] SaveRequest secure flow — 1 day
- [ ] User disclosures + settings UX + localization — 0.5-1 day
- [ ] Security review + QA on OEM variations — 2-3 days
