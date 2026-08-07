/// Formats a plain "YYYY-MM-DD" date string (as returned by the backend for
/// work_orders.service_date) as "DD.MM.YYYY" for display. Pure string
/// manipulation, deliberately not routed through DateTime/DateFormat — this
/// is a calendar date with no time component, and parsing it into a
/// DateTime would require picking a timezone to interpret it in, which a
/// plain date has no meaningful one of.
String formatDateDMY(String isoDate) {
  final parts = isoDate.split('-');
  return '${parts[2]}.${parts[1]}.${parts[0]}';
}

/// "YYYY-MM-DD" for today, in the device's own local calendar — used as the
/// default service_date on a new work order and when writing a picked
/// DateTime back to the form's string state.
String todayIso() => dateToIso(DateTime.now());

String dateToIso(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Parses "YYYY-MM-DD" into a plain local DateTime (year/month/day only,
/// midnight) — used solely to seed showDatePicker's initialDate. Never use
/// DateTime.parse for this: that treats a bare date string as UTC, which can
/// display as the wrong calendar day once anything downstream calls
/// .toLocal() on it.
DateTime isoToDate(String isoDate) {
  final parts = isoDate.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
