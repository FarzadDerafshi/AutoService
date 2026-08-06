import '../../../core/api/api_client.dart';
import '../../../shared/models/paginated_response.dart';
import 'vehicle_model.dart';

class VehicleHistory {
  final Vehicle vehicle;
  final List<Map<String, dynamic>> workOrders;
  const VehicleHistory({required this.vehicle, required this.workOrders});
}

class VehiclesRepository {
  VehiclesRepository(this._client);
  final ApiClient _client;

  Future<PaginatedResponse<Vehicle>> list({String? plate, String? clientId, int page = 1, int pageSize = 50}) async {
    final response = await _client.dio.get('/vehicles', queryParameters: {
      if (plate != null && plate.isNotEmpty) 'plate': plate,
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      'page': page,
      'pageSize': pageSize,
    });
    return PaginatedResponse.fromJson(response.data as Map<String, dynamic>, Vehicle.fromJson);
  }

  /// Lightweight, debounce-friendly search for the master-data Autocomplete
  /// pattern (see DECISIONS.md) — shop-wide by plate/make/model, optionally
  /// narrowed to one owner, and joins the owner's name for display.
  Future<List<Vehicle>> search(String q, {String? clientId}) async {
    final response = await _client.dio.get('/vehicles/search', queryParameters: {
      'q': q,
      'clientId': ?clientId,
    });
    return (response.data as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> getById(String id) async {
    final response = await _client.dio.get('/vehicles/$id');
    return Vehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<VehicleHistory> history(String id) async {
    final response = await _client.dio.get('/vehicles/$id/history');
    final body = response.data as Map<String, dynamic>;
    return VehicleHistory(
      vehicle: Vehicle.fromJson(body['vehicle'] as Map<String, dynamic>),
      workOrders: (body['workOrders'] as List).cast<Map<String, dynamic>>(),
    );
  }

  Future<Vehicle> create(Map<String, dynamic> input) async {
    final response = await _client.dio.post('/vehicles', data: input);
    return Vehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<Vehicle> update(String id, Map<String, dynamic> input) async {
    final response = await _client.dio.patch('/vehicles/$id', data: input);
    return Vehicle.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.dio.delete('/vehicles/$id');
}
