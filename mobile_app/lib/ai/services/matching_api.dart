import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';

class MatchingApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }

  /// Sends the JobPlan from Agent 1 to Agent 2 for provider matching and ranking.
  static Future<MatchingResponse> matchProviders({
    required JobPlan jobPlan,
    String? customerUserId,
    String? customerName,
    int maxResults = 3,
  }) async {
    developer.log(
      '🤖 [TASKBRIDGE AI: AGENT 2] Initiating matching for "${jobPlan.serviceTitle}" in "${jobPlan.location}"',
      name: 'MatchingAgent',
    );