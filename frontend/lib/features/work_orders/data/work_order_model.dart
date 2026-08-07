import 'work_order_item_model.dart';

class WorkOrder {
  final String id;
  final int orderNo;
  final String clientId;
  final String vehicleId;
  final int? mileageAtService;
  final String status; // draft | completed | paid
  final String? paymentMethod;
  final double subtotal;
  final double discountAmount;
  final double taxRate;
  final double taxAmount;
  final double grandTotal;
  final String? notes;
  final List<WorkOrderItem> items;
  final DateTime createdAt;
  // "YYYY-MM-DD" — kept as a plain string, never parsed into a DateTime.
  // This is a calendar date (backdatable, printed on the slip), not a
  // moment in time; parsing it would mean picking a timezone to interpret
  // it in, which a plain date has no meaningful one of. See the backend's
  // config/db.ts DATE type-parser override for the matching server-side
  // half of this.
  final String serviceDate;

  // Denormalized fields present on list/summary responses only.
  final String? clientName;
  final String? vehiclePlate;
  final String? vehicleMake;
  final String? vehicleModel;

  const WorkOrder({
    required this.id,
    required this.orderNo,
    required this.clientId,
    required this.vehicleId,
    required this.status,
    required this.subtotal,
    required this.discountAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.grandTotal,
    required this.items,
    required this.createdAt,
    required this.serviceDate,
    this.mileageAtService,
    this.paymentMethod,
    this.notes,
    this.clientName,
    this.vehiclePlate,
    this.vehicleMake,
    this.vehicleModel,
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) => WorkOrder(
    id: json['id'] as String,
    orderNo: json['orderNo'] as int,
    clientId: json['clientId'] as String,
    vehicleId: json['vehicleId'] as String,
    mileageAtService: json['mileageAtService'] as int?,
    status: json['status'] as String,
    paymentMethod: json['paymentMethod'] as String?,
    subtotal: (json['subtotal'] as num).toDouble(),
    discountAmount: (json['discountAmount'] as num).toDouble(),
    taxRate: (json['taxRate'] as num).toDouble(),
    taxAmount: (json['taxAmount'] as num).toDouble(),
    grandTotal: (json['grandTotal'] as num).toDouble(),
    notes: json['notes'] as String?,
    items: (json['items'] as List? ?? [])
        .map((e) => WorkOrderItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    serviceDate: json['serviceDate'] as String,
    clientName: json['clientName'] as String?,
    vehiclePlate: json['vehiclePlate'] as String?,
    vehicleMake: json['vehicleMake'] as String?,
    vehicleModel: json['vehicleModel'] as String?,
  );
}
