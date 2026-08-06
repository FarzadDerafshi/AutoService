import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_completeness_bar.dart';
import '../../../core/widgets/search_autocomplete_field.dart';
import '../../../generated/app_localizations.dart';
import '../../clients/application/clients_provider.dart';
import '../../clients/data/client_model.dart';
import '../../clients/presentation/client_form_sheet.dart';
import '../application/vehicles_provider.dart';
import '../data/vehicle_model.dart';

class VehicleFormResult {
  final Map<String, dynamic> data;
  const VehicleFormResult(this.data);
}

Future<VehicleFormResult?> showVehicleFormSheet(
  BuildContext context, {
  Vehicle? existing,
  String? presetClientId,
  Client? presetClient,
  String? initialPlate,
}) {
  return showModalBottomSheet<VehicleFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VehicleFormSheet(
      existing: existing,
      presetClientId: presetClientId,
      presetClient: presetClient,
      initialPlate: initialPlate,
    ),
  );
}

class _VehicleFormSheet extends ConsumerStatefulWidget {
  const _VehicleFormSheet({this.existing, this.presetClientId, this.presetClient, this.initialPlate});
  final Vehicle? existing;
  final String? presetClientId;
  final Client? presetClient;
  final String? initialPlate;

  @override
  ConsumerState<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _engineType;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  late final TextEditingController _chassisNo;
  late final TextEditingController _engineNo;
  late final TextEditingController _color;
  final _ownerFieldKey = GlobalKey<SearchAutocompleteFieldState<Client>>();
  final _makeFieldKey = GlobalKey<SearchAutocompleteFieldState<String>>();
  final _modelFieldKey = GlobalKey<SearchAutocompleteFieldState<String>>();
  String? _clientId;
  Client? _selectedClient;
  String _make = '';
  String _model = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _clientId = e?.clientId ?? widget.presetClient?.id ?? widget.presetClientId;
    if (widget.presetClient != null) {
      _selectedClient = widget.presetClient;
    } else if (_clientId != null) {
      // Only the id is known (editing an existing vehicle, or a bare
      // presetClientId string) — fetch the name for display once the sheet
      // is up rather than blocking the first frame on it.
      Future.microtask(_loadOwnerName);
    }
    _make = e?.make ?? '';
    _model = e?.model ?? '';
    _plate = TextEditingController(text: e?.licensePlate ?? widget.initialPlate ?? '');
    _engineType = TextEditingController(text: e?.engineType ?? '');
    _year = TextEditingController(text: e?.year?.toString() ?? '');
    _mileage = TextEditingController(text: e?.currentMileageKm.toString() ?? '');
    _chassisNo = TextEditingController(text: e?.chassisNo ?? '');
    _engineNo = TextEditingController(text: e?.engineNo ?? '');
    _color = TextEditingController(text: e?.color ?? '');
    for (final c in [_plate, _engineType, _year, _mileage, _chassisNo, _engineNo, _color]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    _engineType.dispose();
    _year.dispose();
    _mileage.dispose();
    _chassisNo.dispose();
    _engineNo.dispose();
    _color.dispose();
    super.dispose();
  }

  Future<void> _loadOwnerName() async {
    try {
      final client = await ref.read(clientsRepositoryProvider).getById(_clientId!);
      if (!mounted) return;
      setState(() => _selectedClient = client);
      _ownerFieldKey.currentState?.setText(client.fullName);
    } catch (_) {
      // Leave the field blank — _clientId is still set, so submitting with
      // the unchanged owner still works; the user can re-search to fix the
      // display if they notice.
    }
  }

  List<(String, bool)> _completenessFields(AppLocalizations l) => [
        (l.owner, _clientId != null),
        (l.licensePlate, _plate.text.trim().isNotEmpty),
        (l.make, _make.trim().isNotEmpty),
        (l.model, _model.trim().isNotEmpty),
        (l.engineLabel, _engineType.text.trim().isNotEmpty),
        (l.yearFieldLabel, _year.text.trim().isNotEmpty),
        (l.currentMileageKmLabel, _mileage.text.trim().isNotEmpty),
        (l.chassisNoLabel, _chassisNo.text.trim().isNotEmpty),
        (l.engineNoLabel, _engineNo.text.trim().isNotEmpty),
        (l.colorLabel, _color.text.trim().isNotEmpty),
      ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      VehicleFormResult({
        'clientId': _clientId,
        'licensePlate': _plate.text.trim(),
        'make': _make.trim(),
        'model': _model.trim(),
        'engineType': _engineType.text.trim(),
        if (_year.text.trim().isNotEmpty) 'year': int.tryParse(_year.text.trim()),
        if (_mileage.text.trim().isNotEmpty) 'currentMileageKm': int.tryParse(_mileage.text.trim()),
        'chassisNo': _chassisNo.text.trim(),
        'engineNo': _engineNo.text.trim(),
        'color': _color.text.trim(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? l10n.newVehicle : l10n.editVehicle, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ProfileCompletenessBar(fields: _completenessFields(l10n), title: l10n.garageCompleteness),
            const SizedBox(height: 16),
            SearchAutocompleteField<Client>(
              key: _ownerFieldKey,
              labelText: l10n.owner,
              initialText: _selectedClient?.fullName ?? '',
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
                _clientId = client.id;
              }),
              validator: (_) => _clientId == null ? l10n.selectAnOwner : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              decoration: InputDecoration(labelText: l10n.licensePlate),
              textCapitalization: TextCapitalization.characters,
              style: AppFonts.mono(const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.6)),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchAutocompleteField<String>(
                    key: _makeFieldKey,
                    labelText: l10n.make,
                    initialText: _make,
                    search: (q) => ref.read(vehiclesRepositoryProvider).searchMakes(q),
                    displayStringForOption: (s) => s,
                    createOptionLabel: l10n.useTypedTextOption,
                    onCreateNew: (typedText) async => typedText,
                    onChanged: (text) => setState(() => _make = text),
                    onSelected: (value) => setState(() {
                      _make = value;
                      // A model typed for the old make is likely stale once
                      // the make changes — clear it, same as the work-order
                      // form clears vehicle when its client changes.
                      _model = '';
                      _modelFieldKey.currentState?.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchAutocompleteField<String>(
                    key: _modelFieldKey,
                    labelText: l10n.model,
                    initialText: _model,
                    search: (q) => ref.read(vehiclesRepositoryProvider).searchModels(q, make: _make.isEmpty ? null : _make),
                    displayStringForOption: (s) => s,
                    createOptionLabel: l10n.useTypedTextOption,
                    onCreateNew: (typedText) async => typedText,
                    onChanged: (text) => setState(() => _model = text),
                    onSelected: (value) => setState(() => _model = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _engineType,
                    decoration: InputDecoration(labelText: l10n.engineLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    decoration: InputDecoration(labelText: l10n.yearFieldLabel),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mileage,
              decoration: InputDecoration(labelText: l10n.currentMileageKmLabel),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _chassisNo,
                    decoration: InputDecoration(labelText: l10n.chassisNoLabel),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _engineNo,
                    decoration: InputDecoration(labelText: l10n.engineNoLabel),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _color,
              decoration: InputDecoration(labelText: l10n.colorLabel),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
