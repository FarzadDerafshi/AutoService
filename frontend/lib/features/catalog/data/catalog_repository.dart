import '../../../core/api/api_client.dart';
import 'catalog_item_model.dart';

class CatalogRepository {
  CatalogRepository(this._client);
  final ApiClient _client;

  Future<List<CatalogItem>> list({String? type, String? search}) async {
    final response = await _client.dio.get('/catalog', queryParameters: {
      if (type != null && type.isNotEmpty) 'type': type,
      if (search != null && search.isNotEmpty) 'search': search,
    });
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List).map((e) => CatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Lightweight, debounce-friendly search for the master-data Autocomplete
  /// pattern (see DECISIONS.md) — capped, active items only, unlike [list].
  Future<List<CatalogItem>> search(String q, {String? type}) async {
    final response = await _client.dio.get('/catalog/search', queryParameters: {
      'q': q,
      'type': ?type,
    });
    return (response.data as List).map((e) => CatalogItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<CatalogItem> create(Map<String, dynamic> input) async {
    final response = await _client.dio.post('/catalog', data: input);
    return CatalogItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<CatalogItem> update(String id, Map<String, dynamic> input) async {
    final response = await _client.dio.patch('/catalog/$id', data: input);
    return CatalogItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.dio.delete('/catalog/$id');
}
