import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/search_autocomplete_field.dart';
import '../../../generated/app_localizations.dart';
import '../../catalog/application/catalog_provider.dart';
import '../../catalog/data/catalog_item_model.dart';
import '../../catalog/presentation/catalog_item_form_sheet.dart';
import '../../clients/application/clients_provider.dart';
import '../../clients/data/client_model.dart';
import '../../clients/presentation/client_form_sheet.dart';
import '../../vehicles/application/vehicles_provider.dart';
import '../../vehicles/data/vehicle_model.dart';
import '../../vehicles/presentation/vehicle_form_sheet.dart';
import '../application/work_orders_provider.dart';
import '../data/work_order_item_model.dart';
import '../data/work_order_model.dart';

class _ItemRow {
  String? catalogItemId;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemRow({this.catalogItemId, String description = '', String quantity = '1', String unitPrice = '0'})
      : description = TextEditingController(text: description),
        quantity = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: unitPrice);

  void dispose() {
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }

  double get lineTotal => (double.tryParse(quantity.text) ?? 0) * (double.tryParse(unitPrice.text) ?? 0);
}

class WorkOrderFormScreen extends ConsumerStatefulWidget {
  const WorkOrderFormScreen({this.existing, super.key});
  final WorkOrder? existing;

  @override
  ConsumerState<WorkOrderFormScreen> createState() => _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends ConsumerState<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<SearchAutocompleteFieldState<Client>>();
  final _vehicleFieldKey = GlobalKey<SearchAutocompleteFieldState<Vehicle>>();
  final _catalogFieldKey = GlobalKey<SearchAutocompleteFieldState<CatalogItem>>();
  Client? _selectedClient;
  Vehicle? _selectedVehicle;
  late final TextEditingController _mileage;
  late final TextEditingController _discount;
  late final TextEditingController _taxRate;
  late final TextEditingController _notes;
  final List<_ItemRow> _items = [];
  bool _saving = false;
  String? _errorMessage;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mileage = TextEditingController(text: e?.mileageAtService?.toString() ?? '');
    _discount = TextEditingController(text: e?.discountAmount.toString() ?? '0');
    _taxRate = TextEditingController(text: e?.taxRate.toString() ?? '0');
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e != null && e.items.isNotEmpty) {
      for (final item in e.items) {
        _items.add(_ItemRow(
          catalogItemId: item.catalogItemId,
          description: item.description,
          quantity: item.quantity.toString(),
          unitPrice: item.unitPrice.toString(),
        ));
      }
    } else {
      _items.add(_ItemRow());
    }
  }

  @override
  void dispose() {
    _mileage.dispose();
    _discount.dispose();
    _taxRate.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  double get _subtotal => _items.fold(0, (sum, i) => sum + i.lineTotal);
  double get _discountValue => double.tryParse(_discount.text) ?? 0;
  double get _taxRateValue => double.tryParse(_taxRate.text) ?? 0;
  double get _taxable => (_subtotal - _discountValue).clamp(0, double.infinity);
  double get _taxAmount => _taxable * (_taxRateValue / 100);
  double get _grandTotal => _taxable + _taxAmount;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && (_selectedClient == null || _selectedVehicle == null)) {
      setState(() => _errorMessage = l10n.selectClientAndVehicle);
      return;
    }
    if (_items.isEmpty) {
      setState(() => _errorMessage = l10n.addAtLeastOneLineItem);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final items = _items
        .map((row) => WorkOrderItem(
              catalogItemId: row.catalogItemId,
              description: row.description.text.trim(),
              quantity: double.tryParse(row.quantity.text) ?? 0,
              unitPrice: double.tryParse(row.unitPrice.text) ?? 0,
            ).toJson())
        .toList();

    try {
      final repo = ref.read(workOrdersRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!.id, {
          if (_mileage.text.trim().isNotEmpty) 'mileageAtService': int.tryParse(_mileage.text.trim()),
          'items': items,
          'discountAmount': _discountValue,
          'taxRate': _taxRateValue,
          'notes': _notes.text.trim(),
        });
        ref.invalidate(workOrderDetailProvider(widget.existing!.id));
      } else {
        await repo.create({
          'clientId': _selectedClient!.id,
          'vehicleId': _selectedVehicle!.id,
          if (_mileage.text.trim().isNotEmpty) 'mileageAtService': int.tryParse(_mileage.text.trim()),
          'items': items,
          'discountAmount': _discountValue,
          'taxRate': _taxRateValue,
          'notes': _notes.text.trim(),
        });
      }
      ref.invalidate(workOrdersListProvider);
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _errorMessage = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? l10n.editWorkOrderTitle(widget.existing!.orderNo) : l10n.newWorkOrder),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEdit) ...[
              Text(l10n.clientLabel(widget.existing!.clientName ?? widget.existing!.clientId)),
              Text(l10n.vehicleLabel(widget.existing!.vehiclePlate ?? widget.existing!.vehicleId)),
              const SizedBox(height: 12),
            ] else ...[
              SearchAutocompleteField<Client>(
                key: _clientFieldKey,
                labelText: l10n.client,
                search: (q) => ref.read(clientsRepositoryProvider).search(q),
                displayStringForOption: (c) => c.fullName,
                subtitleForOption: (c) =>
                    [c.phone, c.email].where((s) => s != null && s.isNotEmpty).join(' · '),
                createOptionLabel: l10n.addNewClientOption,
                onCreateNew: (typedText) async {
                  final result = await showClientFormSheet(context, initialFullName: typedText);
                  if (result == null) return null;
                  final created = await ref.read(clientsRepositoryProvider).create(result.data);
                  ref.invalidate(clientsListProvider);
                  return created;
                },
                onSelected: (client) => setState(() {
                  _selectedClient = client;
                  if (_selectedVehicle != null && _selectedVehicle!.clientId != client.id) {
                    _selectedVehicle = null;
                    _vehicleFieldKey.currentState?.clear();
                  }
                }),
                validator: (_) => _selectedClient == null ? l10n.selectAClient : null,
              ),
              if (_selectedClient != null &&
                  ((_selectedClient!.phone?.isNotEmpty ?? false) || (_selectedClient!.email?.isNotEmpty ?? false)))
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    [
                      if (_selectedClient!.phone?.isNotEmpty ?? false) '${l10n.phoneLabel}: ${_selectedClient!.phone}',
                      if (_selectedClient!.email?.isNotEmpty ?? false) '${l10n.email}: ${_selectedClient!.email}',
                    ].join('   '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              SearchAutocompleteField<Vehicle>(
                key: _vehicleFieldKey,
                labelText: l10n.vehicle,
                search: (q) => ref.read(vehiclesRepositoryProvider).search(q, clientId: _selectedClient?.id),
                displayStringForOption: (v) => '${v.licensePlate} — ${v.displayName}',
                subtitleForOption: (v) =>
                    (v.clientName == null || v.clientName == _selectedClient?.fullName) ? null : '${l10n.owner}: ${v.clientName}',
                createOptionLabel: l10n.addNewVehicleOption,
                onCreateNew: (typedText) async {
                  final result = await showVehicleFormSheet(
                    context,
                    presetClient: _selectedClient,
                    initialPlate: typedText,
                  );
                  if (result == null) return null;
                  final created = await ref.read(vehiclesRepositoryProvider).create(result.data);
                  ref.invalidate(vehiclesListProvider);
                  return created;
                },
                onSelected: (vehicle) async {
                  setState(() => _selectedVehicle = vehicle);
                  if (_selectedClient == null || _selectedClient!.id != vehicle.clientId) {
                    final client = await ref.read(clientsRepositoryProvider).getById(vehicle.clientId);
                    if (!mounted) return;
                    setState(() => _selectedClient = client);
                    _clientFieldKey.currentState?.setText(client.fullName);
                  }
                },
                validator: (_) => _selectedVehicle == null ? l10n.selectAVehicle : null,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _mileage,
              decoration: InputDecoration(labelText: l10n.mileageAtServiceLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.lineItems, style: Theme.of(context).textTheme.titleMedium),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemRow())),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.customLineItem),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SearchAutocompleteField<CatalogItem>(
              key: _catalogFieldKey,
              labelText: l10n.fromCatalog,
              search: (q) => ref.read(catalogRepositoryProvider).search(q),
              displayStringForOption: (c) => c.name,
              subtitleForOption: (c) => '${c.type == 'service' ? l10n.service : l10n.part} · ${formatCurrency(c.defaultUnitPrice)}',
              createOptionLabel: l10n.addNewCatalogItemOption,
              onCreateNew: (typedText) async {
                final result = await showCatalogItemFormSheet(context, initialName: typedText);
                if (result == null) return null;
                final created = await ref.read(catalogRepositoryProvider).create(result.data);
                ref.invalidate(catalogListProvider);
                return created;
              },
              onSelected: (item) {
                setState(() {
                  _items.add(_ItemRow(
                    catalogItemId: item.id,
                    description: item.name,
                    quantity: '1',
                    unitPrice: item.defaultUnitPrice.toString(),
                  ));
                });
                _catalogFieldKey.currentState?.clear();
              },
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _items.length; i++) _buildItemRow(l10n, i),
            const SizedBox(height: 16),
            if (kOrderTaxAndDiscountVisible) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discount,
                      decoration: InputDecoration(labelText: l10n.discount),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _taxRate,
                      decoration: InputDecoration(labelText: l10n.taxRateLabel),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(controller: _notes, decoration: InputDecoration(labelText: l10n.notes), maxLines: 2),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${l10n.subtotal}: ${formatCurrency(_subtotal)}'),
                    if (kOrderTaxAndDiscountVisible) Text('${l10n.taxLabel}: ${formatCurrency(_taxAmount)}'),
                    Text('${l10n.grandTotal}: ${formatCurrency(_grandTotal)}',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(AppLocalizations l10n, int index) {
    final row = _items[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: row.description,
              decoration: InputDecoration(labelText: l10n.descriptionLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.quantity,
              decoration: InputDecoration(labelText: l10n.qtyLabel),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.unitPrice,
              decoration: InputDecoration(labelText: l10n.priceLabel),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _items.length > 1
                ? () => setState(() {
                      row.dispose();
                      _items.removeAt(index);
                    })
                : null,
          ),
        ],
      ),
    );
  }
}
