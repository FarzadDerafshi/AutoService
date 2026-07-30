import 'package:flutter/material.dart';
import '../data/catalog_item_model.dart';

class CatalogItemFormResult {
  final Map<String, dynamic> data;
  const CatalogItemFormResult(this.data);
}

Future<CatalogItemFormResult?> showCatalogItemFormSheet(BuildContext context, {CatalogItem? existing}) {
  return showModalBottomSheet<CatalogItemFormResult>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CatalogItemFormSheet(existing: existing),
  );
}

class _CatalogItemFormSheet extends StatefulWidget {
  const _CatalogItemFormSheet({this.existing});
  final CatalogItem? existing;

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
    _name = TextEditingController(text: e?.name ?? '');
    _sku = TextEditingController(text: e?.sku ?? '');
    _unit = TextEditingController(text: e?.unit ?? 'unit');
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
            Text(widget.existing == null ? 'New Catalog Item' : 'Edit Catalog Item',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'service', label: Text('Service')),
                ButtonSegment(value: 'part', label: Text('Part')),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _sku, decoration: const InputDecoration(labelText: 'SKU (optional)')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _unit, decoration: const InputDecoration(labelText: 'Unit'))),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Default price'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid number' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: _submit, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
