import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../application/work_orders_provider.dart';
import '../data/work_order_model.dart';

class WorkOrdersMasterList extends ConsumerWidget {
  const WorkOrdersMasterList({required this.selectedId, required this.onSelect, required this.onCreate, super.key});

  final String? selectedId;
  final void Function(WorkOrder order) onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(workOrdersListProvider);
    final statusFilter = ref.watch(workOrdersStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Work Orders'),
        actions: [IconButton(onPressed: onCreate, icon: const Icon(Icons.add))],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: 'All', selected: statusFilter == null, onTap: () => _setFilter(ref, null)),
                  _FilterChip(label: 'Draft', selected: statusFilter == 'draft', onTap: () => _setFilter(ref, 'draft')),
                  _FilterChip(
                      label: 'Completed', selected: statusFilter == 'completed', onTap: () => _setFilter(ref, 'completed')),
                  _FilterChip(label: 'Paid', selected: statusFilter == 'paid', onTap: () => _setFilter(ref, 'paid')),
                ],
              ),
            ),
          ),
        ),
      ),
      body: AsyncValueWidget(
        value: ordersAsync,
        onRetry: () => ref.invalidate(workOrdersListProvider),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No work orders yet'));
          }
          return ListView.separated(
            itemCount: orders.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                selected: order.id == selectedId,
                leading: _StatusDot(status: order.status),
                title: Text('#${order.orderNo} — ${order.clientName ?? order.clientId}'),
                subtitle: Text(order.vehiclePlate ?? order.vehicleId),
                trailing: Text(formatCurrency(order.grandTotal)),
                onTap: () => onSelect(order),
              );
            },
          );
        },
      ),
    );
  }

  void _setFilter(WidgetRef ref, String? status) {
    ref.read(workOrdersStatusFilterProvider.notifier).state = status;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'draft' => Colors.grey,
      'completed' => Colors.orange,
      'paid' => Colors.green,
      _ => Colors.grey,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }
}
