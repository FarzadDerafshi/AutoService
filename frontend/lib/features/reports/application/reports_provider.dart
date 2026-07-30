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
