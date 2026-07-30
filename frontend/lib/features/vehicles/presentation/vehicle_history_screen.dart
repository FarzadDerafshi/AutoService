import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../application/vehicles_provider.dart';

class VehicleHistoryScreen extends ConsumerWidget {
  const VehicleHistoryScreen({required this.vehicleId, super.key});
  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(vehicleHistoryProvider(vehicleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle History')),
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
                      if (vehicle.engineType != null) Text('Engine: ${vehicle.engineType}'),
                      if (vehicle.year != null) Text('Year: ${vehicle.year}'),
                      Text('Current mileage: ${vehicle.currentMileageKm} km'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Service History (${history.workOrders.length})', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (history.workOrders.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No work orders yet')),
              for (final order in history.workOrders)
                Card(
                  child: ListTile(
                    title: Text('Order #${order['orderNo']} — ${order['status']}'),
                    subtitle: Text(
                      'Mileage: ${order['mileageAtService'] ?? '—'} km · ${DateTime.parse(order['createdAt'] as String).toLocal().toString().split('.').first}',
                    ),
                    trailing: Text(formatCurrency((order['grandTotal'] as num).toDouble())),
                    onTap: () => context.push('/work-orders?id=${order['id']}'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
