import '../../../core/api/api_client.dart';
import '../../../shared/models/paginated_response.dart';
import 'client_model.dart';

class ClientsRepository {
  ClientsRepository(this._client);
  final ApiClient _client;

  Future<PaginatedResponse<Client>> list({String? search, int page = 1, int pageSize = 50}) async {
    final response = await _client.dio.get('/clients', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      'page': page,
      'pageSize': pageSize,
    });
    return PaginatedResponse.fromJson(response.data as Map<String, dynamic>, Client.fromJson);
  }

  /// Lightweight, debounce-friendly search for the master-data Autocomplete
  /// pattern (see DECISIONS.md) — capped and unpaginated, unlike [list].
  Future<List<Client>> search(String q) async {
    final response = await _client.dio.get('/clients/search', queryParameters: {'q': q});
    return (response.data as List).map((e) => Client.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Client> getById(String id) async {
    final response = await _client.dio.get('/clients/$id');
    return Client.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Client> create(Map<String, dynamic> input) async {
    final response = await _client.dio.post('/clients', data: input);
    return Client.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Client> update(String id, Map<String, dynamic> input) async {
    final response = await _client.dio.patch('/clients/$id', data: input);
    return Client.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.dio.delete('/clients/$id');
}
