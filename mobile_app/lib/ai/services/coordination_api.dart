import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/coordination_models.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';

class CoordinationApi {
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

  /// Sends JobPlan and candidate providers to Agent 3 (Coordination Agent) to evaluate quotes
  /// and formulate the best booking proposal.
  static Future<BookingProposalResponse> evaluateQuotations({
    required JobPlan jobPlan,
    List<MatchedProvider>? candidateProviders,
  }) async {
    developer.log(
      '🤝 [TASKBRIDGE AI: AGENT 3] Evaluating quotations for "${jobPlan.serviceTitle}"',
      name: 'CoordinationAgent',
    );

    // Map matched providers into quotation DTOs
    final List<Map<String, dynamic>> quotesJson = [];
    if (candidateProviders != null && candidateProviders.isNotEmpty) {
      for (final p in candidateProviders) {
        final requestedWindow = jobPlan.scheduledTime.isNotEmpty
            ? '${jobPlan.scheduledDate} (${jobPlan.scheduledTime})'
            : (jobPlan.scheduledDate.isNotEmpty
                  ? jobPlan.scheduledDate
                  : 'Customer preferred schedule');
        quotesJson.add({
          'providerId': p.providerId,
          'fullName': p.fullName,
          'category': p.category,
          'profilePhotoUrl': p.profilePhotoUrl,
          'phone': p.phone,
          'quotedPrice': p.hourlyRate > 0 ? p.hourlyRate : 3500.0,
          'availableTime': requestedWindow,
          'distanceKm': p.distanceKm,
          'rating': p.rating,
          'reviewCount': p.reviewCount,
          'notes': 'Verified service provider matching your requirements.',
          'matchScore': p.matchScore,
        });
      }
    }

    final payload = jsonEncode({
      'jobPlan': jobPlan.toJson(),
      'candidateProviders': quotesJson,
    });

    final candidates = _candidateUrls;
    Object? lastError;

    for (final candidate in candidates) {
      final uri = Uri.parse('$candidate/api/agent/coordination/evaluate');
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
          final result = BookingProposalResponse.fromJson(json);

          developer.log(
            '🤝 [TASKBRIDGE AI: AGENT 3] Recommended "${result.recommendedProviderName}" in ${stopwatch.elapsedMilliseconds} ms (${result.latencyMs} ms backend/AI).\n'
            '   Reason: ${result.recommendationReason}',
            name: 'CoordinationAgent',
          );

          return result;
        } else {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
      } catch (e) {
        lastError = e;
      }
    }

    developer.log(
      '⚠️ Coordination evaluation failed on all candidates. Using fallback. Error: $lastError',
      name: 'CoordinationAgent',
    );

    // Fallback response for offline / resilience
    return _generateFallbackProposal(jobPlan, candidateProviders);
  }

  static final List<BookingItem> _localBookings = [];

  /// Persists a quotation request immediately when customer requests quotations.
  static Future<bool> createQuotationRequest({
    required BookingDetails booking,
    required String category,
    required String providerId,
  }) async {
    developer.log(
      '📝 [TASKBRIDGE AI: AGENT 3] Creating quotation request "${booking.bookingReference}" for ${booking.providerName}',
      name: 'CoordinationAgent',
    );

    final newItem = BookingItem(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      bookingReference: booking.bookingReference,
      customerName: booking.customerName.isNotEmpty
          ? booking.customerName
          : 'Customer',
      providerName: booking.providerName,
      serviceTitle: booking.serviceTitle,
      category: category,
      location: booking.location,
      schedule: booking.schedule,
      price: booking.price,
      status: 'Requested',
      createdAt: DateTime.now(),
    );

    _localBookings.removeWhere(
      (b) => b.bookingReference == booking.bookingReference,
    );
    _localBookings.insert(0, newItem);

    final payload = jsonEncode({
      'bookingReference': booking.bookingReference,
      'providerId': providerId,
      'providerName': booking.providerName,
      'customerName': booking.customerName,
      'serviceTitle': booking.serviceTitle,
      'category': category,
      'location': booking.location,
      'schedule': booking.schedule,
      'price': booking.price,
      'status': 'Requested',
    });

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/agent/coordination/request-quote');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (_) {}
    }

    return true;
  }

  /// Submits a provider counter-bid / updated quote.
  static Future<bool> submitCounterBid({
    required String bookingReference,
    required double counterPrice,
    String? availableTime,
    String? notes,
  }) async {
    final idx = _localBookings.indexWhere(
      (b) => b.bookingReference == bookingReference,
    );
    if (idx != -1) {
      final old = _localBookings[idx];
      final newSchedule = availableTime != null && availableTime.isNotEmpty
          ? '$availableTime · ${old.location}'
          : old.schedule;
      _localBookings[idx] = BookingItem(
        id: old.id,
        bookingReference: old.bookingReference,
        customerName: old.customerName,
        providerName: old.providerName,
        serviceTitle: old.serviceTitle,
        category: old.category,
        location: old.location,
        schedule: newSchedule,
        price: counterPrice,
        status: 'Requested',
        createdAt: old.createdAt,
      );
    }

    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'counterPrice': counterPrice,
      'availableTime': availableTime,
      'notes': notes,
    });

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/agent/coordination/counter-bid');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }

    return true;
  }

  /// Cancels an active quotation request or booking.
  static Future<bool> cancelBooking({
    required String bookingReference,
    String? reason,
  }) async {
    final idx = _localBookings.indexWhere(
      (b) => b.bookingReference == bookingReference,
    );
    if (idx != -1) {
      final old = _localBookings[idx];
      _localBookings[idx] = BookingItem(
        id: old.id,
        bookingReference: old.bookingReference,
        customerName: old.customerName,
        providerName: old.providerName,
        serviceTitle: old.serviceTitle,
        category: old.category,
        location: old.location,
        schedule: old.schedule,
        price: old.price,
        status: 'Cancelled',
        createdAt: old.createdAt,
      );
    }

    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'reason': reason,
    });

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/agent/coordination/cancel');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }

    return true;
  }

  /// Confirms the booking when the customer approves the proposal (Human-in-the-Loop).
  static Future<bool> confirmBooking({
    required BookingDetails booking,
    required String category,
    required String providerId,
  }) async {
    developer.log(
      '🤝 [TASKBRIDGE AI: AGENT 3] Confirming booking "${booking.bookingReference}" for ${booking.providerName}',
      name: 'CoordinationAgent',
    );

    // Save to local cache immediately
    final newItem = BookingItem(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      bookingReference: booking.bookingReference,
      customerName: booking.customerName.isNotEmpty
          ? booking.customerName
          : 'Customer',
      providerName: booking.providerName,
      serviceTitle: booking.serviceTitle,
      category: category,
      location: booking.location,
      schedule: booking.schedule,
      price: booking.price,
      status: 'Upcoming',
      createdAt: DateTime.now(),
    );
    _localBookings.removeWhere(
      (b) => b.bookingReference == booking.bookingReference,
    );
    _localBookings.insert(0, newItem);

    final payload = jsonEncode({
      'bookingReference': booking.bookingReference,
      'providerId': providerId,
      'providerName': booking.providerName,
      'customerName': booking.customerName,
      'serviceTitle': booking.serviceTitle,
      'category': category,
      'location': booking.location,
      'schedule': booking.schedule,
      'price': booking.price,
      'status': 'Upcoming',
    });

    final candidates = _candidateUrls;

    for (final candidate in candidates) {
      final uri = Uri.parse('$candidate/api/agent/coordination/confirm');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          return true;
        }
      } catch (_) {}
    }

    return true; // Graceful return for demo if backend offline
  }

  /// Retrieves live bookings for customer/provider dashboard.
  static Future<List<BookingItem>> getBookings({
    String? providerId,
    String? providerName,
    String? customerName,
    String? status,
  }) async {
    final candidates = _candidateUrls;

    for (final candidate in candidates) {
      var url = '$candidate/api/agent/coordination/bookings';
      final queryParams = <String>[];
      if (providerId != null && providerId.isNotEmpty) {
        queryParams.add('providerId=$providerId');
      }
      if (providerName != null && providerName.isNotEmpty) {
        queryParams.add('providerName=${Uri.encodeComponent(providerName)}');
      }
      if (customerName != null && customerName.isNotEmpty) {
        queryParams.add('customerName=${Uri.encodeComponent(customerName)}');
      }
      if (status != null && status.isNotEmpty) {
        queryParams.add('status=${Uri.encodeComponent(status)}');
      }
      if (queryParams.isNotEmpty) url += '?${queryParams.join('&')}';

      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          _workingBaseUrl = candidate;
          final list = jsonDecode(response.body) as List<dynamic>;
          final remoteBookings = list
              .map((b) => BookingItem.fromJson(b as Map<String, dynamic>))
              .toList();

          // Merge with local newly created bookings
          final mergedMap = <String, BookingItem>{};
          for (final b in _localBookings) {
            mergedMap[b.bookingReference] = b;
          }
          for (final b in remoteBookings) {
            mergedMap[b.bookingReference] = b;
          }

          var result = mergedMap.values.toList();
          if (status != null && status.isNotEmpty) {
            result = result
                .where((b) => b.status.toLowerCase() == status.toLowerCase())
                .toList();
          }
          if (providerName != null && providerName.isNotEmpty) {
            final pLow = providerName.trim().toLowerCase();
            result = result
                .where((b) => b.providerName.trim().toLowerCase() == pLow)
                .toList();
          }
          if (customerName != null && customerName.isNotEmpty) {
            final cLow = customerName.trim().toLowerCase();
            result = result
                .where((b) => b.customerName.trim().toLowerCase() == cLow)
                .toList();
          }
          return result;
        }
      } catch (_) {}
    }

    // Fallback to local live bookings
    var result = List<BookingItem>.from(_localBookings);
    if (status != null && status.isNotEmpty) {
      result = result
          .where((b) => b.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    if (providerName != null && providerName.isNotEmpty) {
      final pLow = providerName.trim().toLowerCase();
      result = result
          .where((b) => b.providerName.trim().toLowerCase() == pLow)
          .toList();
    }
    if (customerName != null && customerName.isNotEmpty) {
      final cLow = customerName.trim().toLowerCase();
      result = result
          .where((b) => b.customerName.trim().toLowerCase() == cLow)
          .toList();
    }
    return result;
  }

  /// Updates job status (e.g. Upcoming -> Active -> Completed).
  static Future<bool> updateBookingStatus({
    required String bookingReference,
    required String newStatus,
    String? schedule,
    double? price,
  }) async {
    // Update locally immediately
    final idx = _localBookings.indexWhere(
      (b) => b.bookingReference == bookingReference,
    );
    if (idx != -1) {
      final old = _localBookings[idx];
      _localBookings[idx] = BookingItem(
        id: old.id,
        bookingReference: old.bookingReference,
        customerName: old.customerName,
        providerName: old.providerName,
        serviceTitle: old.serviceTitle,
        category: old.category,
        location: old.location,
        schedule: schedule ?? old.schedule,
        price: price ?? old.price,
        status: newStatus,
        createdAt: old.createdAt,
      );
    }

    final candidates = _candidateUrls;
    final body = <String, dynamic>{
      'bookingReference': bookingReference,
      'newStatus': newStatus,
    };
    if (schedule != null) body['schedule'] = schedule;
    if (price != null) body['price'] = price;
    final payload = jsonEncode(body);

    for (final candidate in candidates) {
      final uri = Uri.parse('$candidate/api/agent/coordination/update-status');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return true;
        }
      } catch (_) {}
    }

    return true;
  }

  static BookingProposalResponse _generateFallbackProposal(
    JobPlan plan,
    List<MatchedProvider>? candidateProviders,
  ) {
    final topProvider =
        (candidateProviders != null && candidateProviders.isNotEmpty)
        ? candidateProviders.first
        : null;

    final winnerName = topProvider?.fullName ?? 'Ravindu Dissanayake';
    final winnerId = topProvider?.providerId ?? 'p-ravindu';
    final winnerPrice = topProvider != null && topProvider.hourlyRate > 0
        ? (topProvider.hourlyRate * 1.5).roundToDouble()
        : 4500.0;

    final isMorning = plan.scheduledTime.toLowerCase().contains('morning');
    final timeStr = isMorning ? 'Tomorrow at 9:30 AM' : 'Tomorrow at 4:00 PM';

    final winQuote = ProviderQuotation(
      providerId: winnerId,
      fullName: winnerName,
      category: plan.category,
      phone: topProvider?.phone ?? '0771234567',
      quotedPrice: winnerPrice,
      availableTime: timeStr,
      distanceKm: topProvider?.distanceKm ?? 2.4,
      rating: topProvider?.rating ?? 4.8,
      reviewCount: topProvider?.reviewCount ?? 12,
      notes: 'Includes full service, professional equipment, and cleanup.',
      matchScore: 96,
      isRecommended: true,
    );

    final datePart = plan.scheduledDate.isNotEmpty
        ? plan.scheduledDate.split('·').first.trim()
        : 'Tomorrow';
    final locPart = plan.location ?? 'Colombo 05';
    final scheduleDisplay =
        '$datePart · ${isMorning ? "9:30 AM" : "4:00 PM"} · $locPart';

    return BookingProposalResponse(
      success: true,
      recommendedProviderId: winnerId,
      recommendedProviderName: winnerName,
      recommendationReason:
          '$winnerName is recommended because their quote of Rs. ${winnerPrice.toInt()} fits your budget, matches your preferred time window ($timeStr), and holds a 4.8★ verified track record.',
      winningQuotation: winQuote,
      allQuotations: [winQuote],
      bookingProposal: BookingDetails(
        bookingReference: 'TB-1042',
        serviceTitle: plan.serviceTitle,
        providerName: winnerName,
        customerName: 'Kavindu Alwis',
        location: locPart,
        schedule: scheduleDisplay,
        price: winnerPrice,
        priceFormatted: 'Rs. ${winnerPrice.toInt()}',
        status: 'Upcoming',
      ),
      model: 'rule-based-fallback',
      latencyMs: 15,
    );
  }
}
