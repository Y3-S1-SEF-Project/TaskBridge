import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../../auth/data/auth_api.dart';
import '../../../core/config/api_config.dart';
import '../models/planning_models.dart';

/// Dart model representing a persistent Service Request entity from PostgreSQL
class ServiceRequestItem {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String title;
  final String category;
  final String description;
  final String location;
  final String? locationAddress;
  final double? estimatedBudget;
  final String scheduledDate;
  final String scheduledTime;
  final String status;
  final List<String> mediaUrls;
  final JobPlan? aiPlan;
  final List<String> acceptanceChecklist;
  final String? clarificationQuestion;
  final bool isLocationMissing;
  final List<String> missingFields;
  final String? cancellationReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ServiceRequestItem({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    this.locationAddress,
    this.estimatedBudget,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.mediaUrls,
    this.aiPlan,
    required this.acceptanceChecklist,
    this.clarificationQuestion,
    required this.isLocationMissing,
    required this.missingFields,
    this.cancellationReason,
    required this.createdAt,
    this.updatedAt,
  });

  factory ServiceRequestItem.fromJson(Map<String, dynamic> json) {
    final rawMedia = json['mediaUrls'] as List<dynamic>? ?? [];
    final media = rawMedia.map((m) => m.toString()).toList();

    final rawChecklist = json['acceptanceChecklist'] as List<dynamic>? ?? [];
    final checklist = rawChecklist.map((c) => c.toString()).toList();

    final rawMissing = json['missingFields'] as List<dynamic>? ?? [];
    final missing = rawMissing.map((f) => f.toString()).toList();

    JobPlan? plan;
    if (json['aiPlan'] != null && json['aiPlan'] is Map<String, dynamic>) {
      plan = JobPlan.fromJson(json['aiPlan'] as Map<String, dynamic>);
    }

    return ServiceRequestItem(
      id: json['id'] as String? ?? '',
      customerId: json['customerId'] as String? ?? '',
      customerName: json['customerName'] as String? ?? 'Customer',
      customerPhone: json['customerPhone'] as String? ?? '',
      title: json['title'] as String? ?? 'Home Service Request',
      category: json['category'] as String? ?? 'General Handyman',
      description: json['description'] as String? ?? '',
      location: json['location'] as String? ?? '',
      locationAddress: json['locationAddress'] as String?,
      estimatedBudget: (json['estimatedBudget'] is num)
          ? (json['estimatedBudget'] as num).toDouble()
          : null,
      scheduledDate: json['scheduledDate'] as String? ?? '',
      scheduledTime: json['scheduledTime'] as String? ?? '',
      status: json['status'] as String? ?? 'ReadyForMatching',
      mediaUrls: media,
      aiPlan: plan,
      acceptanceChecklist: checklist,
      clarificationQuestion: json['clarificationQuestion'] as String?,
      isLocationMissing: json['isLocationMissing'] as bool? ?? false,
      missingFields: missing,
      cancellationReason: json['cancellationReason'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }
}

class ServiceRequestsApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthApi.getCachedToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Creates a new service request, triggers Planning Agent AI, and saves to PostgreSQL
  static Future<ServiceRequestItem?> createRequest({
    required String description,
    String? title,
    String? category,
    String? location,
    String? locationAddress,
    double? estimatedBudget,
    String? scheduledDate,
    String? scheduledTime,
    List<String>? mediaUrls,
    String? customerId,
    String? customerName,
    String? customerPhone,
  }) async {
    final headers = await _authHeaders();
    final payload = jsonEncode({
      'title': title,
      'category': category,
      'description': description,
      'location': location,
      'locationAddress': locationAddress,
      'estimatedBudget': estimatedBudget,
      'scheduledDate': scheduledDate,
      'scheduledTime': scheduledTime,
      'mediaUrls': mediaUrls ?? [],
      'customerId': (customerId != null && customerId.isNotEmpty && customerId.contains('-'))
          ? customerId
          : null,
      'customerName': customerName,
      'customerPhone': customerPhone,
    });

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/requests');
      try {
        final res = await http.post(
          uri,
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 30));

        if (res.statusCode == 200 || res.statusCode == 201) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final item = ServiceRequestItem.fromJson(json);
          developer.log('✅ [ServiceRequestsApi] Request saved to PostgreSQL with ID: ${item.id}');
          return item;
        }
      } catch (e) {
        developer.log('⚠️ [ServiceRequestsApi] Create request failed on $candidate: $e');
      }
    }
    return null;
  }

  /// Fetches all service requests submitted by the customer
  static Future<List<ServiceRequestItem>> getMyRequests({
    String? customerId,
    String? customerName,
    String? status,
  }) async {
    final headers = await _authHeaders();
    final queryParams = <String, String>{};
    if (customerId != null && customerId.isNotEmpty && customerId.contains('-')) {
      queryParams['customerId'] = customerId;
    }
    if (customerName != null && customerName.isNotEmpty) {
      queryParams['customerName'] = customerName;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final query = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/requests/my$query');
      try {
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          _workingBaseUrl = candidate;
          final List list = jsonDecode(res.body);
          return list
              .map((item) => ServiceRequestItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        developer.log('⚠️ [ServiceRequestsApi] getMyRequests failed on $candidate: $e');
      }
    }
    return [];
  }

  /// Cancels an open service request
  static Future<bool> cancelRequest({
    required String requestId,
    required String reason,
  }) async {
    final headers = await _authHeaders();
    final payload = jsonEncode({'reason': reason});

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/requests/$requestId/cancel');
      try {
        final res = await http.put(
          uri,
          headers: headers,
          body: payload,
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (e) {
        developer.log('⚠️ [ServiceRequestsApi] cancelRequest failed on $candidate: $e');
      }
    }
    return false;
  }

  /// Permanently deletes a service request from the database
  static Future<bool> deleteRequest({
    required String requestId,
  }) async {
    final headers = await _authHeaders();

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/requests/$requestId');
      try {
        final res = await http.delete(
          uri,
          headers: headers,
        ).timeout(const Duration(seconds: 12));

        if (res.statusCode == 200) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (e) {
        developer.log('⚠️ [ServiceRequestsApi] deleteRequest failed on $candidate: $e');
      }
    }
    return false;
  }
}
