import '../../../core/api/api_client.dart';

class RevenuePoint {
  final DateTime period;
  final double revenue;
  final int orderCount;
  const RevenuePoint({required this.period, required this.revenue, required this.orderCount});

  factory RevenuePoint.fromJson(Map<String, dynamic> json) => RevenuePoint(
        period: DateTime.parse(json['period'] as String),
        revenue: (json['revenue'] as num).toDouble(),
        orderCount: json['orderCount'] as int,
      );
}

class PaymentStatusReport {
  final int draft;
  final int completed;
  final int paid;
  final double totalOutstanding;
  const PaymentStatusReport({required this.draft, required this.completed, required this.paid, required this.totalOutstanding});

  factory PaymentStatusReport.fromJson(Map<String, dynamic> json) => PaymentStatusReport(
        draft: json['draft'] as int,
        completed: json['completed'] as int,
        paid: json['paid'] as int,
        totalOutstanding: (json['totalOutstanding'] as num).toDouble(),
      );
}

class PartsUsageRow {
  final String catalogItemId;
  final String name;
  final double totalQuantity;
  final double totalRevenue;
  const PartsUsageRow({
    required this.catalogItemId,
    required this.name,
    required this.totalQuantity,
    required this.totalRevenue,
  });

  factory PartsUsageRow.fromJson(Map<String, dynamic> json) => PartsUsageRow(
        catalogItemId: json['catalogItemId'] as String,
        name: json['name'] as String,
        totalQuantity: (json['totalQuantity'] as num).toDouble(),
        totalRevenue: (json['totalRevenue'] as num).toDouble(),
      );
}

class ReportsRepository {
  ReportsRepository(this._client);
  final ApiClient _client;

  Future<List<RevenuePoint>> revenue({DateTime? dateFrom, DateTime? dateTo, String groupBy = 'day'}) async {
    final response = await _client.dio.get('/reports/revenue', queryParameters: {
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
      'groupBy': groupBy,
    });
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List).map((e) => RevenuePoint.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PaymentStatusReport> paymentStatus({DateTime? dateFrom, DateTime? dateTo}) async {
    final response = await _client.dio.get('/reports/payment-status', queryParameters: {
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
    });
    return PaymentStatusReport.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<PartsUsageRow>> partsUsage({DateTime? dateFrom, DateTime? dateTo}) async {
    final response = await _client.dio.get('/reports/parts-usage', queryParameters: {
      if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
      if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
    });
    final body = response.data as Map<String, dynamic>;
    return (body['data'] as List).map((e) => PartsUsageRow.fromJson(e as Map<String, dynamic>)).toList();
  }
}
