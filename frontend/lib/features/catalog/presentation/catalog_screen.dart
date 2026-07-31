import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/catalog_provider.dart';
import 'catalog_item_form_sheet.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final itemsAsync = ref.watch(catalogListProvider);
    final typeFilter = ref.watch(catalogTypeFilterProvider);
    final canManage = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.serviceAndPartsCatalog),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String?>(
                segments: [
                  ButtonSegment(value: null, label: Text(l.all)),
                  ButtonSegment(value: 'service', label: Text(l.services)),
                  ButtonSegment(value: 'part', label: Text(l.parts)),
                ],
                selected: {typeFilter},
                onSelectionChanged: (s) => ref.read(catalogTypeFilterProvider.notifier).state = s.first,
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () async {
                final result = await showCatalogItemFormSheet(context);
                if (result == null) return;
                try {
                  await ref.read(catalogRepositoryProvider).create(result.data);
                  ref.invalidate(catalogListProvider);
                } catch (e) {
                  if (context.mounted) _showError(context, e);
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
      body: AsyncValueWidget(
        value: itemsAsync,
        onRetry: () => ref.invalidate(catalogListProvider),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text(l.noCatalogItemsYet));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                leading: Icon(item.type == 'service' ? Icons.build : Icons.settings_suggest),
                title: Text(item.name, style: item.isActive ? null : const TextStyle(color: Colors.grey)),
                subtitle: Text('${item.sku ?? ''} ${item.unit}'.trim()),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(formatCurrency(item.defaultUnitPrice)),
                    if (canManage)
                      PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final result = await showCatalogItemFormSheet(context, existing: item);
                            if (result == null) return;
                            try {
                              await ref.read(catalogRepositoryProvider).update(item.id, result.data);
                              ref.invalidate(catalogListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          } else if (action == 'delete') {
                            try {
                              await ref.read(catalogRepositoryProvider).delete(item.id);
                              ref.invalidate(catalogListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'edit', child: Text(l.edit)),
                          PopupMenuItem(value: 'delete', child: Text(l.delete)),
                        ],
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(toApiException(error).message)));
}
