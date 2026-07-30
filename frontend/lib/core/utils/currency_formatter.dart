import 'package:intl/intl.dart';

final _currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

String formatCurrency(num amount) => _currencyFormat.format(amount);
