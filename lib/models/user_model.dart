class UserModel {
  final int? id;
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? provider;

  UserModel({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.photoUrl,
    this.provider,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'provider': provider,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id'] ?? ''}'),
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      provider: json['provider'] as String?,
    );
  }
}

class AuthSessionModel {
  final int id;
  final bool isActive;
  final String? createdAt;
  final String? lastSeenAt;
  final String? ipAddress;
  final String? deviceName;
  final String? platform;
  final String? deviceId;

  AuthSessionModel({
    required this.id,
    required this.isActive,
    this.createdAt,
    this.lastSeenAt,
    this.ipAddress,
    this.deviceName,
    this.platform,
    this.deviceId,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    final device = json['device'] as Map<String, dynamic>? ?? {};
    return AuthSessionModel(
      id: json['id'] as int,
      isActive: json['is_active'] as bool? ?? false,
      createdAt: json['created_at'] as String?,
      lastSeenAt: json['last_seen_at'] as String?,
      ipAddress: json['ip_address'] as String?,
      deviceName: device['name'] as String?,
      platform: device['platform'] as String?,
      deviceId: device['device_id'] as String?,
    );
  }
}
