import 'package:flutter/material.dart';
import '../../../core/widgets/profile_completeness_bar.dart';
import '../../../generated/app_localizations.dart';
import '../data/client_model.dart';

class ClientFormResult {
  final Map<String, dynamic> data;
  const ClientFormResult(this.data);
}

Future<ClientFormResult?> showClientFormSheet(BuildContext context, {Client? existing, String? initialFullName}) {
  return showModalBottomSheet<ClientFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ClientFormSheet(existing: existing, initialFullName: initialFullName),
  );
}

class _ClientFormSheet extends StatefulWidget {
  const _ClientFormSheet({this.existing, this.initialFullName});
  final Client? existing;
  final String? initialFullName;

  @override
  State<_ClientFormSheet> createState() => _ClientFormSheetState();
}

class _ClientFormSheetState extends State<_ClientFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _fullName = TextEditingController(text: e?.fullName ?? widget.initialFullName ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _address = TextEditingController(text: e?.address ?? '');
    _notes = TextEditingController(text: e?.notes ?? '');
    for (final c in [_fullName, _phone, _email, _address, _notes]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  List<(String, bool)> _completenessFields(AppLocalizations l) => [
        (l.fullNameLabel, _fullName.text.trim().isNotEmpty),
        (l.phoneLabel, _phone.text.trim().isNotEmpty),
        (l.email, _email.text.trim().isNotEmpty),
        (l.addressLabel, _address.text.trim().isNotEmpty),
        (l.notes, _notes.text.trim().isNotEmpty),
      ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      ClientFormResult({
        'fullName': _fullName.text.trim(),
        'phone': _phone.text.trim(),
        'email': _email.text.trim(),
        'address': _address.text.trim(),
        'notes': _notes.text.trim(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
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
            Text(widget.existing == null ? l.newClient : l.editClient, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            ProfileCompletenessBar(fields: _completenessFields(l), title: l.garageCompleteness),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fullName,
              decoration: InputDecoration(labelText: l.fullNameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _phone, decoration: InputDecoration(labelText: l.phoneLabel)),
            const SizedBox(height: 12),
            TextFormField(controller: _email, decoration: InputDecoration(labelText: l.email)),
            const SizedBox(height: 12),
            TextFormField(controller: _address, decoration: InputDecoration(labelText: l.addressLabel), maxLines: 2),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: InputDecoration(labelText: l.notes), maxLines: 2),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}
