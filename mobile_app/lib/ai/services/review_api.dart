import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/review_models.dart';

class ReviewApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];

    return const [
      'http://localhost:5298',
      'http://10.0.2.2:5298',
      'http://192.168.1.4:5298',
      'http://192.168.1.2:5298',
    ];
  }

  /// Uploads a proof photo (before or after) to Cloudflare R2 via backend
  static Future<String?> uploadProofPhoto(String filePath, {String? bookingRef}) async {
    final candidates = _candidateUrls;
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/proofs/upload');
        final request = http.MultipartRequest('POST', uri);
        if (bookingRef != null && bookingRef.isNotEmpty) {
          request.fields['bookingRef'] = bookingRef;
        }

        final file = await http.MultipartFile.fromPath('file', filePath);
        request.files.add(file);

        final streamed = await request.send().timeout(const Duration(seconds: 40));
        final response = await http.Response.fromStream(streamed);

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final url = json['url']?.toString();
          developer.log('📷 [REVIEW AGENT] Proof photo uploaded to R2: $url', name: 'ReviewAgent');
          return url;
        }
      } catch (e) {
        developer.log('Upload error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return null;
  }

  /// Provider starts the job with optional before-photo URL
  static Future<bool> startJob({
    required String bookingReference,
    String? beforePhotoUrl,
  }) async {
    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'beforePhotoUrl': beforePhotoUrl,
    });

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/start');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          developer.log('⏱ [REVIEW AGENT] Started job #$bookingReference', name: 'ReviewAgent');
          return true;
        }
      } catch (e) {
        developer.log('Start job error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return false;
  }

  /// Evaluates job completion with Agent 4 multimodal OpenAI vision review
  static Future<ReviewAnalyzeResponseModel?> evaluateCompletion({
    required String bookingReference,
    required String providerNotes,
    String? beforePhotoUrl,
    List<String>? beforePhotoUrls,
    required List<String> afterPhotoUrls,
    DateTime? startedAt,
    DateTime? endedAt,
    double? hourlyRate,
  }) async {
    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'providerNotes': providerNotes,
      'beforePhotoUrl': beforePhotoUrl ?? (beforePhotoUrls != null && beforePhotoUrls.isNotEmpty ? beforePhotoUrls.first : null),
      'beforePhotoUrls': beforePhotoUrls ?? (beforePhotoUrl != null ? [beforePhotoUrl] : []),
      'afterPhotoUrls': afterPhotoUrls,
      'startedAt': startedAt?.toUtc().toIso8601String(),
      'endedAt': endedAt?.toUtc().toIso8601String(),
      'hourlyRate': hourlyRate,
    });

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/evaluate');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 45));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return ReviewAnalyzeResponseModel.fromJson(json);
        }
      } catch (e) {
        developer.log('Evaluate completion error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return null;
  }

  /// Fetches completion details for a booking
  static Future<JobCompletionModel?> getCompletionDetails(String bookingRef) async {
    final candidates = _candidateUrls;
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/$bookingRef');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return JobCompletionModel.fromJson(json);
        } else if (response.statusCode == 404) {
          _workingBaseUrl = candidate;
          return null;
        }
      } catch (e) {
        developer.log('Get completion details error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return null;
  }

  /// Customer signs off on the job
  static Future<bool> customerApprove({
    required String bookingReference,
    String? customerNotes,
  }) async {
    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'customerNotes': customerNotes,
    });

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/customer-approve');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (e) {
        developer.log('Customer approve error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return false;
  }

  /// Customer requests a revision
  static Future<bool> requestRevision({
    required String bookingReference,
    required String reason,
  }) async {
    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'reason': reason,
    });

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/request-revision');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (e) {
        developer.log('Request revision error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return false;
  }

  /// Submits customer rating and feedback
  static Future<FeedbackModel?> submitFeedback({
    required String bookingReference,
    String? customerId,
    String? customerName,
    String? providerId,
    String? providerName,
    required int rating,
    required String comment,
  }) async {
    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'customerId': customerId,
      'customerName': customerName,
      'providerId': providerId,
      'providerName': providerName,
      'rating': rating,
      'comment': comment,
    });

    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/agent/review/feedback');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: payload,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          return FeedbackModel.fromJson(json);
        }
      } catch (e) {
        developer.log('Submit feedback error on $candidate: $e', name: 'ReviewAgent');
      }
    }
    return null;
  }
}
