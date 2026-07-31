// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AutoService';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String get logIn => 'Log in';

  @override
  String get newShopCreateAccount => 'New shop? Create an account';

  @override
  String get createYourShop => 'Create your shop';

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
  String get createShopAndAccount => 'Create shop & account';

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
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get searchByNamePhoneOrEmail => 'Search by name, phone, or email';

  @override
  String get noClientsYet => 'No clients yet';

  @override
  String get clientsVehicles => 'Client\'s Vehicles';

  @override
  String get searchByLicensePlate => 'Search by license plate';

  @override
  String get noVehiclesFound => 'No vehicles found';

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
  String get noWorkOrdersYet => 'No work orders yet';

  @override
  String mileageKm(String km) {
    return 'Mileage: $km km';
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
  String get noCatalogItemsYet => 'No catalog items yet';

  @override
  String get newWorkOrder => 'New Work Order';

  @override
  String get noWorkOrders => 'No work orders';

  @override
  String get paymentMethodTitle => 'Payment method';

  @override
  String get deleteWorkOrderTitle => 'Delete work order?';

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
  String get printPdf => 'Print / PDF';

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
  String get noPaidWorkOrdersInRange => 'No paid work orders in this range';

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
  String get draft => 'Draft';

  @override
  String get completed => 'Completed';

  @override
  String get paid => 'Paid';

  @override
  String get completedUnpaid => 'Completed (unpaid)';

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
}
