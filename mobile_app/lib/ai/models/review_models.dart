import 'dart:convert';

class JobCompletionModel {
  final String id;
  final String bookingReference;
  final String? bookingId;
  final String? providerId;
  final String providerName;
  final String? customerId;
  final String customerName;
  final String serviceTitle;
  final String category;
  final String providerNotes;
  final String? beforePhotoUrl;
  final List<String> afterPhotoUrls;
  final DateTime startedAt;
  final DateTime endedAt;
  final int durationMinutes;
  final double hourlyRate;
  final double calculatedPrice;
  final bool aiVerificationPassed;
  final int aiConfidenceScore;
  final String aiComparisonAnalysis;
  final List<String> aiVerifiedTasks;
  final List<String> aiMissingDetails;
  final String status;
  final DateTime createdAt;

  JobCompletionModel({
    required this.id,
    required this.bookingReference,
    this.bookingId,
    this.providerId,
    required this.providerName,
    this.customerId,
    required this.customerName,
    required this.serviceTitle,
    required this.category,
    required this.providerNotes,
    this.beforePhotoUrl,
    required this.afterPhotoUrls,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.hourlyRate,
    required this.calculatedPrice,
    required this.aiVerificationPassed,
    required this.aiConfidenceScore,
    required this.aiComparisonAnalysis,
    required this.aiVerifiedTasks,
    required this.aiMissingDetails,
    required this.status,
    required this.createdAt,
  });

  factory JobCompletionModel.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    return JobCompletionModel(
      id: json['id']?.toString() ?? '',
      bookingReference: json['bookingReference']?.toString() ?? '',
      bookingId: json['bookingId']?.toString(),
      providerId: json['providerId']?.toString(),
      providerName: json['providerName']?.toString() ?? 'Provider',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Customer',
      serviceTitle: json['serviceTitle']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      providerNotes: json['providerNotes']?.toString() ?? '',
      beforePhotoUrl: json['beforePhotoUrl']?.toString(),
      afterPhotoUrls: parseStringList(json['afterPhotoUrls']),
      startedAt: DateTime.tryParse(json['startedAt']?.toString() ?? '') ?? DateTime.now(),
      endedAt: DateTime.tryParse(json['endedAt']?.toString() ?? '') ?? DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 5000.0,
      calculatedPrice: (json['calculatedPrice'] as num?)?.toDouble() ?? 0.0,
      aiVerificationPassed: json['aiVerificationPassed'] == true,
      aiConfidenceScore: (json['aiConfidenceScore'] as num?)?.toInt() ?? 0,
      aiComparisonAnalysis: json['aiComparisonAnalysis']?.toString() ?? '',
      aiVerifiedTasks: parseStringList(json['aiVerifiedTasks']),
      aiMissingDetails: parseStringList(json['aiMissingDetails']),
      status: json['status']?.toString() ?? 'PendingAiReview',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class ReviewAnalyzeResponseModel {
  final bool success;
  final String bookingReference;
  final bool verificationPassed;
  final int confidenceScore;
  final String comparisonAnalysis;
  final List<String> verifiedTasks;
  final List<String> missingDetails;
  final int durationMinutes;
  final String durationFormatted;
  final double hourlyRate;
  final double calculatedPrice;
  final String priceFormatted;
  final String status;
  final String model;
  final int latencyMs;

  ReviewAnalyzeResponseModel({
    required this.success,
    required this.bookingReference,
    required this.verificationPassed,
    required this.confidenceScore,
    required this.comparisonAnalysis,
    required this.verifiedTasks,
    required this.missingDetails,
    required this.durationMinutes,
    required this.durationFormatted,
    required this.hourlyRate,
    required this.calculatedPrice,
    required this.priceFormatted,
    required this.status,
    required this.model,
    required this.latencyMs,
  });

  factory ReviewAnalyzeResponseModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    return ReviewAnalyzeResponseModel(
      success: json['success'] == true,
      bookingReference: json['bookingReference']?.toString() ?? '',
      verificationPassed: json['verificationPassed'] == true,
      confidenceScore: (json['confidenceScore'] as num?)?.toInt() ?? 0,
      comparisonAnalysis: json['comparisonAnalysis']?.toString() ?? '',
      verifiedTasks: parseList(json['verifiedTasks']),
      missingDetails: parseList(json['missingDetails']),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      durationFormatted: json['durationFormatted']?.toString() ?? '',
      hourlyRate: (json['hourlyRate'] as num?)?.toDouble() ?? 5000.0,
      calculatedPrice: (json['calculatedPrice'] as num?)?.toDouble() ?? 0.0,
      priceFormatted: json['priceFormatted']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      model: json['model']?.toString() ?? 'gpt-4o-mini',
      latencyMs: (json['latencyMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class FeedbackModel {
  final String id;
  final String bookingReference;
  final String? customerId;
  final String customerName;
  final String? providerId;
  final String providerName;
  final int rating;
  final String comment;
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.bookingReference,
    this.customerId,
    required this.customerName,
    this.providerId,
    required this.providerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory FeedbackModel.fromJson(Map<String, dynamic> json) {
    return FeedbackModel(
      id: json['id']?.toString() ?? '',
      bookingReference: json['bookingReference']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Customer',
      providerId: json['providerId']?.toString(),
      providerName: json['providerName']?.toString() ?? 'Provider',
      rating: (json['rating'] as num?)?.toInt() ?? 5,
      comment: json['comment']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
