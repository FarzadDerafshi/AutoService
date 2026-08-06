import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../application/work_orders_provider.dart';
import '../data/work_order_model.dart';

class WorkOrdersMasterList extends ConsumerWidget {
  const WorkOrdersMasterList({required this.selectedId, required this.onSelect, required this.onCreate, super.key});

  final String? selectedId;
  final void Function(WorkOrder order) onSelect;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final ordersAsync = ref.watch(workOrdersListProvider);
    final statusFilter = ref.watch(workOrdersStatusFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.workOrders),
        actions: [
          IconButton.filled(tooltip: l.newWorkOrder, onPressed: onCreate, icon: const Icon(Icons.add)),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(label: l.all, selected: statusFilter == null, onTap: () => _setFilter(ref, null)),
                  _FilterChip(label: l.draft, selected: statusFilter == 'draft', onTap: () => _setFilter(ref, 'draft')),
                  _FilterChip(label: l.completed, selected: statusFilter == 'completed', onTap: () => _setFilter(ref, 'completed')),
                  _FilterChip(label: l.paid, selected: statusFilter == 'paid', onTap: () => _setFilter(ref, 'paid')),
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
            return _EmptyState(message: l.noWorkOrders);
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final selected = order.id == selectedId;
              final color = AppColors.statusColor(order.status);
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF152A1B) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selected ? AppColors.neonGreenDim.withValues(alpha: 0.35) : Colors.transparent),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  leading: _StatusDot(color: color),
                  title: Text('#${order.orderNo} — ${order.clientName ?? order.clientId}'),
                  subtitle: Text(
                    order.vehiclePlate ?? order.vehicleId,
                    style: AppFonts.mono(const TextStyle(color: AppColors.textMuted, letterSpacing: 0.4)),
                  ),
                  trailing: Text(
                    formatCurrency(order.grandTotal),
                    style: AppFonts.mono(const TextStyle(fontWeight: FontWeight.w700, color: AppColors.neonGreen)),
                  ),
                  onTap: () => onSelect(order),
                ),
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
  const _StatusDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.65), blurRadius: 6, spreadRadius: 1)],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFF6BFFA0), Color(0xFF12A34E)], center: Alignment(-0.3, -0.4)),
                boxShadow: [BoxShadow(color: AppColors.neonGreen.withValues(alpha: 0.4), blurRadius: 18, spreadRadius: 3)],
              ),
              padding: const EdgeInsets.all(14),
              child: Image.asset('assets/branding/logo.png'),
            ),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.textMuted), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
