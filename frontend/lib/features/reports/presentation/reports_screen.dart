import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../application/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Revenue'),
            Tab(text: 'Payment Status'),
            Tab(text: 'Parts Usage'),
          ]),
        ),
        body: Column(
          children: [
            _DateRangeBar(),
            const Expanded(
              child: TabBarView(children: [
                _RevenueTab(),
                _PaymentStatusTab(),
                _PartsUsageTab(),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? d) => d == null ? 'Any' : d.toIso8601String().split('T').first;

class _DateRangeBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportsDateRangeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('From: ${_formatDate(range.from)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDate: range.from ?? DateTime.now(),
              );
              if (picked != null) {
                ref.read(reportsDateRangeProvider.notifier).state = DateRange(from: picked, to: range.to);
              }
            },
          ),
          TextButton.icon(
            icon: const Icon(Icons.calendar_today, size: 16),
            label: Text('To: ${_formatDate(range.to)}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDate: range.to ?? DateTime.now(),
              );
              if (picked != null) {
                ref.read(reportsDateRangeProvider.notifier).state = DateRange(from: range.from, to: picked);
              }
            },
          ),
          if (range.from != null || range.to != null)
            TextButton(
              onPressed: () => ref.read(reportsDateRangeProvider.notifier).state = const DateRange(),
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }
}

class _RevenueTab extends ConsumerWidget {
  const _RevenueTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupBy = ref.watch(revenueGroupByProvider);
    final revenueAsync = ref.watch(revenueReportProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'day', label: Text('Day')),
                ButtonSegment(value: 'week', label: Text('Week')),
                ButtonSegment(value: 'month', label: Text('Month')),
              ],
              selected: {groupBy},
              onSelectionChanged: (s) => ref.read(revenueGroupByProvider.notifier).state = s.first,
            ),
          ),
        ),
        Expanded(
          child: AsyncValueWidget(
            value: revenueAsync,
            onRetry: () => ref.invalidate(revenueReportProvider),
            data: (points) {
              if (points.isEmpty) return const Center(child: Text('No paid work orders in this range'));
              final total = points.fold<double>(0, (sum, p) => sum + p.revenue);
              return ListView(
                children: [
                  ListTile(
                    title: const Text('Total revenue'),
                    trailing: Text(formatCurrency(total), style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Divider(),
                  for (final point in points)
                    ListTile(
                      title: Text(point.period.toLocal().toString().split(' ').first),
                      subtitle: Text('${point.orderCount} orders'),
                      trailing: Text(formatCurrency(point.revenue)),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PaymentStatusTab extends ConsumerWidget {
  const _PaymentStatusTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(paymentStatusReportProvider);
    return AsyncValueWidget(
      value: statusAsync,
      onRetry: () => ref.invalidate(paymentStatusReportProvider),
      data: (report) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatCard(label: 'Draft', value: report.draft.toString()),
          _StatCard(label: 'Completed (unpaid)', value: report.completed.toString()),
          _StatCard(label: 'Paid', value: report.paid.toString()),
          _StatCard(label: 'Total outstanding', value: formatCurrency(report.totalOutstanding), emphasize: true),
        ],
      ),
    );
  }
}

class _PartsUsageTab extends ConsumerWidget {
  const _PartsUsageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usageAsync = ref.watch(partsUsageReportProvider);
    return AsyncValueWidget(
      value: usageAsync,
      onRetry: () => ref.invalidate(partsUsageReportProvider),
      data: (rows) {
        if (rows.isEmpty) return const Center(child: Text('No usage in this range'));
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              title: Text(row.name),
              subtitle: Text('Qty used: ${row.totalQuantity}'),
              trailing: Text(formatCurrency(row.totalRevenue)),
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, this.emphasize = false});
  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: emphasize
              ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
