import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/application/auth_provider.dart';
import '../application/work_orders_provider.dart';
import '../data/work_order_model.dart';

const _nextStatus = {'draft': 'completed', 'completed': 'paid', 'paid': null};
const _paymentMethods = ['cash', 'card', 'bank_transfer', 'other'];

class WorkOrderDetailPanel extends ConsumerWidget {
  const WorkOrderDetailPanel({required this.workOrderId, this.onClose, super.key});
  final String workOrderId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(workOrderDetailProvider(workOrderId));
    final canManage = ref.watch(currentUserProvider)?.canManage ?? false;

    return AsyncValueWidget(
      value: orderAsync,
      onRetry: () => ref.invalidate(workOrderDetailProvider(workOrderId)),
      data: (order) => _DetailContent(order: order, canManage: canManage, onClose: onClose),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.order, required this.canManage, this.onClose});
  final WorkOrder order;
  final bool canManage;
  final VoidCallback? onClose;

  Future<void> _advanceStatus(BuildContext context, WidgetRef ref) async {
    final next = _nextStatus[order.status];
    if (next == null) return;

    String? paymentMethod;
    if (next == 'paid') {
      paymentMethod = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Payment method'),
          children: _paymentMethods
              .map((m) => SimpleDialogOption(onPressed: () => Navigator.pop(context, m), child: Text(m)))
              .toList(),
        ),
      );
      if (paymentMethod == null) return;
    }

    try {
      await ref.read(workOrdersRepositoryProvider).updateStatus(order.id, status: next, paymentMethod: paymentMethod);
      ref.invalidate(workOrderDetailProvider(order.id));
      ref.invalidate(workOrdersListProvider);
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete work order?'),
        content: Text('Order #${order.orderNo} will be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(workOrdersRepositoryProvider).delete(order.id);
      ref.invalidate(workOrdersListProvider);
      onClose?.call();
      if (context.mounted && Navigator.of(context).canPop()) context.pop();
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _printPdf(BuildContext context, WidgetRef ref) async {
    final token = ref.read(authControllerProvider).valueOrNull?.token;
    if (token == null) return;
    final url = ref.read(workOrdersRepositoryProvider).pdfUrl(order.id, token);
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = _nextStatus[order.status];

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.orderNo}'),
        actions: [
          IconButton(icon: const Icon(Icons.print), tooltip: 'Print / PDF', onPressed: () => _printPdf(context, ref)),
          if (canManage && order.status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => context.push('/work-orders/${order.id}/edit'),
            ),
          if (canManage && order.status == 'draft')
            IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Delete', onPressed: () => _delete(context, ref)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(order.status.toUpperCase())),
              if (order.paymentMethod != null) Chip(label: Text(order.paymentMethod!)),
              if (next != null)
                FilledButton.icon(
                  onPressed: () => _advanceStatus(context, ref),
                  icon: const Icon(Icons.arrow_forward),
                  label: Text('Mark as $next'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Client: ${order.clientName ?? order.clientId}'),
                  Text('Vehicle: ${order.vehiclePlate ?? order.vehicleId} ${order.vehicleMake ?? ''} ${order.vehicleModel ?? ''}'),
                  if (order.mileageAtService != null) Text('Mileage at service: ${order.mileageAtService} km'),
                  Text('Date: ${order.createdAt.toLocal().toString().split('.').first}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Line Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final item in order.items)
                  ListTile(
                    title: Text(item.description),
                    subtitle: Text('${item.quantity} x ${formatCurrency(item.unitPrice)}'),
                    trailing: Text(formatCurrency(item.lineTotal)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TotalRow('Subtotal', order.subtotal),
                  if (order.discountAmount > 0) _TotalRow('Discount', -order.discountAmount),
                  _TotalRow('Tax (${order.taxRate}%)', order.taxAmount),
                  const Divider(),
                  _TotalRow('Grand Total', order.grandTotal, emphasize: true),
                ],
              ),
            ),
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(order.notes!),
          ],
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount, {this.emphasize = false});
  final String label;
  final double amount;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$label: ', style: style),
          SizedBox(width: 90, child: Text(formatCurrency(amount), style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
}
