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

  Future<void> _declineJob(BookingItem booking) async {
    final isProposal = booking.bookingReference.startsWith('PR-');
    final success = isProposal
        ? await CoordinationApi.declineProposal(
            proposalReference: booking.bookingReference,
            reason: 'Declined by provider',
          )
        : await CoordinationApi.cancelBooking(
            bookingReference: booking.bookingReference,
            reason: 'Declined by provider',
          );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isProposal
                ? 'Proposal #${booking.bookingReference} declined.'
                : 'Job #${booking.bookingReference} has been declined.',
          ),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _loadBookings();
    }
  }

  void _showCounterBidModal(BookingItem booking) {
    final palette = AppPalette.of(context);
    String rateType = booking.rateType;
    final priceController = TextEditingController(
      text: booking.price.toInt().toString(),
    );
    final timeController = TextEditingController(
      text: booking.schedule.contains('·')
          ? booking.schedule.split('·').first.trim()
          : booking.schedule,
    );
    final notesController = TextEditingController(
      text: 'Specialist revised quotation with full labor, tools, and testing.',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.s20,
                right: AppSpacing.s20,
                top: AppSpacing.s8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.edit_note_rounded,
                          color: palette.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Counter-Offer / Edit Bid',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Job: ${booking.serviceTitle} · Customer: ${booking.customerName}',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                    const SizedBox(height: 14),

                    // Customer's Exact Requested Time Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.soft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.primary.withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 18,
                            color: palette.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Customer's Exact Requested Time:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  booking.schedule,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: palette.primary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pricing Type Selector (Hourly vs Fixed)
                    Text(
                      'Pricing Type',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setSheetState(() => rateType = 'Hourly'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: rateType.toLowerCase() == 'hourly'
                                    ? palette.primary.withValues(alpha: 0.12)
                                    : palette.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: rateType.toLowerCase() == 'hourly'
                                      ? palette.primary
                                      : palette.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 16,
                                    color: rateType.toLowerCase() == 'hourly'
                                        ? palette.primary
                                        : palette.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Hourly (/hr)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: rateType.toLowerCase() == 'hourly'
                                          ? palette.primary
                                          : palette.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setSheetState(() => rateType = 'Fixed'),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: rateType.toLowerCase() == 'fixed'
                                    ? palette.primary.withValues(alpha: 0.12)
                                    : palette.surface,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: rateType.toLowerCase() == 'fixed'
                                      ? palette.primary
                                      : palette.border,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sell_outlined,
                                    size: 16,
                                    color: rateType.toLowerCase() == 'fixed'
                                        ? palette.primary
                                        : palette.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Fixed Total',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: rateType.toLowerCase() == 'fixed'
                                          ? palette.primary
                                          : palette.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Price field
                    Text(
                      rateType.toLowerCase() == 'hourly'
                          ? 'Your Quoted Hourly Rate (Rs./hr)'
                          : 'Your Quoted Total Price (Rs.)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixText: 'Rs. ',
                        suffixText: rateType.toLowerCase() == 'hourly'
                            ? '/ hr'
                            : 'fixed total',
                        suffixStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: palette.muted,
                        ),
                        prefixStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: palette.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Arrival Time field with interactive time picker
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Attendance Time',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () async {
                            final now = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay(
                                hour: (now.hour + 1) % 24,
                                minute: 0,
                              ),
                            );
                            if (picked != null) {
                              final h = picked.hourOfPeriod == 0
                                  ? 12
                                  : picked.hourOfPeriod;
                              final m = picked.minute.toString().padLeft(
                                2,
                                '0',
                              );
                              final p = picked.period == DayPeriod.am
                                  ? 'AM'
                                  : 'PM';
                              final timeStr = '$h:$m $p';
                              final current = timeController.text.trim();
                              String datePart = 'Tomorrow';
                              if (current.contains('·')) {
                                datePart = current.split('·').first.trim();
                              } else if (current.toLowerCase().contains(
                                'tomorrow',
                              )) {
                                datePart = 'Tomorrow';
                              }
                              setSheetState(() {
                                timeController.text = '$datePart at $timeStr';
                              });
                            }
                          },
                          icon: Icon(
                            Icons.access_time_rounded,
                            size: 16,
                            color: palette.primary,
                          ),
                          label: Text(
                            'Pick Time',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: palette.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 18,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.access_time_filled_rounded,
                            color: palette.primary,
                          ),
                          onPressed: () async {
                            final now = TimeOfDay.now();
                            final picked = await showTimePicker(
                              context: ctx,
                              initialTime: TimeOfDay(
                                hour: (now.hour + 1) % 24,
                                minute: 0,
                              ),
                            );
                            if (picked != null) {
                              final h = picked.hourOfPeriod == 0
                                  ? 12
                                  : picked.hourOfPeriod;
                              final m = picked.minute.toString().padLeft(
                                2,
                                '0',
                              );
                              final p = picked.period == DayPeriod.am
                                  ? 'AM'
                                  : 'PM';
                              final timeStr = '$h:$m $p';
                              final current = timeController.text.trim();
                              String datePart = 'Tomorrow';
                              if (current.contains('·')) {
                                datePart = current.split('·').first.trim();
                              } else if (current.toLowerCase().contains(
                                'tomorrow',
                              )) {
                                datePart = 'Tomorrow';
                              }
                              setSheetState(() {
                                timeController.text = '$datePart at $timeStr';
                              });
                            }
                          },
                        ),
                        hintText: 'e.g. Tomorrow at 10:30 AM',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick time slot chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final slot in [
                            '8:30 AM',
                            '10:00 AM',
                            '11:30 AM',
                            '2:00 PM',
                            '4:00 PM',
                            '5:30 PM',
                          ])
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(
                                  slot,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                backgroundColor:
                                    timeController.text.contains(slot)
                                    ? palette.primary.withValues(alpha: 0.18)
                                    : palette.surface,
                                side: BorderSide(
                                  color: timeController.text.contains(slot)
                                      ? palette.primary
                                      : palette.border,
                                ),
                                onPressed: () {
                                  final current = timeController.text.trim();
                                  String datePart = 'Tomorrow';
                                  if (current.contains('·')) {
                                    datePart = current.split('·').first.trim();
                                  } else if (current.toLowerCase().contains(
                                    'tomorrow',
                                  )) {
                                    datePart = 'Tomorrow';
                                  }
                                  setSheetState(() {
                                    timeController.text = '$datePart at $slot';
                                  });
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Notes
                    Text(
                      'Quotation Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Notes for the customer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.onPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final price =
                              double.tryParse(priceController.text.trim()) ??
                              booking.price;
                          final time = timeController.text.trim();
                          final note = notesController.text.trim();
                          final messenger = ScaffoldMessenger.of(context);

                          Navigator.pop(ctx);
                          final success =
                              await CoordinationApi.submitCounterBid(
                                bookingReference: booking.bookingReference,
                                counterPrice: price,
                                rateType: rateType,
                                availableTime: time,
                                notes: note,
                                sender: 'provider',
                              );

                          if (success && mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Counter-bid of Rs. ${price.toInt()} sent to customer!',
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
                        },
                        child: const Text(
                          'Submit Counter-Bid',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final incomingRequests = _bookings.where((b) => b.isRequested).toList();
    final upcomingJobs = _bookings.where((b) => b.isUpcoming).toList();
    final activeJobs = _bookings
        .where(
          (b) =>
              b.status.toLowerCase() == 'active' ||
              b.status.toLowerCase() == 'in progress',
        )
        .toList();
    final completedJobs = _bookings
        .where((b) => b.status.toLowerCase() == 'completed')
        .toList();

    double totalEarnings = completedJobs.fold(0.0, (sum, b) => sum + b.price);
    if (totalEarnings == 0 &&
        widget.user.providerEarnings != null &&
        widget.user.providerEarnings! > 0) {
      totalEarnings = widget.user.providerEarnings!;
    }

    final activePendingText = activeJobs.isNotEmpty
        ? '${activeJobs.length} Active'
        : (upcomingJobs.isNotEmpty
              ? '${upcomingJobs.length} Upcoming'
              : (incomingRequests.isNotEmpty
                    ? '${incomingRequests.length} Pending'
                    : '0 Active'));

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadBookings,
          color: palette.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROVIDER DASHBOARD',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Welcome back,\n${widget.user.fullName.split(' ').first}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onPressed: widget.onSwitchToCustomer,
                      icon: const Icon(AppIcons.switchMode, size: 18),
                      label: const Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s20),

                // ── Quick Metrics Row (Live & Dynamic) ──
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'This Month',
                        value: 'Rs. ${totalEarnings.toStringAsFixed(0)}',
                        icon: AppIcons.trendUp,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Active Jobs',
                        value: activePendingText,
                        icon: AppIcons.briefcase,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        label: 'Rating',
                        value: _ratingText,
                        icon: AppIcons.star,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.s24),

                // ── Incoming Requests Section (Live) ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Incoming Requests',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: palette.text,
                      ),
                    ),
                    if (incomingRequests.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${incomingRequests.length} New',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: palette.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.primary,
                        ),
                      ),
                    ),
                  )
                else if (incomingRequests.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.s24),
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.task_alt_rounded,
                          size: 40,
                          color: palette.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'All Caught Up!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No pending job requests right now. New customer bookings confirmed through AI will appear here in real time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: palette.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...incomingRequests.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _LiveJobCard(
                        booking: booking,
                        onAccept: () => _acceptJob(booking),
                        onDecline: () => _declineJob(booking),
                        onCounterBid: () => _showCounterBidModal(booking),
                      ),
                    ),
                  ),

                // ── Upcoming Confirmed Jobs Section ──
                if (upcomingJobs.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.s24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Upcoming Confirmed Jobs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${upcomingJobs.length} Confirmed',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...upcomingJobs.map(
                    (booking) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BookingCardWidget(
                        title: booking.serviceTitle,
                        providerName: booking.customerName,
                        reference: booking.bookingReference,
                        schedule: booking.schedule,
                        price: booking.isHourly
                            ? 'Rs. ${booking.price.toInt()}/hr'
                            : 'Rs. ${booking.price.toInt()}',
                        status: BookingStatus.upcoming,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProviderJobDetailsPage(booking: booking),
                            ),
                          );
                          _loadBookings();
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: palette.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: palette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveJobCard extends StatelessWidget {
  final BookingItem booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback? onCounterBid;

  const _LiveJobCard({
    required this.booking,
    required this.onAccept,
    required this.onDecline,
    this.onCounterBid,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (booking.isCustomerCountered) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'CUSTOMER RE-BID RECEIVED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.serviceTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (booking.customerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Customer: ${booking.customerName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: palette.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                booking.priceFormatted,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(AppIcons.location, size: 14, color: palette.muted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.location,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(AppIcons.clock, size: 14, color: palette.muted),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  booking.schedule,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: palette.muted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.text,
                    side: BorderSide(color: palette.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: onAccept,
                  child: Text(
                    booking.isCustomerCountered
                        ? 'Accept Re-Bid'
                        : (booking.isRequested ? 'Accept Quote' : 'Accept Job'),
                  ),
                ),
              ),
            ],
          ),
          if (booking.isRequested && onCounterBid != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.primary,
                  side: BorderSide(
                    color: palette.primary.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onPressed: onCounterBid,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text(
                  'Counter-Offer / Edit Bid',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
