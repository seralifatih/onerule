// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'OneRule Kasa';

  @override
  String get settings => 'Ayarlar';

  @override
  String get appearance => 'Görünüm';

  @override
  String get auto => 'Oto';

  @override
  String get light => 'Açık';

  @override
  String get dark => 'Koyu';

  @override
  String get changeMasterPin => 'Ana PIN\'i Değiştir';

  @override
  String get biometricLogin => 'Biyometrik Giriş';

  @override
  String get setPanicPin => 'Panik PIN Ayarla';

  @override
  String get dataManagement => 'Veri Yönetimi';

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
  String get exportDebugLogTitle => 'Hata gunlugunu disa aktar';

  @override
  String get exportDebugLogWarning =>
      'Gunluk yigin izleri icerebilir ancak sifreler yer almamalidir.';

  @override
  String get debugLogEmpty => 'Henuz disa aktarilacak bir hata gunlugu yok.';

  @override
  String get debugLogExportFailed => 'Hata gunlugu disa aktarma basarisiz.';

  @override
  String get exportPasswords => 'Şifreleri Dışa Aktar';

  @override
  String get importPasswords => 'Şifreleri İçe Aktar';

  @override
  String get deleteAllData => 'Tüm Verileri Sil';

  @override
  String get logout => 'ÇIKIŞ YAP';

  @override
  String get language => 'Dil';

  @override
  String get english => 'İngilizce';

  @override
  String get turkish => 'Türkçe';

  @override
  String get cancel => 'İptal';

  @override
  String get delete => 'Sil';

  @override
  String get save => 'Kaydet';

  @override
  String get verify => 'Doğrula';

  @override
  String get enterPin => 'PIN Giriniz';

  @override
  String get addNewPassword => 'Yeni Şifre Ekle';

  @override
  String get editPassword => 'Şifre Düzenle';

  @override
  String get categoryLabel => 'Kategori';

  @override
  String get platformTitleLabel => 'Platform / Başlık';

  @override
  String get titleRequired => 'Başlık zorunludur';

  @override
  String get usernameEmailLabel => 'Kullanıcı adı / E-posta';

  @override
  String get usernameRequired => 'Kullanıcı adı zorunludur';

  @override
  String get passwordLabel => 'Şifre';

  @override
  String get passwordRequired => 'Şifre zorunludur';

  @override
  String get generatePasswordTooltip => 'Şifre Oluştur';

  @override
  String get update => 'GÜNCELLE';

  @override
  String get saveAction => 'KAYDET';

  @override
  String get generatePasswordTitle => 'Şifre Oluştur';

  @override
  String get selectOptions => 'En az bir seçenek seçin';

  @override
  String get lengthLabel => 'Uzunluk: ';

  @override
  String get uppercaseOption => 'Büyük harf (A-Z)';

  @override
  String get lowercaseOption => 'Küçük harf (a-z)';

  @override
  String get numbersOption => 'Rakamlar (0-9)';

  @override
  String get symbolsOption => 'Semboller (!@#)';

  @override
  String get refresh => 'Yenile';

  @override
  String get use => 'KULLAN';

  @override
  String get categoryGeneral => 'Genel';

  @override
  String get categorySocial => 'Sosyal';

  @override
  String get categoryWork => 'İş';

  @override
  String get categoryFinance => 'Finans';

  @override
  String get categoryShopping => 'Alışveriş';

  @override
  String get categoryOther => 'Diğer';

  @override
  String get categoryAll => 'Tümü';

  @override
  String get myVaultTitle => 'Kasam';

  @override
  String get searchPasswordsHint => 'Şifrelerde ara...';

  @override
  String get noPasswordsFound => 'Henüz şifre eklemediniz.';

  @override
  String get newPassword => 'Yeni Şifre';

  @override
  String get deletePasswordTitle => 'Şifre silinsin mi?';

  @override
  String get deletePasswordMessage => 'Bu işlem geri alınamaz.';

  @override
  String get passwordDeleted => 'Şifre silindi.';

  @override
  String copiedPassword(Object title) {
    return '$title şifresi kopyalandı!';
  }

  @override
  String copiedUsername(Object title) {
    return '$title kullanıcı adı kopyalandı!';
  }

  @override
  String get pinMinLength => 'PIN en az 4 haneli olmalı';

  @override
  String get incorrectPin => 'PIN hatalı!';

  @override
  String get createMasterPinTitle => 'Ana PIN Oluştur';

  @override
  String get createMasterPinSubtitle => 'Verilerinizi ana PIN ile koruyun.';

  @override
  String get enterPinToDecrypt => 'Verileri çözmek için PIN girin.';

  @override
  String get setMasterPinAction => 'ANA PIN AYARLA';

  @override
  String get unlockVault => 'KASAYI AÇ';

  @override
  String get tapToUseBiometrics => 'Biyometrik kullanmak için dokunun';

  @override
  String get verifyCurrentPinDescription =>
      'Devam etmek için mevcut PIN\'inizi girin.';

  @override
  String get wrongPin => 'PIN yanlış!';

  @override
  String get setNewPinTitle => 'Yeni PIN Ayarla';

  @override
  String get setNewPinDescription => 'Yeni ana PIN\'inizi girin.';

  @override
  String get pinChangeSuccess => 'PIN güncellendi.';

  @override
  String get pinChangeFailed => 'PIN değiştirme başarısız. Tekrar deneyin.';

  @override
  String get enterPanicPin => 'Panik PIN Girin';

  @override
  String get panicPinSameAsMaster => 'Ana PIN ile aynı olamaz';

  @override
  String get panicPinSet => 'Panik PIN ayarlandı.';

  @override
  String get panicPinInfoTitle => 'Panik PIN\'i etkinlestirmeden once';

  @override
  String get panicPinInfoWhatItDoes =>
      'Panik PIN, alternatif bir acil durum akisina giris yapar.';

  @override
  String get panicPinInfoDecoyVault =>
      'Gercek kasaniz yerine bir yem kasa gosterir.';

  @override
  String get panicPinInfoRisk =>
      'Yanlislikla kullanirsaniz verileriniz kayip sanilabilir.';

  @override
  String get panicPinConfirmLabel =>
      'Yem kasa akisinin olusturulacagini anliyorum.';

  @override
  String get panicPinConfirmRequired => 'Kaydetmeden once lutfen onaylayin.';

  @override
  String get privacyModeHelperText =>
      'Gizlilik modu, ana PIN girilene kadar kasayı boş gösterir.';

  @override
  String get biometricAvailable => 'Parmak izi / Face ID kullan';

  @override
  String get biometricUnavailable => 'Bu cihazda kullanılmıyor';

  @override
  String get deleteAllTitle => 'Emin misiniz?';

  @override
  String get deleteAllDescription =>
      'Kaydedilmiş tüm şifreler kalıcı olarak silinecek.';

  @override
  String get allPasswordsDeleted => 'Tüm şifreler kalıcı olarak silindi.';

  @override
  String get germanShort => 'DE';

  @override
  String get noPasswordsToExport => 'Dışa aktarılacak şifre yok.';

  @override
  String get backupShareText => 'OneRule şifre yedeği';

  @override
  String get saveBackupFileTitle => 'Yedek dosyasını kaydet';

  @override
  String get backupSavedToDevice => 'Yedek cihaza kaydedildi.';

  @override
  String backupLastTimestamp(Object timestamp) {
    return 'Son yedek: $timestamp';
  }

  @override
  String exportFailed(Object error) {
    return 'Dışa aktarma başarısız: $error';
  }

  @override
  String passwordsImported(Object count) {
    return '$count şifre başarıyla içe aktarıldı.';
  }

  @override
  String get importFailed =>
      'İçe aktarma başarısız. Lütfen geçerli bir yedek dosyası seçin.';

  @override
  String get importFailedInvalidOrPassword =>
      'Yedek dosyası geçersiz veya parola hatalı.';

  @override
  String get backupPassphraseTitle => 'Yedek parolası';

  @override
  String get backupPassphraseHint => 'Yedek parolasını girin';

  @override
  String get backupPassphraseConfirmHint => 'Yedek parolasını tekrar girin';

  @override
  String get backupPassphraseMismatch => 'Parolalar eşleşmiyor.';

  @override
  String get backupPassphraseEmpty => 'Parola boş olamaz.';

  @override
  String get legacyImportWarningTitle => 'Eski JSON içe aktarma';

  @override
  String get legacyImportWarningBody =>
      'Bu JSON yedeği şifrelenmemiştir. İçe aktarma sırasında şifreleriniz diğer uygulamalara veya servislerine açılabilir. Yalnızca dosyaya ve ortama güveniyorsanız devam edin.';

  @override
  String get legacyImportConfirm => 'Yine de içe aktar';

  @override
  String get clipboardWillClear => 'Pano 30 saniye içinde temizlenecek.';

  @override
  String get vaultLabel => 'Kasa';

  @override
  String get privacyModeLabel => 'Gizlilik modu';

  @override
  String get copiedToClipboard => 'Panoya kopyalandı';

  @override
  String get usernameCopied => 'Kullanıcı adı kopyalandı';

  @override
  String get autoLockTitle => 'Otomatik kilit';

  @override
  String get clipboardSectionTitle => 'Pano';

  @override
  String get clearClipboardAfterTitle => 'Panoyu temizle';

  @override
  String get alsoClearUsernameCopiesTitle =>
      'Kullanıcı adı/e-posta kopyalarını da temizle';

  @override
  String get offLabel => 'Kapalı';

  @override
  String get passwordRevealControlLabel => 'Şifre görünürlüğü';

  @override
  String get passwordRevealHoldHint => 'Şifreyi görmek için basılı tut';

  @override
  String get passwordRevealHoldTooltip => 'Basılı tut';

  @override
  String get passwordRevealReleaseTooltip => 'Gizlemek için bırak';

  @override
  String get clearSearchFiltersLabel => 'Arama ve filtreleri temizle';

  @override
  String get enableClipboardAutoClearFirstHint =>
      'Önce pano otomatik temizlemeyi açın';

  @override
  String secondsShort(int seconds) {
    return '$seconds sn';
  }

  @override
  String minutesShort(int minutes) {
    return '$minutes dk';
  }

  @override
  String get confirm => 'Onayla';

  @override
  String get initErrorTitle => 'Başlatma başarısız';

  @override
  String get initErrorBody =>
      'Kasa açılamadı. Yeniden deneyebilir veya giriş ekranına dönebilirsiniz.';

  @override
  String get retry => 'Tekrar dene';

  @override
  String get goToLogin => 'Giriş ekranına git';

  @override
  String get biometricPrompt => 'Giriş yapmak için kimliğinizi doğrulayın';

  @override
  String get usePinToFinishUnlocking => 'Kilidi tamamlamak için PIN kullanın.';
}
