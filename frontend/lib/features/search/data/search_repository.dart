import '../../../core/api/api_client.dart';
import '../../clients/data/client_model.dart';
import '../../vehicles/data/vehicle_model.dart';
import '../../work_orders/data/work_order_model.dart';

class SearchResults {
  final List<Client> clients;
  final List<Vehicle> vehicles;
  final List<WorkOrder> workOrders;
  const SearchResults({required this.clients, required this.vehicles, required this.workOrders});

  bool get isEmpty => clients.isEmpty && vehicles.isEmpty && workOrders.isEmpty;
}

class SearchRepository {
  SearchRepository(this._client);
  final ApiClient _client;

  Future<SearchResults> search(String query) async {
    final response = await _client.dio.get('/search', queryParameters: {'q': query});
    final body = response.data as Map<String, dynamic>;
    return SearchResults(
      clients: (body['clients'] as List).map((e) => Client.fromJson(e as Map<String, dynamic>)).toList(),
      vehicles: (body['vehicles'] as List).map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList(),
      workOrders: (body['workOrders'] as List).map((e) => WorkOrder.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}
