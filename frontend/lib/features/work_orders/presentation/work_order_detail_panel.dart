import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/pit_stop_stepper.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/work_orders_provider.dart';
import '../data/work_order_model.dart';

const _nextStatus = {'draft': 'completed', 'completed': 'paid', 'paid': null};
const _paymentMethods = ['cash', 'card', 'bank_transfer', 'other'];

String _statusLabel(AppLocalizations l, String status) => switch (status) {
      'draft' => l.draft,
      'completed' => l.completed,
      'paid' => l.paid,
      _ => status,
    };

String _paymentMethodLabel(AppLocalizations l, String method) => switch (method) {
      'cash' => l.cash,
      'card' => l.card,
      'bank_transfer' => l.bankTransfer,
      'other' => l.other,
      _ => method,
    };

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
      final l = AppLocalizations.of(context)!;
      paymentMethod = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(l.paymentMethodTitle),
          children: _paymentMethods
              .map((m) => SimpleDialogOption(onPressed: () => Navigator.pop(context, m), child: Text(_paymentMethodLabel(l, m))))
              .toList(),
        ),
      );
      if (paymentMethod == null) return;
    }

    try {
      await ref.read(workOrdersRepositoryProvider).updateStatus(order.id, status: next, paymentMethod: paymentMethod);
      ref.invalidate(workOrderDetailProvider(order.id));
      ref.invalidate(workOrdersListProvider);
      // TODO: fire the Lottie confetti / checkered-flag burst here on success,
      // e.g. showing a transient overlay — this is the moment the game
      // wants a payoff for the mechanic advancing a work order.
    } catch (e) {
      if (context.mounted) _showError(context, e);
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final dl = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dl.deleteWorkOrderTitle),
          content: Text(dl.deleteWorkOrderBody(order.orderNo)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(dl.cancel)),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text(dl.delete)),
          ],
        );
      },
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
    final l = AppLocalizations.of(context)!;
    final next = _nextStatus[order.status];

    return Scaffold(
      appBar: AppBar(
        title: Text(l.orderNo(order.orderNo)),
        actions: [
          IconButton(icon: const Icon(Icons.print), tooltip: l.printPdf, onPressed: () => _printPdf(context, ref)),
          if (canManage && order.status == 'draft')
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: l.edit,
              onPressed: () => context.push('/work-orders/${order.id}/edit'),
            ),
          if (canManage && order.status == 'draft')
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l.delete,
              onPressed: () => _delete(context, ref),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (order.paymentMethod != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Chip(label: Text(_paymentMethodLabel(l, order.paymentMethod!))),
            ),
          PitStopStepper(
            status: order.status,
            nextLabel: next == null ? null : l.markAs(_statusLabel(l, next)),
            onAdvance: () => _advanceStatus(context, ref),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.clientLabel(order.clientName ?? order.clientId)),
                  Text(l.vehicleLabel(
                    '${order.vehiclePlate ?? order.vehicleId} ${order.vehicleMake ?? ''} ${order.vehicleModel ?? ''}'.trim(),
                  )),
                  if (order.mileageAtService != null) Text(l.mileageAtService(order.mileageAtService!)),
                  Text(l.dateLabel(order.createdAt.toLocal().toString().split('.').first)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(l.lineItems, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final item in order.items)
                  ListTile(
                    title: Text(item.description),
                    subtitle: Text('${item.quantity} x ${formatCurrency(item.unitPrice)}'),
                    trailing: Text(formatCurrency(item.lineTotal), style: AppFonts.mono(const TextStyle(fontWeight: FontWeight.w600))),
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
                  _TotalRow(l.subtotal, order.subtotal),
                  if (kOrderTaxAndDiscountVisible && order.discountAmount > 0) _TotalRow(l.discount, -order.discountAmount),
                  if (kOrderTaxAndDiscountVisible) _TotalRow(l.taxWithRate(order.taxRate.toString()), order.taxAmount),
                  const Divider(),
                  _TotalRow(l.grandTotal, order.grandTotal, emphasize: true),
                ],
              ),
            ),
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(l.notes, style: Theme.of(context).textTheme.titleMedium),
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
    final style = AppFonts.mono(TextStyle(
      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
      fontSize: emphasize ? 16 : 13,
      color: emphasize ? AppColors.neonGreen : AppColors.textHigh,
    ));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$label: ', style: AppFonts.body(style.copyWith(color: emphasize ? AppColors.textHigh : AppColors.textMuted))),
          SizedBox(width: 90, child: Text(formatCurrency(amount), style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
}
