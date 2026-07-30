import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/work_order_model.dart';
import '../data/work_orders_repository.dart';

final workOrdersRepositoryProvider = Provider<WorkOrdersRepository>((ref) {
  return WorkOrdersRepository(ref.watch(apiClientProvider));
});

final selectedWorkOrderIdProvider = StateProvider.autoDispose<String?>((ref) => null);

final workOrdersStatusFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final workOrdersListProvider = FutureProvider.autoDispose<List<WorkOrder>>((ref) async {
  final status = ref.watch(workOrdersStatusFilterProvider);
  final result = await ref.watch(workOrdersRepositoryProvider).list(status: status, pageSize: 100);
  return result.data;
});

final workOrderDetailProvider = FutureProvider.autoDispose.family<WorkOrder, String>((ref, id) async {
  return ref.watch(workOrdersRepositoryProvider).getById(id);
});
