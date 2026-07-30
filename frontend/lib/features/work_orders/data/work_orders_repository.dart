import '../../../core/api/api_client.dart';
import '../../../shared/models/paginated_response.dart';
import 'work_order_model.dart';

class WorkOrdersRepository {
  WorkOrdersRepository(this._client);
  final ApiClient _client;

  Future<PaginatedResponse<WorkOrder>> list({
    String? status,
    String? clientId,
    String? vehicleId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _client.dio.get('/work-orders', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (clientId != null && clientId.isNotEmpty) 'clientId': clientId,
      if (vehicleId != null && vehicleId.isNotEmpty) 'vehicleId': vehicleId,
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      'page': page,
      'pageSize': pageSize,
    });
    return PaginatedResponse.fromJson(response.data as Map<String, dynamic>, WorkOrder.fromJson);
  }

  Future<WorkOrder> getById(String id) async {
    final response = await _client.dio.get('/work-orders/$id');
    return WorkOrder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkOrder> create(Map<String, dynamic> input) async {
    final response = await _client.dio.post('/work-orders', data: input);
    return WorkOrder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkOrder> update(String id, Map<String, dynamic> input) async {
    final response = await _client.dio.patch('/work-orders/$id', data: input);
    return WorkOrder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<WorkOrder> updateStatus(String id, {required String status, String? paymentMethod}) async {
    final response = await _client.dio.patch('/work-orders/$id/status', data: {
      'status': status,
      'paymentMethod': ?paymentMethod,
    });
    return WorkOrder.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> delete(String id) => _client.dio.delete('/work-orders/$id');

  String pdfUrl(String id, String token) => '$apiBaseUrl/work-orders/$id/pdf?token=$token';
}
