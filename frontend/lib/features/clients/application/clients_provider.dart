import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/client_model.dart';
import '../data/clients_repository.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(apiClientProvider));
});

final clientSearchProvider = StateProvider.autoDispose<String>((ref) => '');

final clientsListProvider = FutureProvider.autoDispose<List<Client>>((ref) async {
  final search = ref.watch(clientSearchProvider);
  final repo = ref.watch(clientsRepositoryProvider);
  final result = await repo.list(search: search);
  return result.data;
});

/// All clients, unfiltered — used by pickers (e.g. the work-order form)
/// where the whole list is needed regardless of the clients screen's search box.
final allClientsProvider = FutureProvider.autoDispose<List<Client>>((ref) async {
  final result = await ref.watch(clientsRepositoryProvider).list(pageSize: 100);
  return result.data;
});
