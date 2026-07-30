import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/master_detail_scaffold.dart';
import '../application/work_orders_provider.dart';
import 'work_order_detail_panel.dart';
import 'work_orders_master_list.dart';

/// Wires the shared MasterDetailScaffold to the work-orders feature.
/// Wide layouts keep selection state in [selectedWorkOrderIdProvider] and
/// render the detail panel inline; narrow layouts push a full-screen route
/// on selection instead (see WorkOrderDetailScreen), since the scaffold
/// itself only renders the master panel below the breakpoint.
class WorkOrdersScreen extends ConsumerWidget {
  const WorkOrdersScreen({this.initialId, super.key});
  final String? initialId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialId != null && ref.read(selectedWorkOrderIdProvider) != initialId) {
      Future.microtask(() => ref.read(selectedWorkOrderIdProvider.notifier).state = initialId);
    }

    final selectedId = ref.watch(selectedWorkOrderIdProvider);
    final isWide = MediaQuery.of(context).size.width >= MasterDetailScaffold.desktopBreakpoint;

    return MasterDetailScaffold(
      masterPanel: WorkOrdersMasterList(
        selectedId: selectedId,
        onCreate: () => context.push('/work-orders/new'),
        onSelect: (order) {
          if (isWide) {
            ref.read(selectedWorkOrderIdProvider.notifier).state = order.id;
          } else {
            context.push('/work-orders/${order.id}');
          }
        },
      ),
      detailPanel: selectedId == null
          ? null
          : WorkOrderDetailPanel(
              workOrderId: selectedId,
              onClose: () => ref.read(selectedWorkOrderIdProvider.notifier).state = null,
            ),
    );
  }
}

/// Full-screen detail route used on narrow layouts (and when navigating in
/// from outside — vehicle history, global search) — reuses WorkOrderDetailPanel.
class WorkOrderDetailScreen extends StatelessWidget {
  const WorkOrderDetailScreen({required this.workOrderId, super.key});
  final String workOrderId;

  @override
  Widget build(BuildContext context) {
    return WorkOrderDetailPanel(workOrderId: workOrderId);
  }
}
