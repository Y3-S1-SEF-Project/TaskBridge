import 'dart:async';
import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../ai/services/coordination_api.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/widgets/booking_card_widget.dart';
import 'provider_job_details_page.dart';

class ProviderDashboardPage extends StatefulWidget {
  final AuthUser user;
  final VoidCallback onSwitchToCustomer;

  const ProviderDashboardPage({
    super.key,
    required this.user,
    required this.onSwitchToCustomer,
  });

  @override
  State<ProviderDashboardPage> createState() => _ProviderDashboardPageState();
}

class _ProviderDashboardPageState extends State<ProviderDashboardPage> {
  List<BookingItem> _bookings = [];
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

  String get _ratingText {
    if (_feedbacks.isEmpty) return '5.0 ★';
    final avg =
        _feedbacks.fold<double>(0.0, (acc, f) => acc + f.rating.toDouble()) /
        _feedbacks.length;
    return '${avg.toStringAsFixed(1)} ★';
  }

  @override
  void initState() {
    super.initState();
    BookingsSyncService.instance.addListener(_onSyncUpdate);
    _loadBookings();
    _pollingTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        _loadBookings(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    BookingsSyncService.instance.removeListener(_onSyncUpdate);
    super.dispose();
  }

  void _onSyncUpdate() {
    if (mounted) {
      _loadBookings(silent: true);
    }
  }

  Future<void> _loadBookings({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final bookingsFuture = CoordinationApi.getBookings(
        providerId: widget.user.id,
        providerName: widget.user.fullName,
      );
      final proposalsFuture = CoordinationApi.getProposals(
        providerId: widget.user.id,
        providerName: widget.user.fullName,
      );
      final feedbacksFuture = ReviewApi.getProviderFeedbacks(widget.user.id);

      final results = await Future.wait([
        bookingsFuture,
        proposalsFuture,
        feedbacksFuture,
      ]);
      final list = results[0] as List<BookingItem>;
      final propList = results[1] as List<ProposalItem>;
      final feedbackList = results[2] as List<FeedbackModel>;

      if (mounted) {
        final provName = widget.user.fullName.trim().toLowerCase();
        final provId = widget.user.id.toLowerCase();

        final filteredBookings = list.where((b) {
          if (b.providerId != null && b.providerId!.toLowerCase() == provId) {
            return true;
          }
          final bProv = b.providerName.trim().toLowerCase();
          return bProv.contains(provName) || provName.contains(bProv);
        }).toList();

        final filteredProposals = propList
            .where((p) {
              final s = p.status.toLowerCase();
              if (s == 'accepted' || s == 'declined' || s == 'cancelled') {
                return false;
              }
              if (p.providerId != null &&
                  p.providerId!.toLowerCase() == provId) {
                return true;
              }
              final pProv = p.providerName.trim().toLowerCase();
              return pProv.contains(provName) || provName.contains(pProv);
            })
            .map((p) => p.toBookingItem())
            .toList();

        final bookingRefs = <String>{};
        final combined = <BookingItem>[];
        for (final p in filteredProposals) {
          bookingRefs.add(p.bookingReference);
          combined.add(p);
        }
        for (final b in filteredBookings) {
          if (b.bookingReference.startsWith('PR-') && bookingRefs.contains(b.bookingReference)) {
            continue;
          }
          combined.add(b);
        }

        setState(() {
          _bookings = combined;
          _feedbacks = feedbackList;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptJob(BookingItem booking) async {
    final isProposal = booking.bookingReference.startsWith('PR-');
    final success = isProposal
        ? await CoordinationApi.acceptProposal(
            proposalReference: booking.bookingReference,
            price: booking.price,
            schedule: booking.schedule,
          )
        : await CoordinationApi.updateBookingStatus(
            bookingReference: booking.bookingReference,
            newStatus: 'Active',
          );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isProposal
                ? 'Proposal #${booking.bookingReference} accepted! Appointment confirmed.'
                : 'Job #${booking.bookingReference} moved to Active Jobs!',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _loadBookings();
    }
  }