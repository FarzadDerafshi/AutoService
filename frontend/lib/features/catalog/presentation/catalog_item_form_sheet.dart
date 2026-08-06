import 'package:flutter/material.dart';
import '../../../generated/app_localizations.dart';
import '../data/catalog_item_model.dart';

class CatalogItemFormResult {
  final Map<String, dynamic> data;
  const CatalogItemFormResult(this.data);
}

Future<CatalogItemFormResult?> showCatalogItemFormSheet(
  BuildContext context, {
  CatalogItem? existing,
  String? initialName,
}) {
  return showModalBottomSheet<CatalogItemFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CatalogItemFormSheet(existing: existing, initialName: initialName),
  );
}

class _CatalogItemFormSheet extends StatefulWidget {
  const _CatalogItemFormSheet({this.existing, this.initialName});
  final CatalogItem? existing;
  final String? initialName;

  @override
  State<_CatalogItemFormSheet> createState() => _CatalogItemFormSheetState();
}

class _CatalogItemFormSheetState extends State<_CatalogItemFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _type;
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _unit;
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'service';
    _name = TextEditingController(text: e?.name ?? widget.initialName ?? '');
    _sku = TextEditingController(text: e?.sku ?? '');
    _unit = TextEditingController(text: e?.unit ?? '');
    _price = TextEditingController(text: e?.defaultUnitPrice.toString() ?? '0');
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      CatalogItemFormResult({
        'type': _type,
        'name': _name.text.trim(),
        'sku': _sku.text.trim(),
        'unit': _unit.text.trim(),
        'defaultUnitPrice': double.tryParse(_price.text.trim()) ?? 0,
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
            Text(widget.existing == null ? l10n.newCatalogItem : l10n.editCatalogItem,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'service', label: Text(l10n.service)),
                ButtonSegment(value: 'part', label: Text(l10n.part)),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: InputDecoration(labelText: l10n.nameLabel),
              validator: (v) => (v == null || v.trim().isEmpty) ? l10n.required : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _sku, decoration: InputDecoration(labelText: l10n.skuOptional)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _unit, decoration: InputDecoration(labelText: l10n.unit))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: InputDecoration(labelText: l10n.defaultPrice),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? l10n.enterValidNumber : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: Text(l10n.save)),
          ],
        ),
      ),
    );
  }
}
