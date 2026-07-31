import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

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
/// import 'generated/app_localizations.dart';
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
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'AutoService'**
  String get appTitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get emailRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required'**
  String get passwordRequired;

  /// No description provided for @logIn.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get logIn;

  /// No description provided for @newShopCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New shop? Create an account'**
  String get newShopCreateAccount;

  /// No description provided for @createYourShop.
  ///
  /// In en, this message translates to:
  /// **'Create your shop'**
  String get createYourShop;

  /// No description provided for @createShopDescription.
  ///
  /// In en, this message translates to:
  /// **'This creates a new shop and its first owner account.'**
  String get createShopDescription;

  /// No description provided for @shopName.
  ///
  /// In en, this message translates to:
  /// **'Shop name'**
  String get shopName;

  /// No description provided for @yourFullName.
  ///
  /// In en, this message translates to:
  /// **'Your full name'**
  String get yourFullName;

  /// No description provided for @atLeast8Characters.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get atLeast8Characters;

  /// No description provided for @shopNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Shop name is required'**
  String get shopNameRequired;

  /// No description provided for @yourNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Your name is required'**
  String get yourNameRequired;

  /// No description provided for @passwordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get passwordMinLength;

  /// No description provided for @createShopAndAccount.
  ///
  /// In en, this message translates to:
  /// **'Create shop & account'**
  String get createShopAndAccount;

  /// No description provided for @backToLogin.
  ///
  /// In en, this message translates to:
  /// **'Back to login'**
  String get backToLogin;

  /// No description provided for @workOrders.
  ///
  /// In en, this message translates to:
  /// **'Work Orders'**
  String get workOrders;

  /// No description provided for @clients.
  ///
  /// In en, this message translates to:
  /// **'Clients'**
  String get clients;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalog;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @searchByNamePhoneOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Search by name, phone, or email'**
  String get searchByNamePhoneOrEmail;

  /// No description provided for @noClientsYet.
  ///
  /// In en, this message translates to:
  /// **'No clients yet'**
  String get noClientsYet;

  /// No description provided for @clientsVehicles.
  ///
  /// In en, this message translates to:
  /// **'Client\'s Vehicles'**
  String get clientsVehicles;

  /// No description provided for @searchByLicensePlate.
  ///
  /// In en, this message translates to:
  /// **'Search by license plate'**
  String get searchByLicensePlate;

  /// No description provided for @noVehiclesFound.
  ///
  /// In en, this message translates to:
  /// **'No vehicles found'**
  String get noVehiclesFound;

  /// No description provided for @vehicleHistory.
  ///
  /// In en, this message translates to:
  /// **'Vehicle History'**
  String get vehicleHistory;

  /// No description provided for @engine.
  ///
  /// In en, this message translates to:
  /// **'Engine: {value}'**
  String engine(String value);

  /// No description provided for @yearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year: {value}'**
  String yearLabel(String value);

  /// No description provided for @currentMileage.
  ///
  /// In en, this message translates to:
  /// **'Current mileage: {km} km'**
  String currentMileage(String km);

  /// No description provided for @serviceHistoryCount.
  ///
  /// In en, this message translates to:
  /// **'Service History ({count})'**
  String serviceHistoryCount(int count);

  /// No description provided for @noWorkOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No work orders yet'**
  String get noWorkOrdersYet;

  /// No description provided for @mileageKm.
  ///
  /// In en, this message translates to:
  /// **'Mileage: {km} km'**
  String mileageKm(String km);

  /// No description provided for @serviceAndPartsCatalog.
  ///
  /// In en, this message translates to:
  /// **'Service & Parts Catalog'**
  String get serviceAndPartsCatalog;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @services.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get services;

  /// No description provided for @parts.
  ///
  /// In en, this message translates to:
  /// **'Parts'**
  String get parts;

  /// No description provided for @noCatalogItemsYet.
  ///
  /// In en, this message translates to:
  /// **'No catalog items yet'**
  String get noCatalogItemsYet;

  /// No description provided for @newCatalogItem.
  ///
  /// In en, this message translates to:
  /// **'New Catalog Item'**
  String get newCatalogItem;

  /// No description provided for @editCatalogItem.
  ///
  /// In en, this message translates to:
  /// **'Edit Catalog Item'**
  String get editCatalogItem;

  /// No description provided for @service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get service;

  /// No description provided for @part.
  ///
  /// In en, this message translates to:
  /// **'Part'**
  String get part;

  /// No description provided for @nameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @skuOptional.
  ///
  /// In en, this message translates to:
  /// **'SKU (optional)'**
  String get skuOptional;

  /// No description provided for @unit.
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No description provided for @defaultPrice.
  ///
  /// In en, this message translates to:
  /// **'Default price'**
  String get defaultPrice;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @newWorkOrder.
  ///
  /// In en, this message translates to:
  /// **'New Work Order'**
  String get newWorkOrder;

  /// No description provided for @noWorkOrders.
  ///
  /// In en, this message translates to:
  /// **'No work orders'**
  String get noWorkOrders;

  /// No description provided for @paymentMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get paymentMethodTitle;

  /// No description provided for @deleteWorkOrderTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete work order?'**
  String get deleteWorkOrderTitle;

  /// No description provided for @deleteWorkOrderBody.
  ///
  /// In en, this message translates to:
  /// **'Order #{orderNo} will be permanently deleted.'**
  String deleteWorkOrderBody(int orderNo);

  /// No description provided for @markAs.
  ///
  /// In en, this message translates to:
  /// **'Mark as {status}'**
  String markAs(String status);

  /// No description provided for @orderNo.
  ///
  /// In en, this message translates to:
  /// **'Order #{no}'**
  String orderNo(int no);

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client: {name}'**
  String clientLabel(String name);

  /// No description provided for @vehicleLabel.
  ///
  /// In en, this message translates to:
  /// **'Vehicle: {info}'**
  String vehicleLabel(String info);

  /// No description provided for @mileageAtService.
  ///
  /// In en, this message translates to:
  /// **'Mileage at service: {km} km'**
  String mileageAtService(int km);

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date: {date}'**
  String dateLabel(String date);

  /// No description provided for @lineItems.
  ///
  /// In en, this message translates to:
  /// **'Line Items'**
  String get lineItems;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @taxWithRate.
  ///
  /// In en, this message translates to:
  /// **'Tax ({rate}%)'**
  String taxWithRate(String rate);

  /// No description provided for @grandTotal.
  ///
  /// In en, this message translates to:
  /// **'Grand Total'**
  String get grandTotal;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @printPdf.
  ///
  /// In en, this message translates to:
  /// **'Print / PDF'**
  String get printPdf;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @paymentStatus.
  ///
  /// In en, this message translates to:
  /// **'Payment Status'**
  String get paymentStatus;

  /// No description provided for @partsUsage.
  ///
  /// In en, this message translates to:
  /// **'Parts Usage'**
  String get partsUsage;

  /// No description provided for @fromDate.
  ///
  /// In en, this message translates to:
  /// **'From: {date}'**
  String fromDate(String date);

  /// No description provided for @toDate.
  ///
  /// In en, this message translates to:
  /// **'To: {date}'**
  String toDate(String date);

  /// No description provided for @clearFilter.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearFilter;

  /// No description provided for @day.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// No description provided for @week.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get week;

  /// No description provided for @month.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get month;

  /// No description provided for @totalRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total revenue'**
  String get totalRevenue;

  /// No description provided for @noPaidWorkOrdersInRange.
  ///
  /// In en, this message translates to:
  /// **'No paid work orders in this range'**
  String get noPaidWorkOrdersInRange;

  /// No description provided for @noUsageInRange.
  ///
  /// In en, this message translates to:
  /// **'No usage in this range'**
  String get noUsageInRange;

  /// No description provided for @qtyUsed.
  ///
  /// In en, this message translates to:
  /// **'Qty used: {qty}'**
  String qtyUsed(String qty);

  /// No description provided for @orderCount.
  ///
  /// In en, this message translates to:
  /// **'{count} orders'**
  String orderCount(int count);

  /// No description provided for @draft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get draft;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @completedUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Completed (unpaid)'**
  String get completedUnpaid;

  /// No description provided for @totalOutstanding.
  ///
  /// In en, this message translates to:
  /// **'Total outstanding'**
  String get totalOutstanding;

  /// No description provided for @anyDate.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get anyDate;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank transfer'**
  String get bankTransfer;

  /// No description provided for @other.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get other;
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
      <String>['en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
