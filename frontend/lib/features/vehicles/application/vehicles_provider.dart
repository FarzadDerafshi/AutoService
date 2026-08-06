import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/vehicle_model.dart';
import '../data/vehicles_repository.dart';

final vehiclesRepositoryProvider = Provider<VehiclesRepository>((ref) {
  return VehiclesRepository(ref.watch(apiClientProvider));
});

class VehiclesFilter {
  final String plate;
  final String? clientId;
  const VehiclesFilter({this.plate = '', this.clientId});

  VehiclesFilter copyWith({String? plate, String? clientId}) =>
      VehiclesFilter(plate: plate ?? this.plate, clientId: clientId ?? this.clientId);
}

final vehiclesFilterProvider = StateProvider.autoDispose<VehiclesFilter>((ref) => const VehiclesFilter());

final vehiclesListProvider = FutureProvider.autoDispose<List<Vehicle>>((ref) async {
  final filter = ref.watch(vehiclesFilterProvider);
  final repo = ref.watch(vehiclesRepositoryProvider);
  final result = await repo.list(plate: filter.plate, clientId: filter.clientId);
  return result.data;
});

final vehicleHistoryProvider = FutureProvider.autoDispose.family((ref, String vehicleId) async {
  return ref.watch(vehiclesRepositoryProvider).history(vehicleId);
});
