import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../models/coordination_models.dart';
import '../models/matching_models.dart';
import '../models/planning_models.dart';
import 'bookings_sync_service.dart';

class CoordinationApi {
  static String? _workingBaseUrl;

  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }

  /// Sends JobPlan and candidate providers to Agent 3 (Coordination Agent) to evaluate quotes
  /// and formulate the best booking proposal.
  static Future<BookingProposalResponse> evaluateQuotations({
    required JobPlan jobPlan,
    List<MatchedProvider>? candidateProviders,
    String? customerId,
    String? customerName,
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

    final payloadMap = <String, dynamic>{
      'jobPlan': jobPlan.toJson(),
      'candidateProviders': quotesJson,
    };
    if (customerId != null) payloadMap['customerId'] = customerId;
    if (customerName != null) payloadMap['customerName'] = customerName;
    final payload = jsonEncode(payloadMap);

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
    return _generateFallbackProposal(
      jobPlan,
      candidateProviders,
      customerId: customerId,
      customerName: customerName,
    );
  }

  static final List<BookingItem> _localBookings = [];
  static final List<ProposalItem> _localProposals = [];

  /// Persists a newly created quotation proposal (status = "Requested") to the proposals table.
  static Future<bool> createQuotationRequest({
    required BookingDetails booking,
    required String category,
    required String providerId,
    String? customerId,
    String? customerName,
    String? rateType = 'Hourly',
    String? notes,
  }) async {
    developer.log(
      '📝 [TASKBRIDGE AI: AGENT 3] Creating quotation proposal "${booking.bookingReference}" for ${booking.providerName}',
      name: 'CoordinationAgent',
    );

    final resolvedRateType = rateType ?? 'Hourly';
    final resolvedCustomerName =
        (customerName != null && customerName.isNotEmpty)
        ? customerName
        : (booking.customerName.isNotEmpty ? booking.customerName : 'Customer');
    final resolvedCustomerId = customerId ?? booking.customerId;
    final resolvedNotes = notes ?? booking.notes;

    final newProp = ProposalItem(
      id: 'pr-${DateTime.now().millisecondsSinceEpoch}',
      proposalReference: booking.bookingReference,
      serviceTitle: booking.serviceTitle,
      category: category,
      providerName: booking.providerName,
      providerId: providerId,
      customerName: resolvedCustomerName,
      location: booking.location,
      preferredSchedule: booking.schedule,
      estimatedRate: booking.price,
      rateType: resolvedRateType,
      notes: resolvedNotes,
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
      customerName: resolvedCustomerName,
      providerName: booking.providerName,
      serviceTitle: booking.serviceTitle,
      category: category,
      location: booking.location,
      schedule: booking.schedule,
      price: booking.price,
      rateType: resolvedRateType,
      notes: resolvedNotes,
      status: 'Requested',
      createdAt: DateTime.now(),
    );

    _localBookings.removeWhere(
      (b) => b.bookingReference == booking.bookingReference,
    );
    _localBookings.insert(0, newItem);

    final payloadMap = <String, dynamic>{
      'bookingReference': booking.bookingReference,
      'providerId': providerId,
      'providerName': booking.providerName,
      'customerName': resolvedCustomerName,
      'serviceTitle': booking.serviceTitle,
      'category': category,
      'location': booking.location,
      'schedule': booking.schedule,
      'price': booking.price,
      'rateType': resolvedRateType,
      'status': 'Requested',
    };
    if (resolvedCustomerId != null) {
      payloadMap['customerId'] = resolvedCustomerId;
    }
    if (resolvedNotes != null && resolvedNotes.isNotEmpty) {
      payloadMap['notes'] = resolvedNotes;
    }
    final payload = jsonEncode(payloadMap);

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

    final altRef = bookingReference.startsWith('TB-')
        ? bookingReference.replaceFirst('TB-', 'PR-')
        : bookingReference.replaceFirst('PR-', 'TB-');
    final baseRef = bookingReference
        .replaceFirst('TB-', '')
        .replaceFirst('PR-', '');

    for (var i = 0; i < _localBookings.length; i++) {
      final b = _localBookings[i];
      final bBase = b.bookingReference
          .replaceFirst('TB-', '')
          .replaceFirst('PR-', '');
      if (b.bookingReference == bookingReference ||
          b.bookingReference == altRef ||
          bBase == baseRef) {
        if (b.isActive || b.status.toLowerCase() == 'in progress') {
          return false;
        }
        final newSchedule = availableTime != null && availableTime.isNotEmpty
            ? '$availableTime · ${b.location}'
            : b.schedule;
        _localBookings[i] = BookingItem(
          id: b.id,
          bookingReference: b.bookingReference,
          customerName: b.customerName,
          customerPhone: b.customerPhone,
          providerName: b.providerName,
          providerId: b.providerId,
          providerPhone: b.providerPhone,
          serviceTitle: b.serviceTitle,
          category: b.category,
          location: b.location,
          schedule: newSchedule,
          price: counterPrice,
          rateType: rateType ?? b.rateType,
          status: targetStatus,
          createdAt: b.createdAt,
        );
      }
    }

    for (var i = 0; i < _localProposals.length; i++) {
      final p = _localProposals[i];
      final pBase = p.proposalReference
          .replaceFirst('TB-', '')
          .replaceFirst('PR-', '');
      if (p.proposalReference == bookingReference ||
          p.proposalReference == altRef ||
          pBase == baseRef) {
        final newSchedule = availableTime != null && availableTime.isNotEmpty
            ? '$availableTime · ${p.location}'
            : p.preferredSchedule;
        _localProposals[i] = ProposalItem(
          id: p.id,
          proposalReference: p.proposalReference,
          serviceTitle: p.serviceTitle,
          category: p.category,
          providerName: p.providerName,
          providerId: p.providerId,
          providerPhone: p.providerPhone,
          customerName: p.customerName,
          customerPhone: p.customerPhone,
          location: p.location,
          preferredSchedule: newSchedule,
          estimatedRate: counterPrice,
          rateType: rateType ?? p.rateType,
          status: targetStatus,
          createdAt: p.createdAt,
        );
      }
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

  /// Evaluates a rebid against the provider's standard hourly rate using the Coordination Agent.
  static Future<RebidEvaluationResult?> evaluateRebid({
    required String bookingReference,
    required double proposedPrice,
    required String senderRole,
  }) async {
    final payload = jsonEncode({
      'bookingReference': bookingReference,
      'proposedPrice': proposedPrice,
      'senderRole': senderRole,
    });

    for (final candidate in _candidateUrls) {
      final uri = Uri.parse('$candidate/api/agent/coordination/rebid/evaluate');
      try {
        final response = await http
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: payload,
            )
            .timeout(const Duration(seconds: 4));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return RebidEvaluationResult.fromJson(data);
        }
      } catch (_) {}
    }
    return null;
  }

  /// Cancels an active quotation request or booking.
  static Future<bool> cancelBooking({
    required String bookingReference,
    String? reason,
    String cancelledByRole = 'Customer',
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
      'cancelledByRole': cancelledByRole,
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

          // Merge with local newly created bookings using baseKey deduplication
          final mergedMap = <String, BookingItem>{};
          for (final b in _localBookings) {
            final baseKey = b.bookingReference
                .replaceFirst('TB-', '')
                .replaceFirst('PR-', '');
            mergedMap[baseKey] = b;
          }
          for (final b in remoteBookings) {
            final baseKey = b.bookingReference
                .replaceFirst('TB-', '')
                .replaceFirst('PR-', '');
            // Authoritative remote booking overrides local entry
            mergedMap[baseKey] = b;

            final idx = _localBookings.indexWhere(
              (x) =>
                  x.bookingReference == b.bookingReference ||
                  x.bookingReference
                          .replaceFirst('TB-', '')
                          .replaceFirst('PR-', '') ==
                      baseKey,
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
          if (providerId != null && providerId.isNotEmpty) {
            final pIdLower = providerId.trim().toLowerCase();
            result = result.where((b) {
              if (b.providerId != null && b.providerId!.isNotEmpty) {
                return b.providerId!.toLowerCase() == pIdLower;
              }
              if (providerName != null && providerName.isNotEmpty) {
                return b.providerName.trim().toLowerCase() ==
                    providerName.trim().toLowerCase();
              }
              return false;
            }).toList();
          } else if (providerName != null && providerName.isNotEmpty) {
            final pLow = providerName.trim().toLowerCase();
            result = result.where((b) {
              final bProv = b.providerName.trim().toLowerCase();
              return bProv == pLow;
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

          var result = parsed;
          if (providerId != null && providerId.isNotEmpty) {
            final pIdLower = providerId.trim().toLowerCase();
            result = result.where((p) {
              if (p.providerId != null && p.providerId!.isNotEmpty) {
                return p.providerId!.toLowerCase() == pIdLower;
              }
              if (providerName != null && providerName.isNotEmpty) {
                return p.providerName.trim().toLowerCase() ==
                    providerName.trim().toLowerCase();
              }
              return false;
            }).toList();
          } else if (providerName != null && providerName.isNotEmpty) {
            final pLow = providerName.trim().toLowerCase();
            result = result
                .where((p) => p.providerName.trim().toLowerCase() == pLow)
                .toList();
          }
          return result;
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
    String? acceptedByRole,
  }) async {
    final altRef = proposalReference.startsWith('TB-')
        ? proposalReference.replaceFirst('TB-', 'PR-')
        : proposalReference.replaceFirst('PR-', 'TB-');
    final propBase = proposalReference
        .replaceFirst('TB-', '')
        .replaceFirst('PR-', '');

    // Resolve effective agreed price: if passed price <= 0, fallback to local proposal rebid rate
    double effectivePrice = price;
    if (effectivePrice <= 0) {
      final pMatch = _localProposals.where(
        (p) =>
            p.proposalReference == proposalReference ||
            p.proposalReference == altRef ||
            p.proposalReference
                    .replaceFirst('TB-', '')
                    .replaceFirst('PR-', '') ==
                propBase,
      );
      if (pMatch.isNotEmpty && pMatch.first.estimatedRate > 0) {
        effectivePrice = pMatch.first.estimatedRate;
      }
    }

    // Update local proposal
    for (var i = 0; i < _localProposals.length; i++) {
      final p = _localProposals[i];
      final pBase = p.proposalReference
          .replaceFirst('TB-', '')
          .replaceFirst('PR-', '');
      if (p.proposalReference == proposalReference ||
          p.proposalReference == altRef ||
          pBase == propBase) {
        _localProposals[i] = ProposalItem(
          id: p.id,
          proposalReference: p.proposalReference,
          serviceTitle: p.serviceTitle,
          category: p.category,
          providerName: p.providerName,
          providerId: p.providerId,
          providerPhone: p.providerPhone,
          customerName: p.customerName,
          customerPhone: p.customerPhone,
          location: p.location,
          preferredSchedule: schedule,
          estimatedRate: effectivePrice,
          rateType: rateType ?? p.rateType,
          status: 'Accepted',
          createdAt: p.createdAt,
        );
      }
    }

    // Optimistically insert confirmed booking into _localBookings immediately
    final matchingProps = _localProposals.where(
      (p) =>
          p.proposalReference == proposalReference ||
          p.proposalReference == altRef ||
          p.proposalReference.replaceFirst('TB-', '').replaceFirst('PR-', '') ==
              propBase,
    );
    final pSource = matchingProps.isNotEmpty ? matchingProps.first : null;

    final optimisticBooking = BookingItem(
      id: 'b-${DateTime.now().millisecondsSinceEpoch}',
      bookingReference: proposalReference.startsWith('PR-')
          ? proposalReference.replaceFirst('PR-', 'TB-')
          : proposalReference,
      customerName: pSource?.customerName ?? 'Customer',
      customerPhone: pSource?.customerPhone,
      providerName: pSource?.providerName ?? 'Provider',
      providerId: pSource?.providerId,
      providerPhone: pSource?.providerPhone,
      serviceTitle: pSource?.serviceTitle ?? 'Service',
      category: pSource?.category ?? 'General',
      location: pSource?.location ?? '',
      schedule: schedule,
      price: effectivePrice,
      rateType: rateType ?? pSource?.rateType ?? 'Hourly',
      status: 'Upcoming',
      createdAt: DateTime.now(),
    );

    _localBookings.removeWhere(
      (b) =>
          b.bookingReference.replaceFirst('TB-', '').replaceFirst('PR-', '') ==
          propBase,
    );
    _localBookings.insert(0, optimisticBooking);
    BookingsSyncService.instance.triggerImmediateUpdate();

    final candidates = _candidateUrls;
    final payload = jsonEncode({
      'proposalReference': proposalReference,
      'confirmedSchedule': schedule,
      'confirmedPrice': effectivePrice,
      'rateType': rateType,
      'acceptedByRole': acceptedByRole,
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
            final srvBase = serverBooking.bookingReference
                .replaceFirst('TB-', '')
                .replaceFirst('PR-', '');
            _localBookings.removeWhere(
              (b) =>
                  b.bookingReference
                      .replaceFirst('TB-', '')
                      .replaceFirst('PR-', '') ==
                  srvBase,
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
    List<MatchedProvider>? candidateProviders, {
    String? customerId,
    String? customerName,
  }) {
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

    final resolvedCust = (customerName != null && customerName.isNotEmpty)
        ? customerName
        : 'Customer';

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
        customerId: customerId,
        customerName: resolvedCust,
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
