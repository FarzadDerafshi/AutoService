import 'dart:async';
import 'package:flutter/material.dart';

class _Option<T> {
  final T? item;
  final bool isCreateNew;
  const _Option.item(T this.item) : isCreateNew = false;
  const _Option.createNew()
      : item = null,
        isCreateNew = true;
}

/// The standard "search-as-you-type Autocomplete with quick-create" field
/// for master-data pickers (client, vehicle, catalog item, ...) across
/// transaction forms. See DECISIONS.md's "Master-data search-autocomplete
/// pattern" section for the rationale and how to wire a new field.
///
/// [search] is called (debounced, only once [minChars] characters are
/// typed) to fetch matching options. The dropdown always appends a
/// trailing "+ Add new ..." row once [minChars] is reached; selecting it
/// calls [onCreateNew], which should open a quick-create UI and return the
/// newly-created item (or null if the user cancelled). Either a picked
/// search result or a freshly-created item is then routed through
/// [onSelected].
class SearchAutocompleteField<T extends Object> extends StatefulWidget {
  const SearchAutocompleteField({
    super.key,
    required this.labelText,
    required this.search,
    required this.displayStringForOption,
    required this.onSelected,
    required this.createOptionLabel,
    required this.onCreateNew,
    this.subtitleForOption,
    this.initialText = '',
    this.validator,
    this.onChanged,
    this.minChars = 2,
    this.debounce = const Duration(milliseconds: 300),
  });

  final String labelText;
  final Future<List<T>> Function(String query) search;
  final String Function(T option) displayStringForOption;
  final void Function(T option) onSelected;
  final String Function(String typedText) createOptionLabel;
  final Future<T?> Function(String typedText) onCreateNew;
  final String? Function(T option)? subtitleForOption;
  final String initialText;
  final String? Function(String?)? validator;
  /// Fires on every keystroke, not just on selection — for fields whose raw
  /// typed text is itself a valid value with nothing else to select (e.g.
  /// vehicle make/model, which aren't a separate entity with an id; see
  /// DECISIONS.md). Most fields backed by a real entity don't need this,
  /// since their value only becomes meaningful once [onSelected] fires.
  final void Function(String text)? onChanged;
  final int minChars;
  final Duration debounce;

  @override
  State<SearchAutocompleteField<T>> createState() => SearchAutocompleteFieldState<T>();
}

class SearchAutocompleteFieldState<T extends Object> extends State<SearchAutocompleteField<T>> {
  Timer? _debounceTimer;
  TextEditingController? _fieldController;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Imperatively overwrite the field's displayed text — used when another
  /// field's selection auto-fills this one (e.g. picking a vehicle fills
  /// the owner field).
  void setText(String text) => _fieldController?.text = text;

  /// Clears the field — used after adding a catalog line item, so the
  /// search box is ready for the next one.
  void clear() => _fieldController?.clear();

  Future<Iterable<_Option<T>>> _optionsBuilder(TextEditingValue value) {
    _debounceTimer?.cancel();
    final query = value.text.trim();
    _lastQuery = query;
    if (query.length < widget.minChars) return Future.value(const []);

    final completer = Completer<Iterable<_Option<T>>>();
    _debounceTimer = Timer(widget.debounce, () async {
      if (completer.isCompleted) return;
      try {
        final results = await widget.search(query);
        if (!completer.isCompleted) {
          completer.complete([...results.map((r) => _Option<T>.item(r)), const _Option.createNew()]);
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete([const _Option.createNew()]);
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<_Option<T>>(
      initialValue: TextEditingValue(text: widget.initialText),
      optionsBuilder: _optionsBuilder,
      displayStringForOption: (option) =>
          option.isCreateNew ? _lastQuery : widget.displayStringForOption(option.item as T),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _fieldController = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(labelText: widget.labelText),
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280, maxWidth: 480),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final option = list[index];
                  if (option.isCreateNew) {
                    return ListTile(
                      leading: const Icon(Icons.add_circle_outline),
                      title: Text(widget.createOptionLabel(_lastQuery)),
                      onTap: () => onSelected(option),
                    );
                  }
                  final item = option.item as T;
                  final subtitle = widget.subtitleForOption?.call(item);
                  return ListTile(
                    title: Text(widget.displayStringForOption(item)),
                    subtitle: (subtitle == null || subtitle.isEmpty) ? null : Text(subtitle),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (option) async {
        if (!option.isCreateNew) {
          widget.onSelected(option.item as T);
          return;
        }
        final typedText = _lastQuery;
        final created = await widget.onCreateNew(typedText);
        if (created == null) return;
        _fieldController?.text = widget.displayStringForOption(created);
        widget.onSelected(created);
      },
    );
  }
}
