class JobPlan {
  final String serviceTitle;
  final String category;
  final String description;
  final String? location;
  final String? locationAddress;
  final String scheduledDate;
  final String scheduledTime;
  final double? budget;
  final String budgetDisplay;

  const JobPlan({
    required this.serviceTitle,
    required this.category,
    required this.description,
    this.location,
    this.locationAddress,
    required this.scheduledDate,
    required this.scheduledTime,
    this.budget,
    required this.budgetDisplay,
  });

  factory JobPlan.fromJson(Map<String, dynamic> json) {
    return JobPlan(
      serviceTitle: json['serviceTitle'] as String? ?? 'Home Service',
      category: json['category'] as String? ?? 'General Handyman',
      description: json['description'] as String? ?? '',
      location: json['location'] as String?,
      locationAddress: json['locationAddress'] as String?,
      scheduledDate: json['scheduledDate'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      budget: (json['budget'] is num)
          ? (json['budget'] as num).toDouble()
          : null,
      budgetDisplay: json['budgetDisplay'] as String? ?? 'Budget not specified',
    );
  }

  JobPlan copyWith({
    String? serviceTitle,
    String? category,
    String? description,
    String? location,
    String? locationAddress,
    String? scheduledDate,
    String? scheduledTime,
    double? budget,
    String? budgetDisplay,
  }) {
    return JobPlan(
      serviceTitle: serviceTitle ?? this.serviceTitle,
      category: category ?? this.category,
      description: description ?? this.description,
      location: location ?? this.location,
      locationAddress: locationAddress ?? this.locationAddress,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      budget: budget ?? this.budget,
      budgetDisplay: budgetDisplay ?? this.budgetDisplay,
    );
  }

  Map<String, dynamic> toJson() => {
    'serviceTitle': serviceTitle,
    'category': category,
    'description': description,
    'location': location,
    'locationAddress': locationAddress,
    'scheduledDate': scheduledDate,
    'scheduledTime': scheduledTime,
    'budget': budget,
    'budgetDisplay': budgetDisplay,
  };
}

class ReasoningStep {
  final String stepKey;
  final String title;
  final String subtitle;
  final String status; // 'completed', 'in_progress', 'pending'

  const ReasoningStep({
    required this.stepKey,
    required this.title,
    required this.subtitle,
    this.status = 'pending',
  });

  factory ReasoningStep.fromJson(Map<String, dynamic> json) {
    return ReasoningStep(
      stepKey: json['stepKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  ReasoningStep copyWith({
    String? stepKey,
    String? title,
    String? subtitle,
    String? status,
  }) {
    return ReasoningStep(
      stepKey: stepKey ?? this.stepKey,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
    );
  }
}

class PlanningAnalyzeResult {
  final bool success;
  final bool isLocationMissing;
  final List<String> missingFields;
  final String clarificationQuestion;
  final JobPlan jobPlan;
  final List<ReasoningStep> progressSteps;
  final int latencyMs;
  final int tokensUsed;
  final String model;

  const PlanningAnalyzeResult({
    required this.success,
    required this.isLocationMissing,
    required this.missingFields,
    required this.clarificationQuestion,
    required this.jobPlan,
    required this.progressSteps,
    required this.latencyMs,
    required this.tokensUsed,
    required this.model,
  });

  factory PlanningAnalyzeResult.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['progressSteps'] as List<dynamic>? ?? [];
    final steps = rawSteps
        .map((s) => ReasoningStep.fromJson(s as Map<String, dynamic>))
        .toList();
    final rawMissing = json['missingFields'] as List<dynamic>? ?? [];
    final missing = rawMissing.map((m) => m.toString()).toList();

    return PlanningAnalyzeResult(
      success: json['success'] as bool? ?? true,
      isLocationMissing: json['isLocationMissing'] as bool? ?? false,
      missingFields: missing,
      clarificationQuestion:
          json['clarificationQuestion'] as String? ??
          'Where do you need the service? We need your location to find providers who cover your area.',
      jobPlan: JobPlan.fromJson(json['jobPlan'] as Map<String, dynamic>? ?? {}),
      progressSteps: steps,
      latencyMs: json['latencyMs'] as int? ?? 0,
      tokensUsed: json['tokensUsed'] as int? ?? 0,
      model: json['model'] as String? ?? 'gpt-4o-mini',
    );
  }
}
