// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'AutoServis';

  @override
  String get email => 'E-posta';

  @override
  String get password => 'Şifre';

  @override
  String get emailRequired => 'E-posta gereklidir';

  @override
  String get passwordRequired => 'Şifre gereklidir';

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
  String get save => 'Sıkıştır (Kaydet)';

  @override
  String get newWorkOrder => 'Yeni İş Emri Patlat';

  @override
  String get noWorkOrders => 'Servis kaydı yok';

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
}
