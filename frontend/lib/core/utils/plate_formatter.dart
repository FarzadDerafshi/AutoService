final _trPlatePattern = RegExp(r'^(\d{2})([A-Z]{1,3})(\d{2,4})$');

/// Formats an already-normalized Turkish plate ("34ABC123", no spaces —
/// see backend's normalizePlate) for display as "34 ABC 123". Display
/// only — never apply this to an editable field's value, to what gets
/// submitted to the API, or to search query text; plates stay stored and
/// compared without spaces everywhere else.
///
/// Matches the general digits-letters-digits shape of a Turkish plate
/// rather than validating the exact official letter/digit-count
/// combinations (1+4, 2+3, 3+2) — simpler, and doesn't need to be kept in
/// sync with that rule table. Anything that doesn't fit this shape (a
/// foreign plate, unusual data) is returned completely unchanged, which is
/// the point: never guess-format something that isn't a Turkish plate.
String formatPlateDisplay(String plate) {
  final match = _trPlatePattern.firstMatch(plate.toUpperCase());
  if (match == null) return plate;
  return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
}
