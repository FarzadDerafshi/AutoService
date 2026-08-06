import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../generated/app_localizations.dart';
import '../../auth/application/auth_provider.dart';
import '../application/clients_provider.dart';
import 'client_form_sheet.dart';

class ClientsScreen extends ConsumerWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final clientsAsync = ref.watch(clientsListProvider);
    final canManage = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.clients),
        actions: [
          IconButton.filled(
            tooltip: l.newClient,
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await showClientFormSheet(context);
              if (result == null) return;
              try {
                await ref.read(clientsRepositoryProvider).create(result.data);
                ref.invalidate(clientsListProvider);
              } catch (e) {
                if (context.mounted) _showError(context, e);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l.searchByNamePhoneOrEmail,
                isDense: true,
              ),
              onChanged: (value) => ref.read(clientSearchProvider.notifier).state = value,
            ),
          ),
        ),
      ),
      body: AsyncValueWidget(
        value: clientsAsync,
        onRetry: () => ref.invalidate(clientsListProvider),
        data: (clients) {
          if (clients.isEmpty) {
            return Center(child: Text(l.noClientsYet));
          }
          return ListView.separated(
            itemCount: clients.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final client = clients[index];
              return ListTile(
                title: Text(client.fullName),
                subtitle: Text([client.phone, client.email].where((s) => s != null && s.isNotEmpty).join(' · ')),
                onTap: () => context.push('/vehicles?clientId=${client.id}'),
                trailing: canManage
                    ? PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final result = await showClientFormSheet(context, existing: client);
                            if (result == null) return;
                            try {
                              await ref.read(clientsRepositoryProvider).update(client.id, result.data);
                              ref.invalidate(clientsListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          } else if (action == 'delete') {
                            try {
                              await ref.read(clientsRepositoryProvider).delete(client.id);
                              ref.invalidate(clientsListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'edit', child: Text(l.edit)),
                          PopupMenuItem(value: 'delete', child: Text(l.delete)),
                        ],
                      )
                    : null,
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
