// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'OneRule Tresor';

  @override
  String get settings => 'Einstellungen';

  @override
  String get appearance => 'Aussehen';

  @override
  String get auto => 'Auto';

  @override
  String get light => 'Hell';

  @override
  String get dark => 'Dunkel';

  @override
  String get changeMasterPin => 'Master-PIN ändern';

  @override
  String get biometricLogin => 'Biometrischer Login';

  @override
  String get setPanicPin => 'Panik-PIN setzen';

  @override
  String get dataManagement => 'Datenverwaltung';

  @override
  String get exportPasswords => 'Passwörter exportieren';

  @override
  String get importPasswords => 'Passwörter importieren';

  @override
  String get deleteAllData => 'Alle Daten löschen';

  @override
  String get logout => 'ABMELDEN';

  @override
  String get language => 'Sprache';

  @override
  String get english => 'Englisch';

  @override
  String get turkish => 'Türkisch';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get delete => 'Löschen';

  @override
  String get save => 'Speichern';

  @override
  String get verify => 'Überprüfen';

  @override
  String get enterPin => 'PIN eingeben';

  @override
  String get addNewPassword => 'Neues Passwort hinzufügen';

  @override
  String get editPassword => 'Passwort bearbeiten';

  @override
  String get categoryLabel => 'Kategorie';

  @override
  String get platformTitleLabel => 'Plattform / Titel';

  @override
  String get titleRequired => 'Titel ist erforderlich';

  @override
  String get usernameEmailLabel => 'Benutzername / E-Mail';

  @override
  String get usernameRequired => 'Benutzername ist erforderlich';

  @override
  String get passwordLabel => 'Passwort';

  @override
  String get passwordRequired => 'Passwort ist erforderlich';

  @override
  String get generatePasswordTooltip => 'Passwort generieren';

  @override
  String get update => 'AKTUALISIEREN';

  @override
  String get saveAction => 'SPEICHERN';

  @override
  String get generatePasswordTitle => 'Passwort generieren';

  @override
  String get selectOptions => 'Mindestens eine Option wählen';

  @override
  String get lengthLabel => 'Länge: ';

  @override
  String get uppercaseOption => 'Großbuchstaben (A-Z)';

  @override
  String get lowercaseOption => 'Kleinbuchstaben (a-z)';

  @override
  String get numbersOption => 'Zahlen (0-9)';

  @override
  String get symbolsOption => 'Symbole (!@#)';

  @override
  String get refresh => 'Aktualisieren';

  @override
  String get use => 'VERWENDEN';

  @override
  String get categoryGeneral => 'Allgemein';

  @override
  String get categorySocial => 'Sozial';

  @override
  String get categoryWork => 'Arbeit';

  @override
  String get categoryFinance => 'Finanzen';

  @override
  String get categoryShopping => 'Einkaufen';

  @override
  String get categoryOther => 'Andere';

  @override
  String get categoryAll => 'Alle';

  @override
  String get myVaultTitle => 'Mein Tresor';

  @override
  String get searchPasswordsHint => 'Passwörter suchen...';

  @override
  String get noPasswordsFound => 'Keine Passwörter gefunden.';

  @override
  String get newPassword => 'Neues Passwort';

  @override
  String get deletePasswordTitle => 'Passwort löschen?';

  @override
  String get deletePasswordMessage =>
      'Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get passwordDeleted => 'Passwort gelöscht.';

  @override
  String copiedPassword(Object title) {
    return '$title-Passwort kopiert!';
  }

  @override
  String get pinMinLength => 'PIN muss mindestens 4 Ziffern haben';

  @override
  String get incorrectPin => 'Falsche PIN!';

  @override
  String get createMasterPinTitle => 'Master-PIN erstellen';

  @override
  String get createMasterPinSubtitle =>
      'Sichere deine Daten mit einer Master-PIN.';

  @override
  String get enterPinToDecrypt => 'PIN eingeben, um Daten zu entschlüsseln.';

  @override
  String get setMasterPinAction => 'MASTER-PIN FESTLEGEN';

  @override
  String get unlockVault => 'TRESOR ÖFFNEN';

  @override
  String get tapToUseBiometrics => 'Tippen, um Biometrie zu verwenden';

  @override
  String get verifyCurrentPinDescription =>
      'Bitte geben Sie Ihre aktuelle PIN ein, um fortzufahren.';

  @override
  String get wrongPin => 'Falsche PIN!';

  @override
  String get setNewPinTitle => 'Neue PIN festlegen';

  @override
  String get setNewPinDescription => 'Geben Sie Ihre neue Master-PIN ein.';

  @override
  String get pinChangeSuccess => 'PIN aktualisiert.';

  @override
  String get pinChangeFailed =>
      'PIN-Änderung fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get enterPanicPin => 'Panik-PIN eingeben';

  @override
  String get panicPinSameAsMaster =>
      'Darf nicht mit der Master-PIN identisch sein';

  @override
  String get panicPinSet => 'Panik-PIN gesetzt.';

  @override
  String get biometricAvailable => 'Fingerabdruck / Face ID verwenden';

  @override
  String get biometricUnavailable => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get deleteAllTitle => 'Sind Sie sicher?';

  @override
  String get deleteAllDescription =>
      'Alle gespeicherten Passwörter werden dauerhaft gelöscht.';

  @override
  String get allPasswordsDeleted =>
      'Alle Passwörter wurden dauerhaft gelöscht.';

  @override
  String get germanShort => 'DE';

  @override
  String get noPasswordsToExport => 'Keine Passwörter zum Exportieren.';

  @override
  String get backupShareText => 'OneRule-Passwort-Backup';

  @override
  String get saveBackupFileTitle => 'Backup-Datei speichern';

  @override
  String get backupSavedToDevice => 'Backup auf dem Gerät gespeichert.';

  @override
  String exportFailed(Object error) {
    return 'Export fehlgeschlagen: $error';
  }

  @override
  String passwordsImported(Object count) {
    return '$count Passwörter erfolgreich importiert.';
  }

  @override
  String get importFailed =>
      'Import fehlgeschlagen. Bitte wählen Sie eine gültige Backup-Datei.';

  @override
  String get importFailedInvalidOrPassword =>
      'Backup ungültig oder falsches Passwort.';

  @override
  String get backupPassphraseTitle => 'Backup-Passwort';

  @override
  String get backupPassphraseHint => 'Backup-Passwort eingeben';

  @override
  String get backupPassphraseConfirmHint => 'Backup-Passwort erneut eingeben';

  @override
  String get backupPassphraseMismatch => 'Passwörter stimmen nicht überein.';

  @override
  String get backupPassphraseEmpty => 'Passwort darf nicht leer sein.';

  @override
  String get legacyImportWarningTitle => 'Legacy-JSON-Import';

  @override
  String get legacyImportWarningBody =>
      'Dieses JSON-Backup ist unverschlüsselt. Beim Import können Passwörter anderen Apps oder Diensten zugänglich werden. Fahren Sie nur fort, wenn Sie der Datei und der Umgebung vertrauen.';

  @override
  String get legacyImportConfirm => 'Trotzdem importieren';

  @override
  String get clipboardWillClear =>
      'Zwischenablage wird in 30 Sekunden gelöscht.';

  @override
  String get confirm => 'Bestätigen';

  @override
  String get initErrorTitle => 'Initialisierung fehlgeschlagen';

  @override
  String get initErrorBody =>
      'Der Tresor konnte nicht entsperrt werden. Sie können es erneut versuchen oder zum Login wechseln.';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get goToLogin => 'Zum Login';

  @override
  String get biometricPrompt =>
      'Bitte bestätigen Sie Ihre Identität zur Anmeldung';
}
