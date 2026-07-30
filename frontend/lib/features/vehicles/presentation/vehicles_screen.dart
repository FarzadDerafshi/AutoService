import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../auth/application/auth_provider.dart';
import '../application/vehicles_provider.dart';
import 'vehicle_form_sheet.dart';

class VehiclesScreen extends ConsumerWidget {
  const VehiclesScreen({this.clientId, super.key});
  final String? clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync the incoming route filter into shared state once per build.
    final currentFilter = ref.read(vehiclesFilterProvider);
    if (clientId != currentFilter.clientId) {
      Future.microtask(() {
        ref.read(vehiclesFilterProvider.notifier).state = currentFilter.copyWith(clientId: clientId ?? '');
      });
    }

    final vehiclesAsync = ref.watch(vehiclesListProvider);
    final canManage = ref.watch(currentUserProvider)?.canManage ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(clientId != null ? "Client's Vehicles" : 'Vehicles'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by license plate',
                isDense: true,
              ),
              textCapitalization: TextCapitalization.characters,
              onChanged: (value) =>
                  ref.read(vehiclesFilterProvider.notifier).state = ref.read(vehiclesFilterProvider).copyWith(plate: value),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await showVehicleFormSheet(context, presetClientId: clientId);
          if (result == null) return;
          try {
            await ref.read(vehiclesRepositoryProvider).create(result.data);
            ref.invalidate(vehiclesListProvider);
          } catch (e) {
            if (context.mounted) _showError(context, e);
          }
        },
        child: const Icon(Icons.add),
      ),
      body: AsyncValueWidget(
        value: vehiclesAsync,
        onRetry: () => ref.invalidate(vehiclesListProvider),
        data: (vehicles) {
          if (vehicles.isEmpty) {
            return const Center(child: Text('No vehicles found'));
          }
          return ListView.separated(
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              return ListTile(
                leading: const Icon(Icons.directions_car),
                title: Text(vehicle.licensePlate),
                subtitle: Text([vehicle.displayName, if (vehicle.year != null) vehicle.year.toString()]
                    .where((s) => s.isNotEmpty)
                    .join(' · ')),
                onTap: () => context.push('/vehicles/${vehicle.id}/history'),
                trailing: canManage
                    ? PopupMenuButton<String>(
                        onSelected: (action) async {
                          if (action == 'edit') {
                            final result = await showVehicleFormSheet(context, existing: vehicle);
                            if (result == null) return;
                            try {
                              await ref.read(vehiclesRepositoryProvider).update(vehicle.id, result.data);
                              ref.invalidate(vehiclesListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          } else if (action == 'delete') {
                            try {
                              await ref.read(vehiclesRepositoryProvider).delete(vehicle.id);
                              ref.invalidate(vehiclesListProvider);
                            } catch (e) {
                              if (context.mounted) _showError(context, e);
                            }
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
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
