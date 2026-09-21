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
    this.isProvider = false,
    this.providerCategory,
    this.providerSkills,
    this.providerServices,
    this.providerExperience,
    this.providerCertifications,
    this.providerServiceAreas,
    this.providerAvailability,
    this.providerBio,
    this.providerEarnings,
    this.providerHourlyRate,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String? address;
  final String? location;
  final String? preferences;
  final String? profilePhotoUrl;
  final bool isProvider;
  final String? providerCategory;
  final String? providerSkills;
  final String? providerServices;
  final String? providerExperience;
  final String? providerCertifications;
  final String? providerServiceAreas;
  final String? providerAvailability;
  final String? providerBio;
  final double? providerEarnings;
  final double? providerHourlyRate;

  AuthUser copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? address,
    String? location,
    String? preferences,
    String? profilePhotoUrl,
    bool? isProvider,
    String? providerCategory,
    String? providerSkills,
    String? providerServices,
    String? providerExperience,
    String? providerCertifications,
    String? providerServiceAreas,
    String? providerAvailability,
    String? providerBio,
    double? providerEarnings,
    double? providerHourlyRate,
  }) => AuthUser(
    id: id,
    fullName: fullName ?? this.fullName,
    email: email ?? this.email,
    phone: phone ?? this.phone,
    address: address ?? this.address,
    location: location ?? this.location,
    preferences: preferences ?? this.preferences,
    profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
    isProvider: isProvider ?? this.isProvider,
    providerCategory: providerCategory ?? this.providerCategory,
    providerSkills: providerSkills ?? this.providerSkills,
    providerServices: providerServices ?? this.providerServices,
    providerExperience: providerExperience ?? this.providerExperience,
    providerCertifications:
        providerCertifications ?? this.providerCertifications,
    providerServiceAreas: providerServiceAreas ?? this.providerServiceAreas,
    providerAvailability: providerAvailability ?? this.providerAvailability,
    providerBio: providerBio ?? this.providerBio,
    providerEarnings: providerEarnings ?? this.providerEarnings,
    providerHourlyRate: providerHourlyRate ?? this.providerHourlyRate,
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
    isProvider: (json['isProvider'] as bool?) ?? false,
    providerCategory: json['providerCategory'] as String?,
    providerSkills: json['providerSkills'] as String?,
    providerServices: json['providerServices'] as String?,
    providerExperience: json['providerExperience'] as String?,
    providerCertifications: json['providerCertifications'] as String?,
    providerServiceAreas: json['providerServiceAreas'] as String?,
    providerAvailability: json['providerAvailability'] as String?,
    providerBio: json['providerBio'] as String?,
    providerEarnings: (json['providerEarnings'] is num)
        ? (json['providerEarnings'] as num).toDouble()
        : 54000.0,
    providerHourlyRate: (json['providerHourlyRate'] is num)
        ? (json['providerHourlyRate'] as num).toDouble()
        : 2500.0,
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
    'isProvider': isProvider,
    'providerCategory': providerCategory,
    'providerSkills': providerSkills,
    'providerServices': providerServices,
    'providerExperience': providerExperience,
    'providerCertifications': providerCertifications,
    'providerServiceAreas': providerServiceAreas,
    'providerAvailability': providerAvailability,
    'providerBio': providerBio,
    'providerEarnings': providerEarnings,
    'providerHourlyRate': providerHourlyRate,
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
