class AuthUser {
  final String id;
  final String fullName;
  final String? email;
  final String role; // owner | manager | technician
  final String shopId;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.role,
    required this.shopId,
    this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String,
        fullName: json['fullName'] as String,
        email: json['email'] as String?,
        role: json['role'] as String,
        shopId: json['shopId'] as String,
      );

  bool get canManage => role == 'owner' || role == 'manager';
}
