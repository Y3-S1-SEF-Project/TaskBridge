import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/matching_models.dart';
import '../models/planning_models.dart';

class MatchingApi {
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

  /// Sends the JobPlan from Agent 1 to Agent 2 for provider matching and ranking.
  static Future<MatchingResponse> matchProviders({
    required JobPlan jobPlan,
    int? customerUserId,
    int maxResults = 3,
  }) async {
    developer.log(
      '🤖 [TASKBRIDGE AI: AGENT 2] Initiating matching for "${jobPlan.serviceTitle}" in "${jobPlan.location}"',
      name: 'MatchingAgent',
    );

    final payload = jsonEncode({
      'jobPlan': jobPlan.toJson(),
      'customerUserId': customerUserId,
      'maxResults': maxResults,
    });

    final candidates = _candidateUrls;
    Object? lastError;

    for (final candidate in candidates) {
      final uri = Uri.parse('$candidate/api/agent/matching/match');
      try {
        final stopwatch = Stopwatch()..start();
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 30));
        stopwatch.stop();

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final result = MatchingResponse.fromJson(json);

          developer.log(
            '🤖 [TASKBRIDGE AI: AGENT 2] Matched ${result.matchedProviders.length} providers in ${stopwatch.elapsedMilliseconds} ms (${result.latencyMs} ms backend/AI).\n'
            'Top Match: ${result.matchedProviders.firstOrNull?.fullName} (${result.matchedProviders.firstOrNull?.matchScore}%)',
            name: 'MatchingAgent',
          );

          return result;
        } else {
          developer.log(
            '⚠️ [TASKBRIDGE AI: AGENT 2] HTTP error ${response.statusCode} from $candidate: ${response.body}',
            name: 'MatchingAgent',
          );
        }
      } catch (e) {
        lastError = e;
        developer.log(
          '⚠️ [TASKBRIDGE AI: AGENT 2] Failed connecting to $candidate: $e',
          name: 'MatchingAgent',
        );
      }
    }

    developer.log(
      '❌ [TASKBRIDGE AI: AGENT 2] Failed connecting to Matching Agent backend: $lastError',
      name: 'MatchingAgent',
    );

    throw Exception(
      'Failed to connect to Matching Agent backend: $lastError',
    );
  }
}
