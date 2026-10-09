class ProviderItem {
  final String id;
  final String userId;
  final String fullName;
  final String? profilePhotoUrl;
  final String phone;
  final String category;
  final String? skills;
  final String? services;
  final String? experience;
  final String? serviceAreas;
  final double hourlyRate;
  final double rating;
  final int reviewCount;
  final double distanceKm;
  final double? latitude;
  final double? longitude;
  final String? bio;
  final bool isActive;
  final bool isVerified;
  final String? verificationStatus;
  final String? verificationDocumentType;
  final String? verificationDocumentUrl;

  const ProviderItem({
    required this.id,
    required this.userId,
    required this.fullName,
    this.profilePhotoUrl,
    required this.phone,
    required this.category,
    this.skills,
    this.services,
    this.experience,
    this.serviceAreas,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    this.latitude,
    this.longitude,
    this.bio,
    this.isActive = true,
    this.isVerified = false,
    this.verificationStatus,
    this.verificationDocumentType,
    this.verificationDocumentUrl,
  });

  factory ProviderItem.fromJson(Map<String, dynamic> json) {
    return ProviderItem(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      fullName: json['fullName'] as String? ?? 'Specialist',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      phone: json['phone'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      skills: json['skills'] as String?,
      services: json['services'] as String?,
      experience: json['experience'] as String?,
      serviceAreas: json['serviceAreas'] as String?,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 2500.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 12,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 2.4,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      bio: json['bio'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isVerified: (json['isVerified'] as bool?) ?? false,
      verificationStatus: json['verificationStatus'] as String?,
      verificationDocumentType: json['verificationDocumentType'] as String?,
      verificationDocumentUrl: json['verificationDocumentUrl'] as String?,
    );
  }

  ProviderItem copyWith({
    double? distanceKm,
    bool? isVerified,
    String? verificationStatus,
  }) {
    return ProviderItem(
      id: id,
      userId: userId,
      fullName: fullName,
      profilePhotoUrl: profilePhotoUrl,
      phone: phone,
      category: category,
      skills: skills,
      services: services,
      experience: experience,
      serviceAreas: serviceAreas,
      hourlyRate: hourlyRate,
      rating: rating,
      reviewCount: reviewCount,
      distanceKm: distanceKm ?? this.distanceKm,
      latitude: latitude,
      longitude: longitude,
      bio: bio,
      isActive: isActive,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationDocumentType: verificationDocumentType,
      verificationDocumentUrl: verificationDocumentUrl,
    );
  }

  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return 'SP';
  }
}
