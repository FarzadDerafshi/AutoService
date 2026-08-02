class Invite {
  final String id;
  final String role;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final DateTime? revokedAt;
  final DateTime createdAt;

  const Invite({
    required this.id,
    required this.role,
    required this.expiresAt,
    required this.createdAt,
    this.usedAt,
    this.revokedAt,
  });

  factory Invite.fromJson(Map<String, dynamic> json) => Invite(
        id: json['id'] as String,
        role: json['role'] as String,
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        usedAt: json['usedAt'] != null ? DateTime.parse(json['usedAt'] as String) : null,
        revokedAt: json['revokedAt'] != null ? DateTime.parse(json['revokedAt'] as String) : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  bool get isRevoked => revokedAt != null;
  bool get isUsed => usedAt != null;
  bool get isExpired => !isUsed && !isRevoked && DateTime.now().isAfter(expiresAt);
  bool get isPending => !isUsed && !isRevoked && !isExpired;
}

class InvitePublicInfo {
  final String shopName;
  final String role;
  const InvitePublicInfo({required this.shopName, required this.role});

  factory InvitePublicInfo.fromJson(Map<String, dynamic> json) => InvitePublicInfo(
        shopName: json['shopName'] as String,
        role: json['role'] as String,
      );
}
