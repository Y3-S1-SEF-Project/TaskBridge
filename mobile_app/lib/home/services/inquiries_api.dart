import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../auth/data/auth_api.dart';
import '../../core/config/api_config.dart';
import '../models/inquiry_model.dart';

class InquiriesApi {
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

  /// Creates a new system inquiry / ticket
  static Future<InquiryModel?> createInquiry({
    required String subject,
    required String category,
    required String message,
    String? priority,
    List<String>? attachmentUrls,
    String? userId,
    String? userName,
    String? userRole,
  }) async {
    final headers = await _authHeaders();
    final body = jsonEncode({
      'subject': subject,
      'category': category,
      'message': message,
      'priority': priority ?? 'Normal',
      if (attachmentUrls != null && attachmentUrls.isNotEmpty)
        'attachmentUrls': attachmentUrls,
      'userId': ?userId,
      'userName': ?userName,
      'userRole': userRole ?? 'Customer',
    });

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/inquiries');
      try {
        final res = await http
            .post(uri, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _workingBaseUrl = base;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final item = InquiryModel.fromJson(json);
          developer.log('📩 [InquiriesApi] Inquiry created: #${item.inquiryReference}');
          return item;
        } else {
          developer.log('⚠️ [InquiriesApi] Failed on $base: ${res.statusCode} ${res.body}');
        }
      } catch (e) {
        developer.log('⚠️ [InquiriesApi] Error on $base: $e');
      }
    }
    return null;
  }

  /// Gets list of inquiries for the user
  static Future<List<InquiryModel>> getUserInquiries({
    String? userId,
    String? search,
  }) async {
    final headers = await _authHeaders();
    final params = <String, String>{};
    if (userId != null && userId.isNotEmpty) {
      params['userId'] = userId;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }

    final query = params.isNotEmpty
        ? '?${Uri(queryParameters: params).query}'
        : '';

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/inquiries$query');
      try {
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 12));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _workingBaseUrl = base;
          final decoded = jsonDecode(res.body);
          if (decoded is List) {
            return decoded
                .map((e) => InquiryModel.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } catch (e) {
        developer.log('⚠️ [InquiriesApi] Error on $base: $e');
      }
    }
    return [];
  }

  /// Gets single inquiry by id or reference
  static Future<InquiryModel?> getInquiry(String idOrRef) async {
    final headers = await _authHeaders();
    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/inquiries/$idOrRef');
      try {
        final res = await http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _workingBaseUrl = base;
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          return InquiryModel.fromJson(json);
        }
      } catch (e) {
        developer.log('⚠️ [InquiriesApi] Error on $base: $e');
      }
    }
    return null;
  }

  /// Deletes an inquiry by id
  static Future<bool> deleteInquiry(String id) async {
    final headers = await _authHeaders();
    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/inquiries/$id');
      try {
        final res = await http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 10));

        if (res.statusCode >= 200 && res.statusCode < 300) {
          _workingBaseUrl = base;
          developer.log('🗑️ [InquiriesApi] Inquiry $id successfully deleted');
          return true;
        } else {
          developer.log('⚠️ [InquiriesApi] Delete failed on $base: ${res.statusCode}');
        }
      } catch (e) {
        developer.log('⚠️ [InquiriesApi] Delete error on $base: $e');
      }
    }
    return false;
  }
}
