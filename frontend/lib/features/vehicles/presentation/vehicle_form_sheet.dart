import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
            Text(widget.existing == null ? 'New Vehicle' : 'Edit Vehicle', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            clientsAsync.when(
              data: (clients) => DropdownButtonFormField<String>(
                initialValue: clients.any((c) => c.id == _clientId) ? _clientId : null,
                decoration: const InputDecoration(labelText: 'Owner'),
                items: clients.map((c) => DropdownMenuItem(value: c.id, child: Text(c.fullName))).toList(),
                onChanged: (value) => setState(() => _clientId = value),
                validator: (v) => v == null ? 'Select an owner' : null,
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load clients: $e'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              decoration: const InputDecoration(labelText: 'License plate'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _make, decoration: const InputDecoration(labelText: 'Make'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _model, decoration: const InputDecoration(labelText: 'Model'))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _engineType,
                    decoration: const InputDecoration(labelText: 'Engine'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _year,
                    decoration: const InputDecoration(labelText: 'Year'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _mileage,
              decoration: const InputDecoration(labelText: 'Current mileage (km)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
