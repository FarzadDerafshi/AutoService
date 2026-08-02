// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'GarajOS';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get logIn => 'Punch In';

  @override
  String get newShopCreateAccount => 'New shop? Create an account';

  @override
  String get createYourShop => 'Build Your Garage';

  @override
  String get createShopDescription =>
      'This creates a new shop and its first owner account.';

  @override
  String get shopName => 'Shop name';

  @override
  String get yourFullName => 'Your full name';

  @override
  String get atLeast8Characters => 'At least 8 characters';

  @override
  String get shopNameRequired => 'Shop name is required';

  @override
  String get yourNameRequired => 'Your name is required';

  @override
  String get passwordMinLength => 'Password must be at least 8 characters';

  @override
  String get createShopAndAccount => 'Hand me the keys (Create Shop)';

  @override
  String get backToLogin => 'Back to login';

  @override
  String get workOrders => 'Work Orders';

  @override
  String get clients => 'Clients';

  @override
  String get vehicles => 'Vehicles';

  @override
  String get catalog => 'Catalog';

  @override
  String get reports => 'Reports';

  @override
  String get logOut => 'Log out';

  @override
  String get language => 'Language';

  @override
  String get voiceToneLabel => 'Voice';

  @override
  String get toneCorporate => 'Corporate';

  @override
  String get toneStreet => 'Garage';

  @override
  String get globalSearchHint => 'Search plate, name, phone, order #';

  @override
  String get selectItemToViewDetails => 'Select an item to view its details';

  @override
  String get edit => 'Tweak';

  @override
  String get delete => 'Scrap it';

  @override
  String get cancel => 'Cancel';

  @override
  String get searchByNamePhoneOrEmail => 'Search by name, phone, or email';

  @override
  String get noClientsYet => 'Ghost town! Let\'s get some drivers in here.';

  @override
  String get newClient => 'New Client';

  @override
  String get editClient => 'Edit Client';

  @override
  String get fullNameLabel => 'Full name';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get addressLabel => 'Address';

  @override
  String get clientsVehicles => 'Client\'s Vehicles';

  @override
  String get searchByLicensePlate => 'Search by license plate';

  @override
  String get noVehiclesFound => 'No cars? The lifts are getting cold.';

  @override
  String get newVehicle => 'New Vehicle';

  @override
  String get editVehicle => 'Edit Vehicle';

  @override
  String get owner => 'Owner';

  @override
  String get selectAnOwner => 'Select an owner';

  @override
  String failedToLoadClients(Object error) {
    return 'Whoops, dropped the client list in the oil pan: $error';
  }

  @override
  String get licensePlate => 'License plate';

  @override
  String get make => 'Make';

  @override
  String get model => 'Model';

  @override
  String get engineLabel => 'Engine';

  @override
  String get yearFieldLabel => 'Year';

  @override
  String get currentMileageKmLabel => 'Current mileage (km)';

  @override
  String get vehicleHistory => 'Vehicle History';

  @override
  String engine(String value) {
    return 'Engine: $value';
  }

  @override
  String yearLabel(String value) {
    return 'Year: $value';
  }

  @override
  String currentMileage(String km) {
    return 'Current mileage: $km km';
  }

  @override
  String serviceHistoryCount(int count) {
    return 'Service History ($count)';
  }

  @override
  String get noWorkOrdersYet =>
      'Clean hands today? Time to pop a hood and start a job!';

  @override
  String mileageKm(String km) {
    return 'Mileage: $km km';
  }

  @override
  String get garageCompleteness => 'Garage Completeness';

  @override
  String get fullyTuned => 'Fully tuned! 🔧';

  @override
  String addFieldsToLevelUp(String fields) {
    return 'Add $fields to level up.';
  }

  @override
  String get serviceAndPartsCatalog => 'Service & Parts Catalog';

  @override
  String get all => 'All';

  @override
  String get services => 'Services';

  @override
  String get parts => 'Parts';

  @override
  String get noCatalogItemsYet =>
      'The toolboxes are empty! Add some parts and services.';

  @override
  String get newCatalogItem => 'New Catalog Item';

  @override
  String get editCatalogItem => 'Edit Catalog Item';

  @override
  String get service => 'Service';

  @override
  String get part => 'Part';

  @override
  String get nameLabel => 'Name';

  @override
  String get required => 'Can\'t run without this!';

  @override
  String get skuOptional => 'SKU (optional)';

  @override
  String get unit => 'Unit';

  @override
  String get defaultPrice => 'Default price';

  @override
  String get enterValidNumber =>
      'Unless you\'re paying in washers, use a real number.';

  @override
  String get save => 'Lock it in';

  @override
  String get newWorkOrder => 'Wrench a New Job';

  @override
  String get noWorkOrders => 'No work orders';

  @override
  String get thePitStop => 'THE PIT STOP';

  @override
  String get dayStreak => 'DAY STREAK';

  @override
  String get paymentMethodTitle => 'Payment method';

  @override
  String get deleteWorkOrderTitle => 'Scrap work order?';

  @override
  String deleteWorkOrderBody(int orderNo) {
    return 'Order #$orderNo will be permanently deleted.';
  }

  @override
  String markAs(String status) {
    return 'Mark as $status';
  }

  @override
  String orderNo(int no) {
    return 'Order #$no';
  }

  @override
  String clientLabel(String name) {
    return 'Client: $name';
  }

  @override
  String vehicleLabel(String info) {
    return 'Vehicle: $info';
  }

  @override
  String mileageAtService(int km) {
    return 'Mileage at service: $km km';
  }

  @override
  String dateLabel(String date) {
    return 'Date: $date';
  }

  @override
  String get lineItems => 'Line Items';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String taxWithRate(String rate) {
    return 'Tax ($rate%)';
  }

  @override
  String get grandTotal => 'Grand Total';

  @override
  String get notes => 'Notes';

  @override
  String get printPdf => 'Print the Bill';

  @override
  String get revenue => 'Revenue';

  @override
  String get paymentStatus => 'Payment Status';

  @override
  String get partsUsage => 'Parts Usage';

  @override
  String fromDate(String date) {
    return 'From: $date';
  }

  @override
  String toDate(String date) {
    return 'To: $date';
  }

  @override
  String get clearFilter => 'Clear';

  @override
  String get day => 'Day';

  @override
  String get week => 'Week';

  @override
  String get month => 'Month';

  @override
  String get totalRevenue => 'Total revenue';

  @override
  String get noPaidWorkOrdersInRange =>
      'No cash flowing in these dates. Let\'s close some tickets!';

  @override
  String get noUsageInRange => 'No usage in this range';

  @override
  String qtyUsed(String qty) {
    return 'Qty used: $qty';
  }

  @override
  String orderCount(int count) {
    return '$count orders';
  }

  @override
  String get draft => 'On the Lift';

  @override
  String get completed => 'Fixed & Ready';

  @override
  String get paid => 'Cashed Out';

  @override
  String get completedUnpaid => 'Fixed (unpaid)';

  @override
  String get totalOutstanding => 'Total outstanding';

  @override
  String get anyDate => 'Any';

  @override
  String get cash => 'Cash';

  @override
  String get card => 'Card';

  @override
  String get bankTransfer => 'Bank transfer';

  @override
  String get other => 'Other';

  @override
  String get profile => 'Profile';

  @override
  String get myAccount => 'My Account';

  @override
  String get shopDetails => 'Shop Details';

  @override
  String get changePassword => 'Change Password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get passwordsDoNotMatch => 'Passwords do not match';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get taxId => 'Tax ID';

  @override
  String get taxOffice => 'Tax office';

  @override
  String get uploadLogo => 'Upload logo';

  @override
  String get removeLogo => 'Remove logo';

  @override
  String get noLogoUploaded => 'No logo uploaded';

  @override
  String get profileUpdated => 'Profile updated';

  @override
  String get shopUpdated => 'Shop details updated';

  @override
  String get viewOnlyShopDetails =>
      'View only — ask an owner or manager to make changes';
}

/// The translations for English, as used in Clipperton Island (`en_CP`).
class AppLocalizationsEnCp extends AppLocalizationsEn {
  AppLocalizationsEnCp() : super('en_CP');

  @override
  String get logIn => 'Log in';

  @override
  String get createYourShop => 'Create your shop';

  @override
  String get createShopAndAccount => 'Create shop & account';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get noClientsYet => 'No clients yet';

  @override
  String get noVehiclesFound => 'No vehicles found';

  @override
  String failedToLoadClients(Object error) {
    return 'Failed to load clients: $error';
  }

  @override
  String get noWorkOrdersYet => 'No work orders yet';

  @override
  String get garageCompleteness => 'Profile Completeness';

  @override
  String get fullyTuned => 'Profile complete.';

  @override
  String addFieldsToLevelUp(String fields) {
    return 'Add $fields to complete this profile.';
  }

  @override
  String get noCatalogItemsYet => 'No catalog items yet';

  @override
  String get required => 'Required';

  @override
  String get enterValidNumber => 'Enter a valid number';

  @override
  String get save => 'Save';

  @override
  String get newWorkOrder => 'New Work Order';

  @override
  String get thePitStop => 'STATUS';

  @override
  String get dayStreak => 'CONSECUTIVE DAYS';

  @override
  String get deleteWorkOrderTitle => 'Delete work order?';

  @override
  String get printPdf => 'Print / PDF';

  @override
  String get noPaidWorkOrdersInRange => 'No paid work orders in this range';

  @override
  String get draft => 'Draft';

  @override
  String get completed => 'Completed';

  @override
  String get paid => 'Paid';

  @override
  String get completedUnpaid => 'Completed (unpaid)';
}
