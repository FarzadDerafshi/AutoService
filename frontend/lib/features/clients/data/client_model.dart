class Client {
  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? address;
  final String? taxId;
  final String? notes;

  const Client({
    required this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.address,
    this.taxId,
    this.notes,
  });

  factory Client.fromJson(Map<String, dynamic> json) => Client(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        taxId: json['taxId'] as String?,
        notes: json['notes'] as String?,
      );
}
