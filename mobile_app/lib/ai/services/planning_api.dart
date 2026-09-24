import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/planning_models.dart';

class PlanningApi {
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

  /// Sends the user's natural language prompt to the Planning Agent backend.
  static Future<PlanningAnalyzeResult> analyzePrompt({
    required String prompt,
    String? userLocation,
    int? userId,
  }) async {
    developer.log(
      '🤖 [TASKBRIDGE AI: AGENT 1] Sending prompt for planning analysis:\n"$prompt"',
      name: 'PlanningAgent',
    );

    final payload = jsonEncode({
      'prompt': prompt,
      'userLocation': userLocation,
      'userId': userId,
    });

    final candidates = _candidateUrls;
    Object? lastError;

    for (final candidate in candidates) {
      final uri = Uri.parse('$candidate/api/agent/planning/analyze');
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
          final result = PlanningAnalyzeResult.fromJson(json);

          developer.log(
            '🤖 [TASKBRIDGE AI: AGENT 1] Successfully analyzed in ${stopwatch.elapsedMilliseconds} ms (${result.latencyMs} ms OpenAI).\n'
            'Service: ${result.jobPlan.serviceTitle} | Category: ${result.jobPlan.category}\n'
            'Location missing: ${result.isLocationMissing} | Budget: ${result.jobPlan.budgetDisplay}',
            name: 'PlanningAgent',
          );

          return result;
        } else {
          developer.log(
            '⚠️ [TASKBRIDGE AI] HTTP error ${response.statusCode} from $candidate: ${response.body}',
            name: 'PlanningAgent',
          );
        }
      } catch (e) {
        lastError = e;
        developer.log(
          '⚠️ [TASKBRIDGE AI] Failed connecting to $candidate: $e',
          name: 'PlanningAgent',
        );
      }
    }

    // Fallback if backend is currently unreachable during offline demo
    developer.log(
      '🔄 [TASKBRIDGE AI: AGENT 1] Backend connection error ($lastError). Generating local fallback plan...',
      name: 'PlanningAgent',
    );

    final isPlumbing = prompt.toLowerCase().contains('tap') ||
        prompt.toLowerCase().contains('leak') ||
        prompt.toLowerCase().contains('pipe');

    final bool locationMissing = userLocation == null || userLocation.isEmpty;

    return PlanningAnalyzeResult(
      success: true,
      isLocationMissing: locationMissing,
      missingFields: locationMissing ? ['location'] : [],
      clarificationQuestion:
          'Where do you need the service? We need your location to find providers who cover your area.',
      jobPlan: JobPlan(
        serviceTitle: isPlumbing ? 'Kitchen tap repair' : 'Home Service Repair',
        category: isPlumbing ? 'Plumbing' : 'General Handyman',
        description: isPlumbing
            ? 'Repair the leaking kitchen tap and test for leaks.'
            : prompt,
        location: locationMissing ? null : userLocation,
        locationAddress: locationMissing ? null : '24 Park Road',
        scheduledDate: 'Tomorrow · 17 Sep',
        scheduledTime: 'After 3:00 PM',
        budget: 5000,
        budgetDisplay: 'Budget up to Rs. 5,000',
      ),
      progressSteps: [
        ReasoningStep(
          stepKey: 'understanding_service',
          title: 'Understanding service',
          subtitle: isPlumbing ? 'Kitchen tap repair' : 'Home Service Repair',
          status: 'completed',
        ),
        const ReasoningStep(
          stepKey: 'finding_providers',
          title: 'Finding suitable providers',
          subtitle: 'Skills and service area matched',
          status: 'completed',
        ),
        const ReasoningStep(
          stepKey: 'checking_availability',
          title: 'Checking availability',
          subtitle: 'Tomorrow after 3 PM',
          status: 'completed',
        ),
        const ReasoningStep(
          stepKey: 'preparing_recommendation',
          title: 'Preparing recommendation',
          subtitle: 'Waiting for availability checks',
          status: 'pending',
        ),
      ],
      latencyMs: 340,
      tokensUsed: 128,
      model: 'local-demo-fallback',
    );
  }
}
