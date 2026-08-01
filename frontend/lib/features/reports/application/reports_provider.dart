import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/reports_repository.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(apiClientProvider));
});

class DateRange {
  final DateTime? from;
  final DateTime? to;
  const DateRange({this.from, this.to});
}

final reportsDateRangeProvider = StateProvider.autoDispose<DateRange>((ref) => const DateRange());
final revenueGroupByProvider = StateProvider.autoDispose<String>((ref) => 'day');

final revenueReportProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(reportsDateRangeProvider);
  final groupBy = ref.watch(revenueGroupByProvider);
  return ref.watch(reportsRepositoryProvider).revenue(dateFrom: range.from, dateTo: range.to, groupBy: groupBy);
});

final paymentStatusReportProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(reportsDateRangeProvider);
  return ref.watch(reportsRepositoryProvider).paymentStatus(dateFrom: range.from, dateTo: range.to);
});

final partsUsageReportProvider = FutureProvider.autoDispose((ref) {
  final range = ref.watch(reportsDateRangeProvider);
  return ref.watch(reportsRepositoryProvider).partsUsage(dateFrom: range.from, dateTo: range.to);
});

/// "Grease Monkey" streak (shown in the AppBar via StreakBadge): the number
/// of consecutive days, ending today, with at least one work order marked
/// paid. Derived from the same day-grouped revenue report the Reports
/// screen uses — independent of that screen's own date-range filter.
final streakDaysProvider = FutureProvider.autoDispose<int>((ref) async {
  final today = DateTime.now();
  final from = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 60));
  final points = await ref.watch(reportsRepositoryProvider).revenue(dateFrom: from, groupBy: 'day');
  final paidDays = {
    for (final p in points)
      if (p.orderCount > 0) _dateKey(p.period.toLocal()),
  };

  var streak = 0;
  var cursor = DateTime(today.year, today.month, today.day);
  while (paidDays.contains(_dateKey(cursor))) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
});

String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';
