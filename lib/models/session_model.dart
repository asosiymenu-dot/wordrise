class UserSession {
  final int id;
  final String? deviceName;
  final String? ipAddress;
  final DateTime? lastActiveAt;
  final bool isOnline;
  final DateTime expiresAt;
  final DateTime createdAt;

  UserSession({
    required this.id,
    this.deviceName,
    this.ipAddress,
    this.lastActiveAt,
    required this.isOnline,
    required this.expiresAt,
    required this.createdAt,
  });

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      id: json['id'] as int,
      deviceName: json['device_name'] as String?,
      ipAddress: json['ip_address'] as String?,
      lastActiveAt: json['last_active_at'] != null ? DateTime.parse(json['last_active_at']) : null,
      isOnline: json['is_online'] == true || json['is_online'] == 1,
      expiresAt: DateTime.parse(json['expires_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
