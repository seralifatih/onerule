# Android Release Checklist

Use this checklist to prevent mixed-artifact installs (engine/snapshot mismatch) and startup crashes.

## Preconditions

- Phone connected with USB debugging enabled
- USB mode set to data transfer (`File transfer/MTP`)
- `adb devices` shows the target as `device` (not `unauthorized`)

## Deterministic Validation (Windows PowerShell)

Run from repo root:

```powershell
.\scripts\android-release-validate.ps1
```

Optional flags:

```powershell
.\scripts\android-release-validate.ps1 -DeviceId RFCW91R2JTY
.\scripts\android-release-validate.ps1 -NoUninstall
.\scripts\android-release-validate.ps1 -NoBuild
```

What this script enforces:

1. `flutter clean`
2. `flutter pub get`
3. `flutter build apk --release`
4. `adb uninstall` (optional) + `adb install -r`
5. App launch via `monkey`
6. Crash-buffer scan for fatal startup indicators
7. PID check to confirm process is alive

## Manual Fallback Commands

```powershell
flutter clean
flutter pub get
flutter build apk --release
adb uninstall com.fidevelopment.onerule
adb install build\app\outputs\flutter-apk\app-release.apk
adb logcat -c
adb shell monkey -p com.fidevelopment.onerule -c android.intent.category.LAUNCHER 1
adb logcat -b crash -d
```
