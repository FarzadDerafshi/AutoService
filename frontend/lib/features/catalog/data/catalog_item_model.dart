class CatalogItem {
  final String id;
  final String type; // service | part
  final String? sku;
  final String name;
  final String unit;
  final double defaultUnitPrice;
  final bool isActive;

  const CatalogItem({
    required this.id,
    required this.type,
    required this.name,
    required this.unit,
    required this.defaultUnitPrice,
    required this.isActive,
    this.sku,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> json) => CatalogItem(
        id: json['id'] as String,
        type: json['type'] as String,
        sku: json['sku'] as String?,
        name: json['name'] as String,
        unit: json['unit'] as String? ?? 'unit',
        defaultUnitPrice: (json['defaultUnitPrice'] as num).toDouble(),
        isActive: json['isActive'] as bool? ?? true,
      );
}
