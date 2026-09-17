class AuthUser {
  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.address,
    this.location,
    this.preferences,
    this.profilePhotoUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? address;
  final String? location;
  final String? preferences;
  final String? profilePhotoUrl;

  AuthUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? location,
    String? preferences,
    String? profilePhotoUrl,
  }) =>
      AuthUser(
        id: id,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        location: location ?? this.location,
        preferences: preferences ?? this.preferences,
        profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      );

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String?,
        location: json['location'] as String?,
        preferences: json['preferences'] as String?,
        profilePhotoUrl: json['profilePhotoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'address': address,
        'location': location,
        'preferences': preferences,
        'profilePhotoUrl': profilePhotoUrl,
      };
}

class OtpChallenge {
  const OtpChallenge({
    required this.email,
    required this.message,
    required this.expiresAt,
    this.resendAt,
  });

  final String email;
  final String message;
  final DateTime expiresAt;
  final DateTime? resendAt;

  factory OtpChallenge.fromJson(Map<String, dynamic> json) => OtpChallenge(
        email: json['email'] as String? ?? '',
        message: json['message'] as String? ?? '',
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : DateTime.now().add(const Duration(minutes: 10)),
        resendAt: json['resendAt'] != null
            ? DateTime.parse(json['resendAt'] as String)
            : DateTime.now().add(const Duration(seconds: 60)),
      );
}

class AuthException implements Exception {
  const AuthException(this.message, {this.status});
  final String message;
  final int? status;

  @override
  String toString() => message;
}
