// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OneRule Vault';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get auto => 'Auto';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get changeMasterPin => 'Change Master PIN';

  @override
  String get biometricLogin => 'Biometric Login';

  @override
  String get setPanicPin => 'Set Panic PIN';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get backupRestoreTitle => 'Backup & Restore';

  @override
  String get backupRestoreDescription =>
      'Create encrypted backups and restore from a backup file.';

  @override
  String get createBackupCta => 'Create Backup';

  @override
  String get restoreFromBackupCta => 'Restore from Backup';

  @override
  String get backupLastUnknown => 'No backup yet';

  @override
  String get backupGuideTitle => 'Important before you continue';

  @override
  String get backupGuideStep1 =>
      'Create backups regularly and store them somewhere safe.';

  @override
  String get backupGuideStep2 =>
      'If you lose your PIN, your vault cannot be recovered.';

  @override
  String get backupGuideStep3 =>
      'Keep your backup passphrase separate from your device.';

  @override
  String get backupGuideStep4 =>
      'Restoring merges imported items into your current vault.';

  @override
  String get exportDebugLogTitle => 'Export debug log';

  @override
  String get exportDebugLogWarning =>
      'Log may include stack traces but should not include passwords.';

  @override
  String get crashReportsSectionTitle => 'Crash reports';

  @override
  String get shareCrashReportsTitle => 'Share crash reports';

  @override
  String get shareCrashReportsSubtitle =>
      'If enabled, you can manually export local logs. Reports are never auto-sent.';

  @override
  String get shareCrashReportsDisabled =>
      'Enable \"Share crash reports\" in Settings before exporting logs.';

  @override
  String get viewLogsTitle => 'View logs';

  @override
  String get viewLogsEmpty => 'No logs available yet.';

  @override
  String get copyLogsAction => 'Copy logs';

  @override
  String get logsCopied => 'Logs copied to clipboard.';

  @override
  String get debugLogEmpty => 'No debug log available yet.';

  @override
  String get debugLogExportFailed => 'Failed to export debug log.';

  @override
  String get exportPasswords => 'Export Passwords';

  @override
  String get importPasswords => 'Import Passwords';

  @override
  String get deleteAllData => 'Delete All Data';

  @override
  String get logout => 'LOGOUT';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get turkish => 'Turkish';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get save => 'Save';

  @override
  String get verify => 'Verify';

  @override
  String get enterPin => 'Enter PIN';

  @override
  String get addNewPassword => 'Add New Password';

  @override
  String get editPassword => 'Edit Password';

  @override
  String get categoryLabel => 'Category';

  @override
  String get platformTitleLabel => 'Platform / Title';

  @override
  String get titleRequired => 'Title is required';

  @override
  String get usernameEmailLabel => 'Username / Email';

  @override
  String get usernameRequired => 'Username is required';

  @override
  String get passwordLabel => 'Password';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get generatePasswordTooltip => 'Generate Password';

  @override
  String get update => 'UPDATE';

  @override
  String get saveAction => 'SAVE';

  @override
  String get generatePasswordTitle => 'Generate Password';

  @override
  String get selectOptions => 'Select at least one option';

  @override
  String get lengthLabel => 'Length: ';

  @override
  String get uppercaseOption => 'Uppercase (A-Z)';

  @override
  String get lowercaseOption => 'Lowercase (a-z)';

  @override
  String get numbersOption => 'Numbers (0-9)';

  @override
  String get symbolsOption => 'Symbols (!@#)';

  @override
  String get refresh => 'Refresh';

  @override
  String get use => 'USE';

  @override
  String get categoryGeneral => 'General';

  @override
  String get categorySocial => 'Social';

  @override
  String get categoryWork => 'Work';

  @override
  String get categoryFinance => 'Finance';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categoryOther => 'Other';

  @override
  String get categoryAll => 'All';

  @override
  String get myVaultTitle => 'My Vault';

  @override
  String get searchPasswordsHint => 'Search passwords...';

  @override
  String get noPasswordsFound => 'No passwords found.';

  @override
  String get newPassword => 'New Password';

  @override
  String get deletePasswordTitle => 'Delete Password?';

  @override
  String get deletePasswordMessage => 'This action cannot be undone.';

  @override
  String get passwordDeleted => 'Password deleted.';

  @override
  String copiedPassword(Object title) {
    return 'Copied $title password!';
  }

  @override
  String copiedUsername(Object title) {
    return 'Copied $title username!';
  }

  @override
  String get pinMinLength => 'PIN must be at least 4 digits';

  @override
  String get incorrectPin => 'Incorrect PIN!';

  @override
  String get createMasterPinTitle => 'Create Master PIN';

  @override
  String get createMasterPinSubtitle => 'Secure your data with a master PIN.';

  @override
  String get enterPinToDecrypt => 'Enter your PIN to decrypt data.';

  @override
  String get setMasterPinAction => 'SET MASTER PIN';

  @override
  String get unlockVault => 'UNLOCK VAULT';

  @override
  String get tapToUseBiometrics => 'Tap to use biometrics';

  @override
  String get verifyCurrentPinDescription =>
      'Please enter your current PIN to continue.';

  @override
  String get wrongPin => 'Wrong PIN!';

  @override
  String get setNewPinTitle => 'Set New PIN';

  @override
  String get setNewPinDescription => 'Enter your new master PIN.';

  @override
  String get pinChangeSuccess => 'PIN updated.';

  @override
  String get pinChangeFailed => 'PIN change failed. Try again.';

  @override
  String get enterPanicPin => 'Enter Panic PIN';

  @override
  String get panicPinSameAsMaster => 'Cannot be same as Master PIN';

  @override
  String get panicPinSet => 'Panic PIN set.';

  @override
  String get panicPinInfoTitle => 'Before enabling Panic PIN';

  @override
  String get panicPinInfoWhatItDoes =>
      'Panic PIN unlocks an alternate emergency flow.';

  @override
  String get panicPinInfoDecoyVault =>
      'It shows a decoy vault instead of your real vault.';

  @override
  String get panicPinInfoRisk =>
      'If used by mistake, you may think your data is missing.';

  @override
  String get panicPinConfirmLabel =>
      'I understand this creates a decoy vault flow.';

  @override
  String get panicPinConfirmRequired =>
      'Please confirm that you understand before saving.';

  @override
  String get privacyModeHelperText =>
      'Privacy mode shows an empty vault until main PIN unlock.';

  @override
  String get biometricAvailable => 'Use Fingerprint / Face ID';

  @override
  String get biometricUnavailable => 'Not available on this device';

  @override
  String get deleteAllTitle => 'Are you sure?';

  @override
  String get deleteAllDescription =>
      'This will permanently delete all your saved passwords.';

  @override
  String get allPasswordsDeleted => 'All passwords deleted permanently.';

  @override
  String get germanShort => 'DE';

  @override
  String get noPasswordsToExport => 'No passwords to export.';

  @override
  String get backupShareText => 'OneRule password backup';

  @override
  String get saveBackupFileTitle => 'Save backup file';

  @override
  String get backupSavedToDevice => 'Backup saved to device.';

  @override
  String backupLastTimestamp(Object timestamp) {
    return 'Last backup: $timestamp';
  }

  @override
  String exportFailed(Object error) {
    return 'Export failed: $error';
  }

  @override
  String passwordsImported(Object count) {
    return '$count passwords imported successfully.';
  }

  @override
  String get importFailed =>
      'Import failed. Please select a valid backup file.';

  @override
  String get importFailedInvalidOrPassword =>
      'Invalid backup or wrong password.';

  @override
  String get backupPassphraseTitle => 'Backup password';

  @override
  String get backupPassphraseHint => 'Enter backup password';

  @override
  String get backupPassphraseConfirmHint => 'Re-enter backup password';

  @override
  String get backupPassphraseMismatch => 'Passwords do not match.';

  @override
  String get backupPassphraseEmpty => 'Password cannot be empty.';

  @override
  String get legacyImportWarningTitle => 'Legacy JSON import';

  @override
  String get legacyImportWarningBody =>
      'This JSON backup is unencrypted. Importing it may expose your passwords to other apps or services. Continue only if you trust the file and environment.';

  @override
  String get legacyImportConfirm => 'Import anyway';

  @override
  String get clipboardWillClear => 'Clipboard will clear in 30 seconds.';

  @override
  String get vaultLabel => 'Vault';

  @override
  String get privacyModeLabel => 'Privacy mode';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get usernameCopied => 'Username copied';

  @override
  String get autoLockTitle => 'Auto-lock';

  @override
  String get clipboardSectionTitle => 'Clipboard';

  @override
  String get clearClipboardAfterTitle => 'Clear clipboard after';

  @override
  String get alsoClearUsernameCopiesTitle => 'Also clear username/email copies';

  @override
  String get offLabel => 'Off';

  @override
  String get passwordRevealControlLabel => 'Password visibility';

  @override
  String get passwordRevealHoldHint => 'Press and hold to reveal password';

  @override
  String get passwordRevealHoldTooltip => 'Hold to reveal';

  @override
  String get passwordRevealReleaseTooltip => 'Release to hide';

  @override
  String get clearSearchFiltersLabel => 'Clear search and filters';

  @override
  String get enableClipboardAutoClearFirstHint =>
      'Enable clipboard auto-clear first';

  @override
  String secondsShort(int seconds) {
    return '$seconds sec';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes min';
  }

  @override
  String get confirm => 'Confirm';

  @override
  String get initErrorTitle => 'Initialization failed';

  @override
  String get initErrorBody =>
      'We couldn\'t unlock your vault. You can retry or go to the login screen.';

  @override
  String get retry => 'Retry';

  @override
  String get goToLogin => 'Go to Login';

  @override
  String get biometricPrompt => 'Verify your identity to sign in';

  @override
  String get usePinToFinishUnlocking => 'Use PIN to finish unlocking.';
}
