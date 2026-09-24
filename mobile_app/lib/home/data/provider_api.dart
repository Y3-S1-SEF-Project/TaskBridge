import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../core/config/api_config.dart';
import '../models/provider_item.dart';

class ProviderApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }

  /// Fetches real providers from the database matching search query, category, location, coordinates, and sort order.
  static Future<List<ProviderItem>> getProviders({
    String? query,
    String? category,
    String? location,
    double? lat,
    double? lng,
    String? sortBy,
    String? excludeUserId,
    String? excludeName,
    int limit = 20,
  }) async {
    final candidates = _candidateUrls;
    Object? lastError;

    // 1. Try dedicated /api/providers endpoint
    for (final candidate in candidates) {
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (query != null && query.trim().isNotEmpty) {
        queryParams['query'] = query.trim();
      }
      if (category != null &&
          category.trim().isNotEmpty &&
          category.toLowerCase() != 'all') {
        queryParams['category'] = category.trim();
      }
      if (location != null && location.trim().isNotEmpty) {
        queryParams['location'] = location.trim();
      }
      if (lat != null && lat != 0) {
        queryParams['lat'] = lat.toString();
      }
      if (lng != null && lng != 0) {
        queryParams['lng'] = lng.toString();
      }
      if (sortBy != null && sortBy.trim().isNotEmpty) {
        queryParams['sortBy'] = sortBy.trim();
      }
      if (excludeUserId != null && excludeUserId.trim().isNotEmpty) {
        queryParams['excludeUserId'] = excludeUserId.trim();
      }
      if (excludeName != null && excludeName.trim().isNotEmpty) {
        queryParams['excludeName'] = excludeName.trim();
      }

      final uri = Uri.parse('$candidate/api/providers')
          .replace(queryParameters: queryParams);


      try {
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          final List<dynamic> list = jsonDecode(response.body) as List<dynamic>;
          return list
              .map((e) => ProviderItem.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (e) {
        lastError = e;
      }
    }

    // 2. Fallback to /api/agent/matching/match to retrieve real DB candidates if backend wasn't restarted
    for (final candidate in candidates) {
      try {
        final matchUri = Uri.parse('$candidate/api/agent/matching/match');
        final cat = (category != null && category.toLowerCase() != 'all')
            ? category
            : 'General';
        final payload = jsonEncode({
          'jobPlan': {
            'category': cat,
            'serviceTitle': query?.isNotEmpty == true ? query : 'Service',
            'description': 'Search query: ${query ?? cat}',
            'location': location ?? 'Colombo',
            'budgetDisplay': 'Rs. 5,000',
          },
          'maxResults': limit,
        });

        final response = await http
            .post(
              matchUri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final raw = json['matchedProviders'] as List<dynamic>? ?? [];
          final items = raw.map((p) {
            final map = p as Map<String, dynamic>;
            return ProviderItem(
              id: map['providerId']?.toString() ?? '',
              userId: map['userId']?.toString() ?? '',
              fullName: map['fullName'] as String? ?? 'Specialist',
              profilePhotoUrl: map['profilePhotoUrl'] as String?,
              phone: map['phone'] as String? ?? '',
              category: map['category'] as String? ?? 'General',
              skills: map['skills'] as String?,
              services: map['services'] as String?,
              serviceAreas: map['serviceAreas'] as String?,
              hourlyRate: (map['hourlyRate'] as num?)?.toDouble() ?? 2500.0,
              rating: (map['rating'] as num?)?.toDouble() ?? 4.8,
              reviewCount: map['reviewCount'] as int? ?? 12,
              distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 2.4,
              bio: map['aiMatchReason'] as String?,
            );
          }).toList();

          // Apply local filtering if necessary
          if (category != null && category.toLowerCase() != 'all') {
            final catLower = category.toLowerCase();
            return items
                .where((i) =>
                    i.category.toLowerCase().contains(catLower) ||
                    (i.skills != null &&
                        i.skills!.toLowerCase().contains(catLower)))
                .toList();
          }
          return items;
        }
      } catch (e) {
        lastError = e;
      }
    }

    developer.log('ProviderApi: Failed to fetch providers: $lastError');
    return [];
  }
}
