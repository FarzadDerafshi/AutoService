import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../application/vehicles_provider.dart';

class VehicleHistoryScreen extends ConsumerWidget {
  const VehicleHistoryScreen({required this.vehicleId, super.key});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final historyAsync = ref.watch(vehicleHistoryProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: Text(l.vehicleHistory)),
      body: AsyncValueWidget(
        value: historyAsync,
        onRetry: () => ref.invalidate(vehicleHistoryProvider(vehicleId)),
        data: (history) {
          final vehicle = history.vehicle;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle.licensePlate, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 4),
                      Text(vehicle.displayName),
                      if (vehicle.engineType != null) Text(l.engine(vehicle.engineType!)),
                      if (vehicle.year != null) Text(l.yearLabel(vehicle.year.toString())),
                      Text(l.currentMileage(vehicle.currentMileageKm.toString())),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(l.serviceHistoryCount(history.workOrders.length),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (history.workOrders.isEmpty)
                Padding(padding: const EdgeInsets.all(16), child: Text(l.noWorkOrdersYet)),
              for (final order in history.workOrders)
                Card(
                  child: ListTile(
                    title: Text('${l.orderNo(order['orderNo'] as int)} — ${_statusLabel(l, order['status'] as String)}'),
                    subtitle: Text(
                      '${l.mileageKm((order['mileageAtService'] ?? '—').toString())} · ${DateTime.parse(order['createdAt'] as String).toLocal().toString().split('.').first}',
                    ),
                    trailing: Text(formatCurrency((order['grandTotal'] as num).toDouble())),
                    onTap: () => context.push('/work-orders/${order['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

String _statusLabel(AppLocalizations l, String status) => switch (status) {
      'draft' => l.draft,
      'completed' => l.completed,
      'paid' => l.paid,
      _ => status,
    };
