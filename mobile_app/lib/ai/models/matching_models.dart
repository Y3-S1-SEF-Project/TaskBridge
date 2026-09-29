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