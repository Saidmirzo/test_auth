class UserModel {
  final String? name;
  final String? email;
  final String? phone;
  final String? photoUrl;
  final String? provider;

  UserModel({this.name, this.email, this.phone, this.photoUrl, this.provider});

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,
      'provider': provider,
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      name: json['name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      photoUrl: json['photoUrl'] as String?,
      provider: json['provider'] as String?,
    );
  }
}
