import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_completeness_bar.dart';
import '../../../generated/app_localizations.dart';
import '../../clients/application/clients_provider.dart';
import '../data/vehicle_model.dart';

class VehicleFormResult {
  final Map<String, dynamic> data;
  const VehicleFormResult(this.data);
}

Future<VehicleFormResult?> showVehicleFormSheet(BuildContext context, {Vehicle? existing, String? presetClientId}) {
  return showModalBottomSheet<VehicleFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VehicleFormSheet(existing: existing, presetClientId: presetClientId),
  );
}

class _VehicleFormSheet extends ConsumerStatefulWidget {
  const _VehicleFormSheet({this.existing, this.presetClientId});
  final Vehicle? existing;
  final String? presetClientId;

  @override
  ConsumerState<_VehicleFormSheet> createState() => _VehicleFormSheetState();
}

class _VehicleFormSheetState extends ConsumerState<_VehicleFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _plate;
  late final TextEditingController _make;
  late final TextEditingController _model;
  late final TextEditingController _engineType;
  late final TextEditingController _year;
  late final TextEditingController _mileage;
  String? _clientId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _clientId = e?.clientId ?? widget.presetClientId;
    _plate = TextEditingController(text: e?.licensePlate ?? '');
    _make = TextEditingController(text: e?.make ?? '');
    _model = TextEditingController(text: e?.model ?? '');
    _engineType = TextEditingController(text: e?.engineType ?? '');
    _year = TextEditingController(text: e?.year?.toString() ?? '');
    _mileage = TextEditingController(text: e?.currentMileageKm.toString() ?? '');
    for (final c in [_plate, _make, _model, _engineType, _year, _mileage]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _plate.dispose();
    _make.dispose();
    _model.dispose();
    _engineType.dispose();
    _year.dispose();
    _mileage.dispose();
    super.dispose();
  }

  List<(String, bool)> get _completenessFields => [
        ('owner', _clientId != null),
        ('license plate', _plate.text.trim().isNotEmpty),
        ('make', _make.text.trim().isNotEmpty),
        ('model', _model.text.trim().isNotEmpty),
        ('engine type', _engineType.text.trim().isNotEmpty),
        ('year', _year.text.trim().isNotEmpty),
        ('mileage', _mileage.text.trim().isNotEmpty),
      ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      VehicleFormResult({
        'clientId': _clientId,
        'licensePlate': _plate.text.trim(),
        'make': _make.text.trim(),
        'model': _model.text.trim(),
        'engineType': _engineType.text.trim(),
        if (_year.text.trim().isNotEmpty) 'year': int.tryParse(_year.text.trim()),
        if (_mileage.text.trim().isNotEmpty) 'currentMileageKm': int.tryParse(_mileage.text.trim()),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clientsAsync = ref.watch(allClientsProvider);

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
            ProfileCompletenessBar(fields: _completenessFields, title: 'Profile Completeness'),
            const SizedBox(height: 16),
            clientsAsync.when(
              data: (clients) => DropdownButtonFormField<String>(
                initialValue: clients.any((c) => c.id == _clientId) ? _clientId : null,
                decoration: InputDecoration(labelText: l10n.owner),
                items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))).toList(),
                onChanged: (value) => setState(() => _clientId = value),
                validator: (v) => v == null ? l10n.selectAnOwner : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(l10n.failedToLoadClients(e)),
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
              children: [
                Expanded(child: TextFormField(controller: _make, decoration: InputDecoration(labelText: l10n.make))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _model, decoration: InputDecoration(labelText: l10n.model))),
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
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
