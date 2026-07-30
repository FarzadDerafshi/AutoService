import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/application/auth_provider.dart';
import '../data/catalog_item_model.dart';
import '../data/catalog_repository.dart';

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository(ref.watch(apiClientProvider));
});

final catalogTypeFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

final catalogListProvider = FutureProvider.autoDispose<List<CatalogItem>>((ref) async {
  final type = ref.watch(catalogTypeFilterProvider);
  return ref.watch(catalogRepositoryProvider).list(type: type);
});
