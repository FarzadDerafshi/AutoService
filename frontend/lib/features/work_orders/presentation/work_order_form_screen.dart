import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/plate_formatter.dart';
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

enum _ExitAction { save, discard, cancel }

class _ItemRow {
  String? catalogItemId;
  // Snapshotted from the catalog item's own "unit" field at the moment it's
  // added to the order (same precedent as description/unitPrice) — not
  // user-editable here (its TextFormField is readOnly), and blank for a
  // custom (non-catalog) line item. Kept as a controller like the other
  // fields, not a plain String read via `initialValue`: `_addItem` can
  // replace `_items[0]` in place (same list slot, no widget Key change),
  // and a bare `initialValue` is only applied the first time a
  // TextFormField's State is created — it's silently ignored on later
  // rebuilds with a different value, which left this field blank for the
  // (most common) case of picking the very first line item from catalog.
  final TextEditingController unit;
  final TextEditingController description;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  _ItemRow({
    this.catalogItemId,
    String unit = '',
    String description = '',
    String quantity = '1',
    String unitPrice = '0',
  }) : unit = TextEditingController(text: unit),
       description = TextEditingController(text: description),
       quantity = TextEditingController(text: quantity),
       unitPrice = TextEditingController(text: unitPrice);

  void dispose() {
    unit.dispose();
    description.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }

  double get lineTotal =>
      (double.tryParse(quantity.text) ?? 0) *
      (double.tryParse(unitPrice.text) ?? 0);
}

class WorkOrderFormScreen extends ConsumerStatefulWidget {
  const WorkOrderFormScreen({this.existing, super.key});
  final WorkOrder? existing;

  @override
  ConsumerState<WorkOrderFormScreen> createState() =>
      _WorkOrderFormScreenState();
}

class _WorkOrderFormScreenState extends ConsumerState<WorkOrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientFieldKey = GlobalKey<SearchAutocompleteFieldState<Client>>();
  final _vehicleFieldKey = GlobalKey<SearchAutocompleteFieldState<Vehicle>>();
  Client? _selectedClient;
  Vehicle? _selectedVehicle;
  late String _serviceDate;
  late final TextEditingController _serviceDateController;
  late final TextEditingController _mileage;
  late final TextEditingController _discount;
  late final TextEditingController _taxRate;
  late final TextEditingController _notes;
  final List<_ItemRow> _items = [];
  bool _saving = false;
  String? _errorMessage;
  bool _dirty = false;

  bool get _isEdit => widget.existing != null;

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _serviceDate = e?.serviceDate ?? todayIso();
    _serviceDateController = TextEditingController(
      text: formatDateDMY(_serviceDate),
    );
    _mileage = TextEditingController(
      text: e?.mileageAtService?.toString() ?? '',
    );
    _discount = TextEditingController(
      text: e?.discountAmount.toString() ?? '0',
    );
    _taxRate = TextEditingController(text: e?.taxRate.toString() ?? '0');
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e != null && e.items.isNotEmpty) {
      for (final item in e.items) {
        _items.add(
          _ItemRow(
            catalogItemId: item.catalogItemId,
            unit: item.unit ?? '',
            description: item.description,
            quantity: item.quantity.toString(),
            unitPrice: item.unitPrice.toString(),
          ),
        );
      }
    } else {
      _items.add(_ItemRow());
    }
    // Attached after the initial seeding above so a freshly-opened form
    // (including its one default blank line item) never starts dirty.
    _mileage.addListener(_markDirty);
    _discount.addListener(_markDirty);
    _taxRate.addListener(_markDirty);
    _notes.addListener(_markDirty);
    for (final item in _items) {
      item.description.addListener(_markDirty);
      item.quantity.addListener(_markDirty);
      item.unitPrice.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _serviceDateController.dispose();
    _mileage.dispose();
    _discount.dispose();
    _taxRate.dispose();
    _notes.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem(_ItemRow row) {
    row.description.addListener(_markDirty);
    row.quantity.addListener(_markDirty);
    row.unitPrice.addListener(_markDirty);
    setState(() {
      _items.add(row);
      _dirty = true;
    });
  }

  Future<void> _pickServiceDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isoToDate(_serviceDate),
      firstDate: DateTime(2015),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _dirty = true;
      _serviceDate = dateToIso(picked);
      _serviceDateController.text = formatDateDMY(_serviceDate);
    });
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
    // Client is optional — a walk-in job can be opened against a vehicle
    // with no linked client at all. The vehicle (the app's real per-shop
    // identity key, via its unique plate) is still required.
    if (!_isEdit && _selectedVehicle == null) {
      setState(() => _errorMessage = l10n.selectAVehicle);
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
        .map(
          (row) => WorkOrderItem(
            catalogItemId: row.catalogItemId,
            description: row.description.text.trim(),
            quantity: double.tryParse(row.quantity.text) ?? 0,
            unitPrice: double.tryParse(row.unitPrice.text) ?? 0,
            unit: row.unit.text.isEmpty ? null : row.unit.text,
          ).toJson(),
        )
        .toList();

    try {
      final repo = ref.read(workOrdersRepositoryProvider);
      if (_isEdit) {
        await repo.update(widget.existing!.id, {
          if (_mileage.text.trim().isNotEmpty)
            'mileageAtService': int.tryParse(_mileage.text.trim()),
          'items': items,
          'discountAmount': _discountValue,
          'taxRate': _taxRateValue,
          'notes': _notes.text.trim(),
          'serviceDate': _serviceDate,
        });
        ref.invalidate(workOrderDetailProvider(widget.existing!.id));
      } else {
        await repo.create({
          // Omitted entirely (not sent as an explicit null) when no client
          // was selected — the backend schema treats the key as
          // optional-if-absent, not optional-if-null.
          if (_selectedClient != null) 'clientId': _selectedClient!.id,
          'vehicleId': _selectedVehicle!.id,
          if (_mileage.text.trim().isNotEmpty)
            'mileageAtService': int.tryParse(_mileage.text.trim()),
          'items': items,
          'discountAmount': _discountValue,
          'taxRate': _taxRateValue,
          'notes': _notes.text.trim(),
          'serviceDate': _serviceDate,
        });
      }
      ref.invalidate(workOrdersListProvider);
      // Clear dirty before popping — PopScope's canPop gate would otherwise
      // intercept this very pop() call and reopen the unsaved-changes dialog.
      _dirty = false;
      if (mounted) context.pop();
    } catch (e) {
      setState(() => _errorMessage = toApiException(e).message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleBackAttempt() async {
    final action = await showDialog<_ExitAction>(
      context: context,
      builder: (context) {
        final dl = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(dl.unsavedChangesTitle),
          content: Text(dl.unsavedChangesBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _ExitAction.cancel),
              child: Text(dl.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, _ExitAction.discard),
              child: Text(dl.discardChanges),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, _ExitAction.save),
              child: Text(dl.saveAsDraft),
            ),
          ],
        );
      },
    );

    switch (action) {
      case _ExitAction.save:
        await _submit();
      case _ExitAction.discard:
        _dirty = false;
        if (mounted) context.pop();
      case _ExitAction.cancel:
      case null:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAttempt();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit
                ? l10n.editWorkOrderTitle(widget.existing!.orderNo)
                : l10n.newWorkOrder,
          ),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_isEdit) ...[
                Text(
                  l10n.clientLabel(
                    widget.existing!.clientName ??
                        widget.existing!.clientId ??
                        l10n.walkInCustomer,
                  ),
                ),
                Text(
                  l10n.vehicleLabel(
                    widget.existing!.vehiclePlate != null
                        ? formatPlateDisplay(widget.existing!.vehiclePlate!)
                        : widget.existing!.vehicleId,
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                SearchAutocompleteField<Client>(
                  key: _clientFieldKey,
                  labelText: l10n.client,
                  search: (q) => ref.read(clientsRepositoryProvider).search(q),
                  displayStringForOption: (c) => c.fullName,
                  subtitleForOption: (c) => [
                    c.phone,
                    c.email,
                  ].where((s) => s != null && s.isNotEmpty).join(' · '),
                  createOptionLabel: l10n.addNewClientOption,
                  onCreateNew: (typedText) async {
                    final result = await showClientFormSheet(
                      context,
                      initialFullName: typedText,
                    );
                    if (result == null) return null;
                    final created = await ref
                        .read(clientsRepositoryProvider)
                        .create(result.data);
                    ref.invalidate(clientsListProvider);
                    return created;
                  },
                  onSelected: (client) => setState(() {
                    _dirty = true;
                    _selectedClient = client;
                    // Only clear the vehicle if it already has a *different*
                    // set owner — a walk-in vehicle (clientId null) has no
                    // real conflict, and picking a client to attach to it
                    // shouldn't wipe out the vehicle the user just chose.
                    if (_selectedVehicle != null &&
                        _selectedVehicle!.clientId != null &&
                        _selectedVehicle!.clientId != client.id) {
                      _selectedVehicle = null;
                      _vehicleFieldKey.currentState?.clear();
                    }
                  }),
                  // No validator — client is optional, a walk-in job can be
                  // opened against a vehicle with no linked client at all.
                ),
                if (_selectedClient != null &&
                    ((_selectedClient!.phone?.isNotEmpty ?? false) ||
                        (_selectedClient!.email?.isNotEmpty ?? false)))
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 4),
                    child: Text(
                      [
                        if (_selectedClient!.phone?.isNotEmpty ?? false)
                          '${l10n.phoneLabel}: ${_selectedClient!.phone}',
                        if (_selectedClient!.email?.isNotEmpty ?? false)
                          '${l10n.email}: ${_selectedClient!.email}',
                      ].join('   '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 12),
                SearchAutocompleteField<Vehicle>(
                  key: _vehicleFieldKey,
                  labelText: l10n.vehicle,
                  search: (q) => ref
                      .read(vehiclesRepositoryProvider)
                      .search(q, clientId: _selectedClient?.id),
                  displayStringForOption: (v) =>
                      '${formatPlateDisplay(v.licensePlate)} — ${v.displayName}',
                  subtitleForOption: (v) =>
                      (v.clientName == null ||
                          v.clientName == _selectedClient?.fullName)
                      ? null
                      : '${l10n.owner}: ${v.clientName}',
                  createOptionLabel: l10n.addNewVehicleOption,
                  onCreateNew: (typedText) async {
                    final result = await showVehicleFormSheet(
                      context,
                      presetClient: _selectedClient,
                      // Strip spaces before seeding the editable Plaka field
                      // — typedText can carry the display-formatted spacing
                      // from an already-selected vehicle's text (see
                      // displayStringForOption above) if the user edited it
                      // back into "create new" territory. The plate input
                      // itself must never show formatted-for-display text.
                      initialPlate: typedText.replaceAll(' ', ''),
                    );
                    if (result == null) return null;
                    final created = await ref
                        .read(vehiclesRepositoryProvider)
                        .create(result.data);
                    ref.invalidate(vehiclesListProvider);
                    return created;
                  },
                  onSelected: (vehicle) async {
                    setState(() {
                      _dirty = true;
                      _selectedVehicle = vehicle;
                    });
                    // A walk-in vehicle (clientId null) has no owner to
                    // auto-fill — leave whatever client (if any) is already
                    // selected untouched, rather than clearing it. This is
                    // what lets a walk-in car get a client attached at the
                    // order level without needing to edit the vehicle record.
                    final ownerId = vehicle.clientId;
                    if (ownerId != null &&
                        (_selectedClient == null ||
                            _selectedClient!.id != ownerId)) {
                      final client = await ref
                          .read(clientsRepositoryProvider)
                          .getById(ownerId);
                      if (!mounted) return;
                      setState(() => _selectedClient = client);
                      _clientFieldKey.currentState?.setText(client.fullName);
                    }
                  },
                  validator: (_) =>
                      _selectedVehicle == null ? l10n.selectAVehicle : null,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                readOnly: true,
                onTap: _pickServiceDate,
                controller: _serviceDateController,
                decoration: InputDecoration(
                  labelText: l10n.serviceDateLabel,
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mileage,
                decoration: InputDecoration(
                  labelText: l10n.mileageAtServiceLabel,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n.lineItems,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _addItem(_ItemRow()),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addLineItem),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (int i = 0; i < _items.length; i++) _buildItemRow(l10n, i),
              const SizedBox(height: 16),
              if (kOrderTaxAndDiscountVisible) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _discount,
                        decoration: InputDecoration(labelText: l10n.discount),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _taxRate,
                        decoration: InputDecoration(
                          labelText: l10n.taxRateLabel,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _notes,
                decoration: InputDecoration(labelText: l10n.notes),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${l10n.subtotal}: ${formatCurrency(_subtotal)}'),
                      if (kOrderTaxAndDiscountVisible)
                        Text('${l10n.taxLabel}: ${formatCurrency(_taxAmount)}'),
                      Text(
                        '${l10n.grandTotal}: ${formatCurrency(_grandTotal)}',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.save),
              ),
            ],
          ),
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
            // Keyed by the row's own identity, not its list index: index
            // shifts (a row above gets deleted) would otherwise leave this
            // widget's State — and its Autocomplete-managed field text —
            // stale, the same class of bug the Unit field's controller
            // switch fixed for a static row (see CHANGELOG v0.16.13).
            child: SearchAutocompleteField<CatalogItem>(
              key: ObjectKey(row),
              labelText: l10n.descriptionLabel,
              initialText: row.description.text,
              search: (q) => ref.read(catalogRepositoryProvider).search(q),
              displayStringForOption: (c) => c.name,
              subtitleForOption: (c) =>
                  '${c.type == 'service' ? l10n.service : l10n.part} · ${formatCurrency(c.defaultUnitPrice)}',
              createOptionLabel: l10n.addNewCatalogItemOption,
              onCreateNew: (typedText) async {
                final result = await showCatalogItemFormSheet(
                  context,
                  initialName: typedText,
                );
                if (result == null) return null;
                final created = await ref
                    .read(catalogRepositoryProvider)
                    .create(result.data);
                ref.invalidate(catalogListProvider);
                return created;
              },
              // Free typing with no selection is still a valid, uncatalogued
              // line — same as the old "Custom" flow, just inline now.
              onChanged: (text) {
                row.description.text = text;
                _markDirty();
              },
              onSelected: (item) {
                setState(() {
                  row.catalogItemId = item.id;
                  row.description.text = item.name;
                  row.unit.text = item.unit;
                  row.unitPrice.text = item.defaultUnitPrice.toString();
                });
                _markDirty();
              },
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.quantity,
              decoration: InputDecoration(labelText: l10n.qtyLabel),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n <= 0) ? l10n.enterValidNumber : null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.unit,
              readOnly: true,
              decoration: InputDecoration(labelText: l10n.unit),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              controller: row.unitPrice,
              decoration: InputDecoration(labelText: l10n.priceLabel),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return (n == null || n < 0) ? l10n.enterValidNumber : null;
              },
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _items.length > 1
                ? () => setState(() {
                    _dirty = true;
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
