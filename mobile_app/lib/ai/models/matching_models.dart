import 'planning_models.dart';
import '../../home/models/provider_item.dart';

class ScoreBreakdown {
  final double skillScore;
  final double locationScore;
  final double budgetScore;
  final double ratingScore;

  const ScoreBreakdown({
    required this.skillScore,
    required this.locationScore,
    required this.budgetScore,
    required this.ratingScore,
  });

  factory ScoreBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoreBreakdown(
      skillScore: (json['skillScore'] as num?)?.toDouble() ?? 0.0,
      locationScore: (json['locationScore'] as num?)?.toDouble() ?? 0.0,
      budgetScore: (json['budgetScore'] as num?)?.toDouble() ?? 0.0,
      ratingScore: (json['ratingScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MatchedProvider {
  final String providerId;
  final String userId;
  final String fullName;
  final String? profilePhotoUrl;
  final String phone;
  final String category;
  final String? skills;
  final String? serviceAreas;
  final double distanceKm;
  final double hourlyRate;
  final double rating;
  final int reviewCount;
  final int matchScore; // e.g. 98
  final String aiMatchReason;
  final ScoreBreakdown scoreBreakdown;
  final bool isVerified;
  final String? verificationStatus;
  final String? verificationDocumentType;
  final String? verificationDocumentUrl;

  const MatchedProvider({
    required this.providerId,
    required this.userId,
    required this.fullName,
    this.profilePhotoUrl,
    required this.phone,
    required this.category,
    this.skills,
    this.serviceAreas,
    required this.distanceKm,
    required this.hourlyRate,
    required this.rating,
    required this.reviewCount,
    required this.matchScore,
    required this.aiMatchReason,
    required this.scoreBreakdown,
    this.isVerified = false,
    this.verificationStatus,
    this.verificationDocumentType,
    this.verificationDocumentUrl,
  });

  factory MatchedProvider.fromJson(Map<String, dynamic> json) {
    return MatchedProvider(
      providerId: json['providerId'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'TaskBridge Specialist',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      phone: json['phone'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      skills: json['skills'] as String?,
      serviceAreas: json['serviceAreas'] as String?,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 2.4,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 2500.0,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 12,
      matchScore: json['matchScore'] as int? ?? 90,
      aiMatchReason:
          json['aiMatchReason'] as String? ??
          'Matched based on expertise and proximity to your location.',
      scoreBreakdown: ScoreBreakdown.fromJson(
        json['scoreBreakdown'] as Map<String, dynamic>? ?? {},
      ),
      isVerified: (json['isVerified'] as bool?) ?? false,
      verificationStatus: json['verificationStatus'] as String?,
      verificationDocumentType: json['verificationDocumentType'] as String?,
      verificationDocumentUrl: json['verificationDocumentUrl'] as String?,
    );
  }

  ProviderItem toProviderItem() {
    return ProviderItem(
      id: providerId,
      userId: userId,
      fullName: fullName,
      profilePhotoUrl: profilePhotoUrl,
      phone: phone,
      category: category,
      skills: skills,
      serviceAreas: serviceAreas,
      hourlyRate: hourlyRate,
      rating: rating,
      reviewCount: reviewCount,
      distanceKm: distanceKm,
      isVerified: isVerified,
      verificationStatus: verificationStatus,
      verificationDocumentType: verificationDocumentType,
      verificationDocumentUrl: verificationDocumentUrl,
    );
  }
}

class MatchingResponse {
  final bool success;
  final JobPlan jobPlan;
  final List<MatchedProvider> matchedProviders;
  final int candidatePoolCount;
  final int latencyMs;
  final int tokensUsed;
  final String model;

  const MatchingResponse({
    required this.success,
    required this.jobPlan,
    required this.matchedProviders,
    required this.candidatePoolCount,
    required this.latencyMs,
    required this.tokensUsed,
    required this.model,
  });

  factory MatchingResponse.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['matchedProviders'] as List<dynamic>? ?? [];
    final list = rawProviders
        .map((p) => MatchedProvider.fromJson(p as Map<String, dynamic>))
        .toList();

    return MatchingResponse(
      success: json['success'] as bool? ?? true,
      jobPlan: JobPlan.fromJson(json['jobPlan'] as Map<String, dynamic>? ?? {}),
      matchedProviders: list,
      candidatePoolCount: json['candidatePoolCount'] as int? ?? list.length,
      latencyMs: json['latencyMs'] as int? ?? 0,
      tokensUsed: json['tokensUsed'] as int? ?? 0,
      model: json['model'] as String? ?? 'gpt-4o-mini',
    );
  }
}
