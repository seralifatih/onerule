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
  String get backupRestoreTitle => 'Yedekleme ve Geri Yükleme';

  @override
  String get backupRestoreDescription =>
      'Şifrelenmiş yedek oluşturun ve bir yedek dosyasından geri yükleyin.';

  @override
  String get createBackupCta => 'Yedek Oluştur';

  @override
  String get restoreFromBackupCta => 'Yedekten Geri Yükle';

  @override
  String get backupLastUnknown => 'Henüz yedek yok';

  @override
  String get backupGuideTitle => 'Devam etmeden önce önemli';

  @override
  String get backupGuideStep1 =>
      'Düzenli yedek alın ve güvenli bir yerde saklayın.';

  @override
  String get backupGuideStep2 =>
      'PIN\'inizi kaybederseniz kasanız kurtarılamaz.';

  @override
  String get backupGuideStep3 => 'Yedek parolasını cihazınızdan ayrı saklayın.';

  @override
  String get backupGuideStep4 =>
      'Geri yükleme, içe aktarılan öğeleri mevcut kasanıza birleştirir.';

  @override
  String get exportDebugLogTitle => 'Hata günlüğünü dışa aktar';

  @override
  String get exportDebugLogWarning =>
      'Günlük yığın izleri içerebilir ancak şifreler yer almamalıdır.';

  @override
  String get crashReportsSectionTitle => 'Çökme raporları';

  @override
  String get shareCrashReportsTitle => 'Çökme raporlarını paylaş';

  @override
  String get shareCrashReportsSubtitle =>
      'Açıksa yerel logları elle dışa aktarabilirsiniz. Raporlar asla otomatik gönderilmez.';

  @override
  String get shareCrashReportsDisabled =>
      'Log dışa aktarmadan önce Ayarlar\'dan \"Çökme raporlarını paylaş\" seçeneğini açın.';

  @override
  String get viewLogsTitle => 'Logları görüntüle';

  @override
  String get viewLogsEmpty => 'Henüz log yok.';

  @override
  String get copyLogsAction => 'Logları kopyala';

  @override
  String get logsCopied => 'Loglar panoya kopyalandı.';

  @override
  String get debugLogEmpty => 'Henüz dışa aktarılacak bir hata günlüğü yok.';

  @override
  String get debugLogExportFailed => 'Hata günlüğü dışa aktarma başarısız.';

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
  String get panicPinInfoTitle => 'Panik PIN\'i etkinleştirmeden önce';

  @override
  String get panicPinInfoWhatItDoes =>
      'Panik PIN, alternatif bir acil durum akışına giriş yapar.';

  @override
  String get panicPinInfoDecoyVault =>
      'Gerçek kasanız yerine bir yem kasa gösterir.';

  @override
  String get panicPinInfoRisk =>
      'Yanlışlıkla kullanırsanız verileriniz kayıp sanılabilir.';

  @override
  String get panicPinConfirmLabel =>
      'Yem kasa akışının oluşturulacağını anlıyorum.';

  @override
  String get panicPinConfirmRequired => 'Kaydetmeden önce lütfen onaylayın.';

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
  String get backupWizardTitle => 'Yedek oluştur';

  @override
  String backupWizardProgress(int current, int total) {
    return 'Adım $current / $total';
  }

  @override
  String get backupWizardStep1Title => 'Adım 1: Yedek oluştur';

  @override
  String get backupWizardStep1Body =>
      'Yedek dosyanız şifrelenir (.enc). Sadece yedek PIN\'iniz ile açılabilir.';

  @override
  String get backupWizardCreateAction => 'Şifreli yedek oluştur';

  @override
  String get backupWizardStep2Title => 'Adım 2: Hedef seçin';

  @override
  String get backupWizardStep2Body =>
      'Şifreli yedek dosyasını nereye kaydedeceğinizi seçin.';

  @override
  String get backupWizardDestinationDownloads => 'İndirilenler';

  @override
  String get backupWizardDestinationShare => 'Paylaş';

  @override
  String get backupWizardStep3Title => 'Adım 3: Başarıyı onayla';

  @override
  String get backupWizardSuccessBody => 'Şifreli yedek başarıyla oluşturuldu.';

  @override
  String backupWizardFilename(Object fileName) {
    return 'Dosya adı: $fileName';
  }

  @override
  String get backupWizardBackAction => 'Geri';

  @override
  String get backupWizardDoneAction => 'Bitti';

  @override
  String get restoreSectionTitle => 'Yedekten geri yükle';

  @override
  String get restoreSectionDescription =>
      'Şifreli bir yedek dosyası seçin ve geri yüklemek için yedek PIN\'inizi girin.';

  @override
  String get restorePickFileCta => 'Yedek dosyası seç';

  @override
  String get restoreNoFileChosen => 'Dosya seçilmedi';

  @override
  String restoreSelectedFile(Object fileName) {
    return 'Seçilen dosya: $fileName';
  }

  @override
  String get restoreSelectFileFirst => 'Önce bir yedek dosyası seçin.';

  @override
  String get restoreWrongPin => 'Yedek PIN hatalı. Tekrar deneyin.';

  @override
  String get restoreCorruptFile =>
      'Bu yedek dosyası bozuk veya desteklenmiyor.';

  @override
  String get restoreUnknownError =>
      'Geri yükleme başarısız. Lütfen tekrar deneyin.';

  @override
  String get legacyImportWarningTitle => 'Eski JSON içe aktarma';

  @override
  String get legacyImportWarningBody =>
      'Bu JSON yedeği şifrelenmemiştir. İçe aktarma sırasında şifreleriniz diğer uygulamalara veya servislere açılabilir. Yalnızca dosyaya ve ortama güveniyorsanız devam edin.';

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

  @override
  String get openLinkFailed => 'Bağlantı açılamadı';

  @override
  String get vaultHealthTitle => 'Kasa Sağlığı';

  @override
  String get vaultHealthSubtitle =>
      'Zayıf, tekrar eden ve eski şifre kontrolleri.';

  @override
  String get autofillTitle => 'Otomatik Doldurma';

  @override
  String get autofillEnabledSubtitle => 'OneRule için etkin';

  @override
  String get autofillDisabledSubtitle => 'Etkin değil. Kurmak için dokunun.';

  @override
  String get backupReminderTitle => 'Yedek hatırlatıcı';

  @override
  String get backupReminderSubtitle =>
      'Son yedek 30 günden eskiyse aylık hatırlatma gösterilir.';

  @override
  String get supportDevelopmentTitle => 'Geliştirmeyi Destekle';

  @override
  String get buyMeCoffeeTitle => 'Bana bir kahve ısmarla';

  @override
  String get supportDevelopmentBody =>
      'OneRule tek bir geliştirici tarafından yapılıyor. Desteğiniz uygulamanın çevrimdışı ve güncel kalmasına yardımcı olur.';
}
