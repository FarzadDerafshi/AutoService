class ShopProfile {
  final String id;
  final String name;
  final String? taxId;
  final String? taxOffice;
  final String? address;
  final String? phone;
  final String? email;
  final String? logoUrl;

  const ShopProfile({
    required this.id,
    required this.name,
    this.taxId,
    this.taxOffice,
    this.address,
    this.phone,
    this.email,
    this.logoUrl,
  });

  factory ShopProfile.fromJson(Map<String, dynamic> json) => ShopProfile(
        id: json['id'] as String,
        name: json['name'] as String,
        taxId: json['taxId'] as String?,
        taxOffice: json['taxOffice'] as String?,
        address: json['address'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );
}
