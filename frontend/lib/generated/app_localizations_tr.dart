// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'GarajOS';

  @override
  String get email => 'E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get emailRequired => 'E-posta gereklidir';

  @override
  String get passwordRequired => 'Şifre gereklidir';

  @override
  String get invalidEmailOrPassword => 'E-posta veya şifre hatalı';

  @override
  String get logIn => 'Mesaiye Başla';

  @override
  String get newShopCreateAccount => 'Yeni işletme? Hesap oluştur';

  @override
  String get createYourShop => 'Dükkanı Kur';

  @override
  String get createShopDescription =>
      'Bu işlem yeni bir işletme ve ilk sahip hesabını oluşturur.';

  @override
  String get shopName => 'İşletme adı';

  @override
  String get yourFullName => 'Adınız soyadınız';

  @override
  String get atLeast8Characters => 'En az 8 karakter';

  @override
  String get shopNameRequired => 'İşletme adı gereklidir';

  @override
  String get yourNameRequired => 'Adınız gereklidir';

  @override
  String get passwordMinLength => 'Şifre en az 8 karakter olmalıdır';

  @override
  String get createShopAndAccount => 'Anahtarları Ver (Dükkanı Aç)';

  @override
  String get backToLogin => 'Girişe dön';

  @override
  String get workOrders => 'Servis Kaydı';

  @override
  String get clients => 'Müşteriler';

  @override
  String get vehicles => 'Araçlar';

  @override
  String get catalog => 'Katalog';

  @override
  String get reports => 'Raporlar';

  @override
  String get logOut => 'Çıkış Yap';

  @override
  String get language => 'Dil';

  @override
  String get voiceToneLabel => 'Ton';

  @override
  String get toneCorporate => 'Kurumsal';

  @override
  String get toneStreet => 'Garaj';

  @override
  String get globalSearchHint => 'Plaka, isim, telefon, sipariş no ile ara';

  @override
  String get selectItemToViewDetails => 'Detayları görmek için bir öğe seçin';

  @override
  String get edit => 'Ayar Çek';

  @override
  String get delete => 'Hurdaya Ayır';

  @override
  String get cancel => 'İptal';

  @override
  String get searchByNamePhoneOrEmail => 'İsim, telefon veya e-posta ile ara';

  @override
  String get noClientsYet =>
      'Dükkan sinek avlıyor! Hadi içeri birkaç müşteri çekelim.';

  @override
  String get newClient => 'Yeni Müşteri';

  @override
  String get editClient => 'Müşteriyi Düzenle';

  @override
  String get fullNameLabel => 'Ad soyad';

  @override
  String get phoneLabel => 'Telefon';

  @override
  String get addressLabel => 'Adres';

  @override
  String get clientsVehicles => 'Müşteri Araçları';

  @override
  String get searchByLicensePlate => 'Plakaya göre ara';

  @override
  String get noVehiclesFound => 'Ortalık çok sessiz. Lifter pas tutacak!';

  @override
  String get newVehicle => 'Yeni Araç';

  @override
  String get editVehicle => 'Aracı Düzenle';

  @override
  String get owner => 'Sahip';

  @override
  String get selectAnOwner => 'Bir sahip seçin';

  @override
  String failedToLoadClients(Object error) {
    return 'Müşteri defteri yağ karterine düştü galiba: $error';
  }

  @override
  String get licensePlate => 'Plaka';

  @override
  String get make => 'Marka';

  @override
  String get model => 'Model';

  @override
  String get engineLabel => 'Motor';

  @override
  String get yearFieldLabel => 'Yıl';

  @override
  String get currentMileageKmLabel => 'Güncel kilometre (km)';

  @override
  String get vehicleHistory => 'Araç Geçmişi';

  @override
  String engine(String value) {
    return 'Motor: $value';
  }

  @override
  String yearLabel(String value) {
    return 'Yıl: $value';
  }

  @override
  String currentMileage(String km) {
    return 'Güncel kilometre: $km km';
  }

  @override
  String serviceHistoryCount(int count) {
    return 'Servis Geçmişi ($count)';
  }

  @override
  String get noWorkOrdersYet =>
      'Bugün eller fazla temiz kaldı. Hadi bir kaput açalım!';

  @override
  String mileageKm(String km) {
    return 'Kilometre: $km km';
  }

  @override
  String get garageCompleteness => 'Garaj Puanı';

  @override
  String get fullyTuned => 'Motor tam kıvamında! 🔧';

  @override
  String addFieldsToLevelUp(String fields) {
    return 'Seviye atlamak için $fields ekle.';
  }

  @override
  String get serviceAndPartsCatalog => 'Servis ve Parça Kataloğu';

  @override
  String get all => 'Tümü';

  @override
  String get services => 'Servisler';

  @override
  String get parts => 'Parçalar';

  @override
  String get noCatalogItemsYet =>
      'Takım çantası boş! Hemen birkaç parça ve servis ekle.';

  @override
  String get newCatalogItem => 'Yeni Katalog Öğesi';

  @override
  String get editCatalogItem => 'Katalog Öğesini Düzenle';

  @override
  String get service => 'Servis';

  @override
  String get part => 'Parça';

  @override
  String get nameLabel => 'İsim';

  @override
  String get required => 'Bu parça eksik, motor çalışmaz!';

  @override
  String get skuOptional => 'SKU (isteğe bağlı)';

  @override
  String get unit => 'Birim';

  @override
  String get defaultPrice => 'Varsayılan fiyat';

  @override
  String get enterValidNumber =>
      'Somunla ödeme almıyorsak geçerli bir rakam girelim.';

  @override
  String get save => 'Kaydet';

  @override
  String get newWorkOrder => 'Yeni İş Emri Patlat';

  @override
  String editWorkOrderTitle(int no) {
    return '#$no Nolu Kaydı Düzenle';
  }

  @override
  String get client => 'Müşteri';

  @override
  String get vehicle => 'Araç';

  @override
  String get selectAClient => 'Bir müşteri seçin';

  @override
  String get selectAVehicle => 'Bir araç seçin';

  @override
  String get selectClientAndVehicle => 'Bir müşteri ve araç seçin';

  @override
  String get addAtLeastOneLineItem => 'En az bir kalem ekleyin';

  @override
  String failedToLoadVehicles(Object error) {
    return 'Araç listesi yağ karterine düştü galiba: $error';
  }

  @override
  String get mileageAtServiceLabel => 'Servis kilometresi (km)';

  @override
  String get fromCatalog => 'Katalogdan seç';

  @override
  String get customLineItem => 'Özel';

  @override
  String get descriptionLabel => 'Açıklama';

  @override
  String get qtyLabel => 'Adet';

  @override
  String get priceLabel => 'Fiyat';

  @override
  String get taxRateLabel => 'Vergi oranı (%)';

  @override
  String get taxLabel => 'Vergi';

  @override
  String get noWorkOrders => 'Servis kaydı yok';

  @override
  String get thePitStop => 'PİT DURAĞI';

  @override
  String get dayStreak => 'GÜN SERİSİ';

  @override
  String get paymentMethodTitle => 'Ödeme yöntemi';

  @override
  String get deleteWorkOrderTitle => 'Servis kaydı hurdaya ayrılsın mı?';

  @override
  String deleteWorkOrderBody(int orderNo) {
    return '#$orderNo numaralı servis kaydı kalıcı olarak silinecek.';
  }

  @override
  String markAs(String status) {
    return '$status İşaretle';
  }

  @override
  String orderNo(int no) {
    return '#$no Servis Kaydı';
  }

  @override
  String clientLabel(String name) {
    return 'Müşteri: $name';
  }

  @override
  String vehicleLabel(String info) {
    return 'Araç: $info';
  }

  @override
  String mileageAtService(int km) {
    return 'Servisteki kilometre: $km km';
  }

  @override
  String dateLabel(String date) {
    return 'Tarih: $date';
  }

  @override
  String get lineItems => 'Kalemler';

  @override
  String get subtotal => 'Ara Toplam';

  @override
  String get discount => 'İndirim';

  @override
  String taxWithRate(String rate) {
    return 'Vergi (%$rate)';
  }

  @override
  String get grandTotal => 'Genel Toplam';

  @override
  String get notes => 'Notlar';

  @override
  String get printPdf => 'Hesabı Kes (PDF)';

  @override
  String get revenue => 'Gelir';

  @override
  String get paymentStatus => 'Ödeme Durumu';

  @override
  String get partsUsage => 'Parça Kullanımı';

  @override
  String fromDate(String date) {
    return 'Başlangıç: $date';
  }

  @override
  String toDate(String date) {
    return 'Bitiş: $date';
  }

  @override
  String get clearFilter => 'Temizle';

  @override
  String get day => 'Gün';

  @override
  String get week => 'Hafta';

  @override
  String get month => 'Ay';

  @override
  String get totalRevenue => 'Toplam gelir';

  @override
  String get noPaidWorkOrdersInRange =>
      'Bu tarihlerde kasaya giren bir şey yok. Hadi birkaç iş bitirelim!';

  @override
  String get noUsageInRange => 'Bu aralıkta kullanım yok';

  @override
  String qtyUsed(String qty) {
    return 'Kullanılan: $qty';
  }

  @override
  String orderCount(int count) {
    return '$count sipariş';
  }

  @override
  String get draft => 'Lifte Alındı';

  @override
  String get completed => 'Tamir Tamam';

  @override
  String get paid => 'Kasa Doldu';

  @override
  String get completedUnpaid => 'Tamir Tamam (ödenmemiş)';

  @override
  String get totalOutstanding => 'Toplam bekleyen';

  @override
  String get anyDate => 'Herhangi';

  @override
  String get cash => 'Nakit';

  @override
  String get card => 'Kart';

  @override
  String get bankTransfer => 'Banka transferi';

  @override
  String get other => 'Diğer';

  @override
  String get profile => 'Profil';

  @override
  String get myAccount => 'Hesabım';

  @override
  String get shopDetails => 'İşletme Bilgileri';

  @override
  String get changePassword => 'Şifre Değiştir';

  @override
  String get currentPassword => 'Mevcut şifre';

  @override
  String get newPassword => 'Yeni şifre';

  @override
  String get confirmPassword => 'Yeni şifreyi onayla';

  @override
  String get passwordsDoNotMatch => 'Şifreler eşleşmiyor';

  @override
  String get passwordChanged => 'Şifre değiştirildi';

  @override
  String get taxId => 'Vergi No';

  @override
  String get taxOffice => 'Vergi Dairesi';

  @override
  String get uploadLogo => 'Logo yükle';

  @override
  String get removeLogo => 'Logoyu kaldır';

  @override
  String get noLogoUploaded => 'Logo yüklenmedi';

  @override
  String get profileUpdated => 'Profil güncellendi';

  @override
  String get shopUpdated => 'İşletme bilgileri güncellendi';

  @override
  String get viewOnlyShopDetails =>
      'Sadece görüntüleme — değişiklik için işletme sahibi veya yöneticisiyle görüşün';

  @override
  String get team => 'Ekip';

  @override
  String get members => 'Üyeler';

  @override
  String get active => 'Aktif';

  @override
  String get inactive => 'Pasif';

  @override
  String get role => 'Rol';

  @override
  String get manager => 'Yönetici';

  @override
  String get technician => 'Teknisyen';

  @override
  String get deactivate => 'Devre dışı bırak';

  @override
  String get reactivate => 'Yeniden etkinleştir';

  @override
  String get deleteMember => 'Kaldır';

  @override
  String get confirmDeleteMemberTitle => 'Ekip üyesi kaldırılsın mı?';

  @override
  String confirmDeleteMemberBody(String name) {
    return '$name erişimini hemen kaybedecek. Bu işlem geri alınamaz.';
  }

  @override
  String get inviteTeamMember => 'Ekip Üyesi Davet Et';

  @override
  String get expiresIn => 'Son kullanma';

  @override
  String get hours24 => '24 saat';

  @override
  String get days3 => '3 gün';

  @override
  String get days7 => '7 gün';

  @override
  String get generateInviteLink => 'Bağlantı oluştur';

  @override
  String get inviteLinkLabel => 'Davet bağlantısı';

  @override
  String get copyLink => 'Kopyala';

  @override
  String get linkCopied => 'Bağlantı kopyalandı';

  @override
  String get shareViaWhatsApp => 'WhatsApp ile paylaş';

  @override
  String whatsAppInviteMessage(String shop, String link) {
    return '$shop işletmesine GarajOS üzerinden katıl: $link';
  }

  @override
  String get pendingInvites => 'Bekleyen Davetler';

  @override
  String get noPendingInvites => 'Bekleyen davet yok';

  @override
  String get inviteStatusPending => 'Bekliyor';

  @override
  String get inviteStatusUsed => 'Kullanıldı';

  @override
  String get inviteStatusRevoked => 'İptal edildi';

  @override
  String get inviteStatusExpired => 'Süresi doldu';

  @override
  String get revokeInviteAction => 'İptal Et';

  @override
  String get firstName => 'Ad';

  @override
  String get lastName => 'Soyad';

  @override
  String youAreJoining(String shop, String role) {
    return '$shop işletmesine $role olarak katılıyorsunuz';
  }

  @override
  String get joinAndCreateAccount => 'Hesap oluştur';
}

/// The translations for Turkish, as used in Clipperton Island (`tr_CP`).
class AppLocalizationsTrCp extends AppLocalizationsTr {
  AppLocalizationsTrCp() : super('tr_CP');

  @override
  String get logIn => 'Giriş Yap';

  @override
  String get createYourShop => 'İşletmenizi oluşturun';

  @override
  String get createShopAndAccount => 'İşletme ve hesap oluştur';

  @override
  String get edit => 'Düzenle';

  @override
  String get delete => 'Sil';

  @override
  String get noClientsYet => 'Henüz müşteri yok';

  @override
  String get noVehiclesFound => 'Araç bulunamadı';

  @override
  String failedToLoadClients(Object error) {
    return 'Müşteriler yüklenemedi: $error';
  }

  @override
  String get noWorkOrdersYet => 'Henüz servis kaydı yok';

  @override
  String get garageCompleteness => 'Profil Tamamlanma Durumu';

  @override
  String get fullyTuned => 'Profil tamamlandı.';

  @override
  String addFieldsToLevelUp(String fields) {
    return 'Profili tamamlamak için $fields ekleyin.';
  }

  @override
  String get noCatalogItemsYet => 'Henüz katalog öğesi yok';

  @override
  String get required => 'Zorunlu';

  @override
  String get enterValidNumber => 'Geçerli bir sayı girin';

  @override
  String get save => 'Kaydet';

  @override
  String get newWorkOrder => 'Yeni Servis Kaydı';

  @override
  String get thePitStop => 'DURUM';

  @override
  String get dayStreak => 'ARDIŞIK GÜN';

  @override
  String get deleteWorkOrderTitle => 'Servis kaydı silinsin mi?';

  @override
  String markAs(String status) {
    return '$status olarak işaretle';
  }

  @override
  String get printPdf => 'Yazdır / PDF';

  @override
  String get noPaidWorkOrdersInRange => 'Bu aralıkta ödenmiş servis kaydı yok';

  @override
  String get draft => 'Taslak';

  @override
  String get completed => 'Tamamlandı';

  @override
  String get paid => 'Ödendi';

  @override
  String get completedUnpaid => 'Tamamlandı (ödenmemiş)';
}
