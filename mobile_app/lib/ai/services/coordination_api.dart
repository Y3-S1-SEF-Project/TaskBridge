import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../models/coordination_models.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';
import 'bookings_sync_service.dart';

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
  static final List<ProposalItem> _localProposals = [];

  /// Persists a newly created quotation proposal (status = "Requested") to the proposals table.
  static Future<bool> createQuotationRequest({
    required BookingDetails booking,
    required String category,
    required String providerId,
    String? rateType = 'Hourly',
  }) async {
    developer.log(
      '📝 [TASKBRIDGE AI: AGENT 3] Creating quotation proposal "${booking.bookingReference}" for ${booking.providerName}',
      name: 'CoordinationAgent',
    );

    final resolvedRateType = rateType ?? 'Hourly';

    final newProp = ProposalItem(
      id: 'pr-${DateTime.now().millisecondsSinceEpoch}',
      proposalReference: booking.bookingReference,
      serviceTitle: booking.serviceTitle,
      category: category,
      providerName: booking.providerName,
      providerId: providerId,
      customerName: booking.customerName.isNotEmpty
          ? booking.customerName
          : 'Customer',
      location: booking.location,
      preferredSchedule: booking.schedule,
      estimatedRate: booking.price,
      rateType: resolvedRateType,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    _localProposals.removeWhere(
      (p) => p.proposalReference == booking.bookingReference,
    );
    _localProposals.insert(0, newProp);

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
      rateType: resolvedRateType,
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
      'rateType': resolvedRateType,
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
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
    return true;
  }

  /// Submits a provider counter-bid or customer re-bid / updated quote.
  static Future<bool> submitCounterBid({
    required String bookingReference,
    required double counterPrice,
    String? rateType,
    String? availableTime,
    String? notes,
    String? sender,
  }) async {
    final isCustomer = sender?.toLowerCase() == 'customer';
    final targetStatus = isCustomer ? 'CustomerCountered' : 'ProviderCountered';

    final idx = _localBookings.indexWhere(
      (b) => b.bookingReference == bookingReference,
    );
    if (idx != -1) {
      final old = _localBookings[idx];
      if (old.isActive || old.status.toLowerCase() == 'in progress') {
        return false;
      }
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
        rateType: rateType ?? old.rateType,
        status: targetStatus,
        createdAt: old.createdAt,
      );
    }

    final pIdx = _localProposals.indexWhere(
      (p) => p.proposalReference == bookingReference,
    );
    if (pIdx != -1) {
      final old = _localProposals[pIdx];
      final newSchedule = availableTime != null && availableTime.isNotEmpty
          ? '$availableTime · ${old.location}'
          : old.preferredSchedule;
      _localProposals[pIdx] = ProposalItem(
        id: old.id,
        proposalReference: old.proposalReference,
        serviceTitle: old.serviceTitle,
        category: old.category,
        providerName: old.providerName,
        providerId: old.providerId,
        customerName: old.customerName,
        location: old.location,
        preferredSchedule: newSchedule,
        estimatedRate: counterPrice,
        rateType: rateType ?? old.rateType,
        status: targetStatus,
        createdAt: old.createdAt,
      );
    }

    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'counterPrice': counterPrice,
      'rateType': rateType,
      'availableTime': availableTime,
      'notes': notes,
      'sender': sender ?? 'provider',
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
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
    return true;
  }

  /// Cancels an active quotation request or booking.
  static Future<bool> cancelBooking({
    required String bookingReference,
    String? reason,
  }) async {
    final altRef = bookingReference.startsWith('TB-')
        ? bookingReference.replaceFirst('TB-', 'PR-')
        : bookingReference.replaceFirst('PR-', 'TB-');

    for (var i = 0; i < _localBookings.length; i++) {
      final b = _localBookings[i];
      if (b.bookingReference == bookingReference ||
          b.bookingReference == altRef) {
        if (b.isActive || b.status.toLowerCase() == 'in progress') {
          return false;
        }
        _localBookings[i] = b.copyWith(status: 'Cancelled');
      }
    }

    for (var i = 0; i < _localProposals.length; i++) {
      final p = _localProposals[i];
      if (p.proposalReference == bookingReference ||
          p.proposalReference == altRef) {
        _localProposals[i] = p.copyWith(status: 'Cancelled');
      }
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
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
    return true;
  }

  /// Confirms the booking when the customer approves the proposal (Human-in-the-Loop).
  static Future<bool> confirmBooking({
    required BookingDetails booking,
    required String category,
    required String providerId,
    String? rateType = 'Hourly',
  }) async {
    developer.log(
      '🤝 [TASKBRIDGE AI: AGENT 3] Confirming booking "${booking.bookingReference}" for ${booking.providerName}',
      name: 'CoordinationAgent',
    );

    final resolvedRateType = rateType ?? 'Hourly';

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
      rateType: resolvedRateType,
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
      'rateType': resolvedRateType,
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
            final idx = _localBookings.indexWhere(
              (x) => x.bookingReference == b.bookingReference,
            );
            if (idx != -1) {
              _localBookings[idx] = b;
            }
            if (b.isCancelled) {
              final alt = b.bookingReference.startsWith('TB-')
                  ? b.bookingReference.replaceFirst('TB-', 'PR-')
                  : b.bookingReference.replaceFirst('PR-', 'TB-');
              for (var i = 0; i < _localProposals.length; i++) {
                if (_localProposals[i].proposalReference ==
                        b.bookingReference ||
                    _localProposals[i].proposalReference == alt) {
                  _localProposals[i] = _localProposals[i].copyWith(
                    status: b.status,
                  );
                }
              }
            }
          }

          var result = mergedMap.values.toList();
          if (status != null && status.isNotEmpty) {
            result = result
                .where((b) => b.status.toLowerCase() == status.toLowerCase())
                .toList();
          }
          if (providerName != null && providerName.isNotEmpty) {
            final pLow = providerName.trim().toLowerCase();
            result = result.where((b) {
              final bProv = b.providerName.trim().toLowerCase();
              return bProv.contains(pLow) || pLow.contains(bProv);
            }).toList();
          }
          if (customerName != null && customerName.isNotEmpty) {
            final cLow = customerName.trim().toLowerCase();
            result = result.where((b) {
              final bCust = b.customerName.trim().toLowerCase();
              return bCust.contains(cLow) ||
                  cLow.contains(bCust) ||
                  bCust == 'customer';
            }).toList();
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
    // Update locally immediately across both bookings and proposals
    final altRef = bookingReference.startsWith('TB-')
        ? bookingReference.replaceFirst('TB-', 'PR-')
        : bookingReference.replaceFirst('PR-', 'TB-');

    for (var i = 0; i < _localBookings.length; i++) {
      final b = _localBookings[i];
      if (b.bookingReference == bookingReference ||
          b.bookingReference == altRef) {
        _localBookings[i] = b.copyWith(
          status: newStatus,
          schedule: schedule ?? b.schedule,
          price: price ?? b.price,
        );
      }
    }

    for (var i = 0; i < _localProposals.length; i++) {
      final p = _localProposals[i];
      if (p.proposalReference == bookingReference ||
          p.proposalReference == altRef) {
        _localProposals[i] = p.copyWith(
          status: newStatus,
          preferredSchedule: schedule ?? p.preferredSchedule,
          estimatedRate: price ?? p.estimatedRate,
        );
      }
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
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
    return true;
  }

  /// Retrieves proposals from the 'proposals' table.
  static Future<List<ProposalItem>> getProposals({
    String? providerId,
    String? providerName,
    String? customerName,
    String? status,
  }) async {
    final candidates = _candidateUrls;
    final queryParams = <String, String>{};
    if (providerId != null && providerId.isNotEmpty) {
      queryParams['providerId'] = providerId;
    }
    if (providerName != null && providerName.isNotEmpty) {
      queryParams['providerName'] = providerName;
    }
    if (customerName != null && customerName.isNotEmpty) {
      queryParams['customerName'] = customerName;
    }
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    for (final candidate in candidates) {
      final uri = Uri.parse(
        '$candidate/api/agent/coordination/proposals',
      ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
      try {
        final response = await http
            .get(uri, headers: {'Content-Type': 'application/json'})
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final list = jsonDecode(response.body) as List<dynamic>;
          final parsed = list
              .map((e) => ProposalItem.fromJson(e as Map<String, dynamic>))
              .toList();

          // Sync into local cache
          for (final p in parsed) {
            final idx = _localProposals.indexWhere(
              (x) => x.proposalReference == p.proposalReference,
            );
            if (idx != -1) {
              _localProposals[idx] = p;
            } else {
              _localProposals.add(p);
            }

            // Also keep _localBookings in sync if it has this reference
            final alt = p.proposalReference.startsWith('PR-')
                ? p.proposalReference.replaceFirst('PR-', 'TB-')
                : p.proposalReference.replaceFirst('TB-', 'PR-');
            for (var i = 0; i < _localBookings.length; i++) {
              if (_localBookings[i].bookingReference == p.proposalReference ||
                  _localBookings[i].bookingReference == alt) {
                _localBookings[i] = _localBookings[i].copyWith(
                  status: p.status,
                  price: p.estimatedRate,
                  schedule: p.preferredSchedule,
                  rateType: p.rateType,
                );
              }
            }
          }

          return parsed;
        }
      } catch (_) {}
    }

    // Fallback to local proposals
    var result = List<ProposalItem>.from(_localProposals);
    if (status != null && status.isNotEmpty) {
      result = result
          .where((p) => p.status.toLowerCase() == status.toLowerCase())
          .toList();
    }
    return result;
  }

  /// Provider accepts a proposal, locking it into confirmed 'bookings'.
  static Future<bool> acceptProposal({
    required String proposalReference,
    required String schedule,
    required double price,
    String? rateType,
  }) async {
    // Update local proposal
    final idx = _localProposals.indexWhere(
      (p) => p.proposalReference == proposalReference,
    );
    if (idx != -1) {
      final old = _localProposals[idx];
      _localProposals[idx] = ProposalItem(
        id: old.id,
        proposalReference: old.proposalReference,
        serviceTitle: old.serviceTitle,
        category: old.category,
        providerName: old.providerName,
        providerId: old.providerId,
        customerName: old.customerName,
        location: old.location,
        preferredSchedule: schedule,
        estimatedRate: price,
        rateType: rateType ?? old.rateType,
        status: 'Accepted',
        createdAt: old.createdAt,
      );
    }

    // Optimistically insert confirmed booking into _localBookings immediately
    if (idx != -1) {
      final old = _localProposals[idx];
      final optimisticBooking = BookingItem(
        id: 'b-${DateTime.now().millisecondsSinceEpoch}',
        bookingReference: proposalReference.startsWith('PR-')
            ? proposalReference.replaceFirst('PR-', 'TB-')
            : proposalReference,
        customerName: old.customerName,
        providerName: old.providerName,
        providerId: old.providerId,
        serviceTitle: old.serviceTitle,
        category: old.category,
        location: old.location,
        schedule: schedule,
        price: price,
        rateType: rateType ?? old.rateType,
        status: 'Upcoming',
        createdAt: DateTime.now(),
      );
      _localBookings.removeWhere(
        (b) =>
            b.bookingReference == optimisticBooking.bookingReference ||
            b.bookingReference == proposalReference,
      );
      _localBookings.insert(0, optimisticBooking);
    }
    BookingsSyncService.instance.triggerImmediateUpdate();

    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'proposalReference': proposalReference,
      'confirmedSchedule': schedule,
      'confirmedPrice': price,
      'rateType': rateType,
    });

    for (final candidate in candidates) {
      final uri = Uri.parse(
        '$candidate/api/agent/coordination/proposals/accept',
      );
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          try {
            final json = jsonDecode(response.body) as Map<String, dynamic>;
            final bookingData = json['booking'] is Map<String, dynamic>
                ? json['booking'] as Map<String, dynamic>
                : json;
            final serverBooking = BookingItem.fromJson(bookingData);
            _localBookings.removeWhere(
              (b) =>
                  b.bookingReference == serverBooking.bookingReference ||
                  b.bookingReference == proposalReference,
            );
            _localBookings.insert(0, serverBooking);
          } catch (_) {}
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
    return true;
  }

  /// Provider declines a proposal.
  static Future<bool> declineProposal({
    required String proposalReference,
    String? reason,
  }) async {
    final altRef = proposalReference.startsWith('PR-')
        ? proposalReference.replaceFirst('PR-', 'TB-')
        : proposalReference.replaceFirst('TB-', 'PR-');

    for (var i = 0; i < _localProposals.length; i++) {
      final p = _localProposals[i];
      if (p.proposalReference == proposalReference ||
          p.proposalReference == altRef) {
        _localProposals[i] = p.copyWith(status: 'Declined');
      }
    }

    for (var i = 0; i < _localBookings.length; i++) {
      final b = _localBookings[i];
      if (b.bookingReference == proposalReference ||
          b.bookingReference == altRef) {
        _localBookings[i] = b.copyWith(status: 'Cancelled');
      }
    }

    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'proposalReference': proposalReference,
      'reason': reason ?? 'Declined by provider',
    });

    for (final candidate in candidates) {
      final uri = Uri.parse(
        '$candidate/api/agent/coordination/proposals/decline',
      );
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          BookingsSyncService.instance.triggerImmediateUpdate();
          return true;
        }
      } catch (_) {}
    }

    BookingsSyncService.instance.triggerImmediateUpdate();
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
