import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../ai/services/bookings_sync_service.dart';
import '../../auth/data/auth_api.dart';
import '../../core/config/api_config.dart';
import '../models/dispute_model.dart';

class DisputesApi {
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

  /// Creates a formal dispute for a booking/completion
  static Future<DisputeItem?> createDispute({
    required String bookingReference,
    required String reasonCategory,
    required String description,
    required String desiredResolution,
    List<String>? evidencePhotoUrls,
    String? customerId,
    String? customerName,
  }) async {
    final headers = await _authHeaders();
    final body = jsonEncode({
      'bookingReference': bookingReference,
      'reasonCategory': reasonCategory,
      'description': description,
      'desiredResolution': desiredResolution,
      if (evidencePhotoUrls != null && evidencePhotoUrls.isNotEmpty)
        'evidencePhotoUrls': evidencePhotoUrls,
      'customerId': ?customerId,
      'customerName': ?customerName,
    });

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/disputes');
      try {
        final res = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _workingBaseUrl = base;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final item = DisputeItem.fromJson(json);
          developer.log(
            '⚖️ [DisputesApi] Dispute created: ${item.disputeReference}',
          );
          BookingsSyncService.instance.triggerImmediateUpdate();
          return item;
        } else {
          developer.log(
            '⚠️ [DisputesApi] Failed on $base: ${res.statusCode} ${res.body}',
          );
        }
      } catch (e) {
        developer.log('⚠️ [DisputesApi] Error on $base: $e');
      }
    }
    return null;
  }

  /// Fetches all disputes made by this customer
  static Future<List<DisputeItem>> getCustomerDisputes({
    String? customerId,
    String? customerName,
    String? bookingReference,
  }) async {
    final headers = await _authHeaders();
    final params = <String, String>{};
    if (customerId != null && customerId.isNotEmpty) {
      params['customerId'] = customerId;
    }
    if (customerName != null && customerName.isNotEmpty) {
      params['customerName'] = customerName;
    }
    if (bookingReference != null && bookingReference.isNotEmpty) {
      params['bookingReference'] = bookingReference;
    }

    final query = params.isNotEmpty
        ? '?${Uri(queryParameters: params).query}'
        : '';

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/disputes$query');
      try {
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          final List list = jsonDecode(res.body);
          return list
              .map((e) => DisputeItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        developer.log(
          '⚠️ [DisputesApi] getCustomerDisputes error on $base: $e',
        );
      }
    }
    return [];
  }

  /// Gets a single dispute by reference or ID
  static Future<DisputeItem?> getDispute(String idOrRef) async {
    final headers = await _authHeaders();
    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/disputes/$idOrRef');
      try {
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return DisputeItem.fromJson(json);
        }
      } catch (e) {
        developer.log('⚠️ [DisputesApi] getDispute error on $base: $e');
      }
    }
    return null;
  }
}
