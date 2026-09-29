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
  });