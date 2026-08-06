class Vehicle {
  final String id;
  final String clientId;
  final String licensePlate;
  final String? make;
  final String? model;
  final String? engineType;
  final int? year;
  final int currentMileageKm;
  final String? chassisNo;
  final String? engineNo;
  final String? color;

  const Vehicle({
    required this.id,
    required this.clientId,
    required this.licensePlate,
    required this.currentMileageKm,
    this.make,
    this.model,
    this.engineType,
    this.year,
    this.chassisNo,
    this.engineNo,
    this.color,
  });

  String get displayName => [make, model].where((s) => s != null && s.isNotEmpty).join(' ');

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        clientId: json['clientId'] as String,
        licensePlate: json['licensePlate'] as String,
        make: json['make'] as String?,
        model: json['model'] as String?,
        engineType: json['engineType'] as String?,
        year: json['year'] as int?,
        currentMileageKm: json['currentMileageKm'] as int? ?? 0,
        chassisNo: json['chassisNo'] as String?,
        engineNo: json['engineNo'] as String?,
        color: json['color'] as String?,
      );
}
