import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('tr')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'OneRule Vault'**
  String get appTitle;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @auto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get auto;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @changeMasterPin.
  ///
  /// In en, this message translates to:
  /// **'Change Master PIN'**
  String get changeMasterPin;

  /// No description provided for @biometricLogin.
  ///
  /// In en, this message translates to:
  /// **'Biometric Login'**
  String get biometricLogin;

  /// No description provided for @setPanicPin.
  ///
  /// In en, this message translates to:
  /// **'Set Panic PIN'**
  String get setPanicPin;

  /// No description provided for @dataManagement.
  ///
  /// In en, this message translates to:
  /// **'Data Management'**
  String get dataManagement;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Create encrypted backups and restore from a backup file.'**
  String get backupRestoreDescription;

  /// No description provided for @createBackupCta.
  ///
  /// In en, this message translates to:
  /// **'Create Backup'**
  String get createBackupCta;

  /// No description provided for @restoreFromBackupCta.
  ///
  /// In en, this message translates to:
  /// **'Restore from Backup'**
  String get restoreFromBackupCta;

  /// No description provided for @backupLastUnknown.
  ///
  /// In en, this message translates to:
  /// **'No backup yet'**
  String get backupLastUnknown;

  /// No description provided for @backupGuideTitle.
  ///
  /// In en, this message translates to:
  /// **'Important before you continue'**
  String get backupGuideTitle;

  /// No description provided for @backupGuideStep1.
  ///
  /// In en, this message translates to:
  /// **'Create backups regularly and store them somewhere safe.'**
  String get backupGuideStep1;

  /// No description provided for @backupGuideStep2.
  ///
  /// In en, this message translates to:
  /// **'If you lose your PIN, your vault cannot be recovered.'**
  String get backupGuideStep2;

  /// No description provided for @backupGuideStep3.
  ///
  /// In en, this message translates to:
  /// **'Keep your backup passphrase separate from your device.'**
  String get backupGuideStep3;

  /// No description provided for @backupGuideStep4.
  ///
  /// In en, this message translates to:
  /// **'Restoring merges imported items into your current vault.'**
  String get backupGuideStep4;

  /// No description provided for @exportDebugLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Export debug log'**
  String get exportDebugLogTitle;

  /// No description provided for @exportDebugLogWarning.
  ///
  /// In en, this message translates to:
  /// **'Log may include stack traces but should not include passwords.'**
  String get exportDebugLogWarning;

  /// No description provided for @debugLogEmpty.
  ///
  /// In en, this message translates to:
  /// **'No debug log available yet.'**
  String get debugLogEmpty;

  /// No description provided for @debugLogExportFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to export debug log.'**
  String get debugLogExportFailed;

  /// No description provided for @exportPasswords.
  ///
  /// In en, this message translates to:
  /// **'Export Passwords'**
  String get exportPasswords;

  /// No description provided for @importPasswords.
  ///
  /// In en, this message translates to:
  /// **'Import Passwords'**
  String get importPasswords;

  /// No description provided for @deleteAllData.
  ///
  /// In en, this message translates to:
  /// **'Delete All Data'**
  String get deleteAllData;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'LOGOUT'**
  String get logout;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @verify.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verify;

  /// No description provided for @enterPin.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get enterPin;

  /// No description provided for @addNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Add New Password'**
  String get addNewPassword;

  /// No description provided for @editPassword.
  ///
  /// In en, this message translates to:
  /// **'Edit Password'**
  String get editPassword;

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryLabel;

  /// No description provided for @platformTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Platform / Title'**
  String get platformTitleLabel;

  /// No description provided for @titleRequired.
  ///
  /// In en, this message translates to:
  /// **'Title is required'**
  String get titleRequired;

  /// No description provided for @usernameEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Username / Email'**
  String get usernameEmailLabel;

  /// No description provided for @usernameRequired.
  ///
  /// In en, this message translates to:
  /// **'Username is required'**
  String get usernameRequired;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @generatePasswordTooltip.
  ///
  /// In en, this message translates to:
  /// **'Generate Password'**
  String get generatePasswordTooltip;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'UPDATE'**
  String get update;

  /// No description provided for @saveAction.
  ///
  /// In en, this message translates to:
  /// **'SAVE'**
  String get saveAction;

  /// No description provided for @generatePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate Password'**
  String get generatePasswordTitle;

  /// No description provided for @selectOptions.
  ///
  /// In en, this message translates to:
  /// **'Select at least one option'**
  String get selectOptions;

  /// No description provided for @lengthLabel.
  ///
  /// In en, this message translates to:
  /// **'Length: '**
  String get lengthLabel;

  /// No description provided for @uppercaseOption.
  ///
  /// In en, this message translates to:
  /// **'Uppercase (A-Z)'**
  String get uppercaseOption;

  /// No description provided for @lowercaseOption.
  ///
  /// In en, this message translates to:
  /// **'Lowercase (a-z)'**
  String get lowercaseOption;

  /// No description provided for @numbersOption.
  ///
  /// In en, this message translates to:
  /// **'Numbers (0-9)'**
  String get numbersOption;

  /// No description provided for @symbolsOption.
  ///
  /// In en, this message translates to:
  /// **'Symbols (!@#)'**
  String get symbolsOption;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @use.
  ///
  /// In en, this message translates to:
  /// **'USE'**
  String get use;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @categorySocial.
  ///
  /// In en, this message translates to:
  /// **'Social'**
  String get categorySocial;

  /// No description provided for @categoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryWork;

  /// No description provided for @categoryFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get categoryFinance;

  /// No description provided for @categoryShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get categoryShopping;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @myVaultTitle.
  ///
  /// In en, this message translates to:
  /// **'My Vault'**
  String get myVaultTitle;

  /// No description provided for @searchPasswordsHint.
  ///
  /// In en, this message translates to:
  /// **'Search passwords...'**
  String get searchPasswordsHint;

  /// No description provided for @noPasswordsFound.
  ///
  /// In en, this message translates to:
  /// **'No passwords found.'**
  String get noPasswordsFound;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @deletePasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Password?'**
  String get deletePasswordTitle;

  /// No description provided for @deletePasswordMessage.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get deletePasswordMessage;

  /// No description provided for @passwordDeleted.
  ///
  /// In en, this message translates to:
  /// **'Password deleted.'**
  String get passwordDeleted;

  /// No description provided for @copiedPassword.
  ///
  /// In en, this message translates to:
  /// **'Copied {title} password!'**
  String copiedPassword(Object title);

  /// No description provided for @copiedUsername.
  ///
  /// In en, this message translates to:
  /// **'Copied {title} username!'**
  String copiedUsername(Object title);

  /// No description provided for @pinMinLength.
  ///
  /// In en, this message translates to:
  /// **'PIN must be at least 4 digits'**
  String get pinMinLength;

  /// No description provided for @incorrectPin.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN!'**
  String get incorrectPin;

  /// No description provided for @createMasterPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Master PIN'**
  String get createMasterPinTitle;

  /// No description provided for @createMasterPinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secure your data with a master PIN.'**
  String get createMasterPinSubtitle;

  /// No description provided for @enterPinToDecrypt.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to decrypt data.'**
  String get enterPinToDecrypt;

  /// No description provided for @setMasterPinAction.
  ///
  /// In en, this message translates to:
  /// **'SET MASTER PIN'**
  String get setMasterPinAction;

  /// No description provided for @unlockVault.
  ///
  /// In en, this message translates to:
  /// **'UNLOCK VAULT'**
  String get unlockVault;

  /// No description provided for @tapToUseBiometrics.
  ///
  /// In en, this message translates to:
  /// **'Tap to use biometrics'**
  String get tapToUseBiometrics;

  /// No description provided for @verifyCurrentPinDescription.
  ///
  /// In en, this message translates to:
  /// **'Please enter your current PIN to continue.'**
  String get verifyCurrentPinDescription;

  /// No description provided for @wrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN!'**
  String get wrongPin;

  /// No description provided for @setNewPinTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New PIN'**
  String get setNewPinTitle;

  /// No description provided for @setNewPinDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your new master PIN.'**
  String get setNewPinDescription;

  /// No description provided for @pinChangeSuccess.
  ///
  /// In en, this message translates to:
  /// **'PIN updated.'**
  String get pinChangeSuccess;

  /// No description provided for @pinChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'PIN change failed. Try again.'**
  String get pinChangeFailed;

  /// No description provided for @enterPanicPin.
  ///
  /// In en, this message translates to:
  /// **'Enter Panic PIN'**
  String get enterPanicPin;

  /// No description provided for @panicPinSameAsMaster.
  ///
  /// In en, this message translates to:
  /// **'Cannot be same as Master PIN'**
  String get panicPinSameAsMaster;

  /// No description provided for @panicPinSet.
  ///
  /// In en, this message translates to:
  /// **'Panic PIN set.'**
  String get panicPinSet;

  /// No description provided for @panicPinInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Before enabling Panic PIN'**
  String get panicPinInfoTitle;

  /// No description provided for @panicPinInfoWhatItDoes.
  ///
  /// In en, this message translates to:
  /// **'Panic PIN unlocks an alternate emergency flow.'**
  String get panicPinInfoWhatItDoes;

  /// No description provided for @panicPinInfoDecoyVault.
  ///
  /// In en, this message translates to:
  /// **'It shows a decoy vault instead of your real vault.'**
  String get panicPinInfoDecoyVault;

  /// No description provided for @panicPinInfoRisk.
  ///
  /// In en, this message translates to:
  /// **'If used by mistake, you may think your data is missing.'**
  String get panicPinInfoRisk;

  /// No description provided for @panicPinConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'I understand this creates a decoy vault flow.'**
  String get panicPinConfirmLabel;

  /// No description provided for @panicPinConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm that you understand before saving.'**
  String get panicPinConfirmRequired;

  /// No description provided for @privacyModeHelperText.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode shows an empty vault until main PIN unlock.'**
  String get privacyModeHelperText;

  /// No description provided for @biometricAvailable.
  ///
  /// In en, this message translates to:
  /// **'Use Fingerprint / Face ID'**
  String get biometricAvailable;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get biometricUnavailable;

  /// No description provided for @deleteAllTitle.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get deleteAllTitle;

  /// No description provided for @deleteAllDescription.
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete all your saved passwords.'**
  String get deleteAllDescription;

  /// No description provided for @allPasswordsDeleted.
  ///
  /// In en, this message translates to:
  /// **'All passwords deleted permanently.'**
  String get allPasswordsDeleted;

  /// No description provided for @germanShort.
  ///
  /// In en, this message translates to:
  /// **'DE'**
  String get germanShort;

  /// No description provided for @noPasswordsToExport.
  ///
  /// In en, this message translates to:
  /// **'No passwords to export.'**
  String get noPasswordsToExport;

  /// No description provided for @backupShareText.
  ///
  /// In en, this message translates to:
  /// **'OneRule password backup'**
  String get backupShareText;

  /// No description provided for @saveBackupFileTitle.
  ///
  /// In en, this message translates to:
  /// **'Save backup file'**
  String get saveBackupFileTitle;

  /// No description provided for @backupSavedToDevice.
  ///
  /// In en, this message translates to:
  /// **'Backup saved to device.'**
  String get backupSavedToDevice;

  /// No description provided for @backupLastTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {timestamp}'**
  String backupLastTimestamp(Object timestamp);

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(Object error);

  /// No description provided for @passwordsImported.
  ///
  /// In en, this message translates to:
  /// **'{count} passwords imported successfully.'**
  String passwordsImported(Object count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed. Please select a valid backup file.'**
  String get importFailed;

  /// No description provided for @importFailedInvalidOrPassword.
  ///
  /// In en, this message translates to:
  /// **'Invalid backup or wrong password.'**
  String get importFailedInvalidOrPassword;

  /// No description provided for @backupPassphraseTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPassphraseTitle;

  /// No description provided for @backupPassphraseHint.
  ///
  /// In en, this message translates to:
  /// **'Enter backup password'**
  String get backupPassphraseHint;

  /// No description provided for @backupPassphraseConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Re-enter backup password'**
  String get backupPassphraseConfirmHint;

  /// No description provided for @backupPassphraseMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get backupPassphraseMismatch;

  /// No description provided for @backupPassphraseEmpty.
  ///
  /// In en, this message translates to:
  /// **'Password cannot be empty.'**
  String get backupPassphraseEmpty;

  /// No description provided for @legacyImportWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Legacy JSON import'**
  String get legacyImportWarningTitle;

  /// No description provided for @legacyImportWarningBody.
  ///
  /// In en, this message translates to:
  /// **'This JSON backup is unencrypted. Importing it may expose your passwords to other apps or services. Continue only if you trust the file and environment.'**
  String get legacyImportWarningBody;

  /// No description provided for @legacyImportConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import anyway'**
  String get legacyImportConfirm;

  /// No description provided for @clipboardWillClear.
  ///
  /// In en, this message translates to:
  /// **'Clipboard will clear in 30 seconds.'**
  String get clipboardWillClear;

  /// No description provided for @vaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get vaultLabel;

  /// No description provided for @privacyModeLabel.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get privacyModeLabel;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @usernameCopied.
  ///
  /// In en, this message translates to:
  /// **'Username copied'**
  String get usernameCopied;

  /// No description provided for @autoLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get autoLockTitle;

  /// No description provided for @clipboardSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Clipboard'**
  String get clipboardSectionTitle;

  /// No description provided for @clearClipboardAfterTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear clipboard after'**
  String get clearClipboardAfterTitle;

  /// No description provided for @alsoClearUsernameCopiesTitle.
  ///
  /// In en, this message translates to:
  /// **'Also clear username/email copies'**
  String get alsoClearUsernameCopiesTitle;

  /// No description provided for @offLabel.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get offLabel;

  /// No description provided for @passwordRevealControlLabel.
  ///
  /// In en, this message translates to:
  /// **'Password visibility'**
  String get passwordRevealControlLabel;

  /// No description provided for @passwordRevealHoldHint.
  ///
  /// In en, this message translates to:
  /// **'Press and hold to reveal password'**
  String get passwordRevealHoldHint;

  /// No description provided for @passwordRevealHoldTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hold to reveal'**
  String get passwordRevealHoldTooltip;

  /// No description provided for @passwordRevealReleaseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Release to hide'**
  String get passwordRevealReleaseTooltip;

  /// No description provided for @clearSearchFiltersLabel.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters'**
  String get clearSearchFiltersLabel;

  /// No description provided for @enableClipboardAutoClearFirstHint.
  ///
  /// In en, this message translates to:
  /// **'Enable clipboard auto-clear first'**
  String get enableClipboardAutoClearFirstHint;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'{seconds} sec'**
  String secondsShort(int seconds);

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String minutesShort(int minutes);

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @initErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Initialization failed'**
  String get initErrorTitle;

  /// No description provided for @initErrorBody.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t unlock your vault. You can retry or go to the login screen.'**
  String get initErrorBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @goToLogin.
  ///
  /// In en, this message translates to:
  /// **'Go to Login'**
  String get goToLogin;

  /// No description provided for @biometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity to sign in'**
  String get biometricPrompt;

  /// No description provided for @usePinToFinishUnlocking.
  ///
  /// In en, this message translates to:
  /// **'Use PIN to finish unlocking.'**
  String get usePinToFinishUnlocking;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
