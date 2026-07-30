class WorkOrderItem {
  final String? id;
  final String? catalogItemId;
  final String description;
  final double quantity;
  final double unitPrice;
  final double lineTotal;

  const WorkOrderItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    this.id,
    this.catalogItemId,
    this.lineTotal = 0,
  });

  factory WorkOrderItem.fromJson(Map<String, dynamic> json) => WorkOrderItem(
        id: json['id'] as String?,
        catalogItemId: json['catalogItemId'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        unitPrice: (json['unitPrice'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        if (catalogItemId != null) 'catalogItemId': catalogItemId,
        'description': description,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  WorkOrderItem copyWith({String? description, double? quantity, double? unitPrice}) => WorkOrderItem(
        id: id,
        catalogItemId: catalogItemId,
        description: description ?? this.description,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}
