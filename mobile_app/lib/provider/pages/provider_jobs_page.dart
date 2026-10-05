import 'dart:async';
import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/bookings_sync_service.dart';
import '../../ai/services/coordination_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/widgets/booking_card_widget.dart';
import 'provider_job_details_page.dart';

class ProviderJobsPage extends StatefulWidget {
  final AuthUser? user;
  const ProviderJobsPage({super.key, this.user});

  @override
  State<ProviderJobsPage> createState() => _ProviderJobsPageState();
}

class _ProviderJobsPageState extends State<ProviderJobsPage> {
  List<BookingItem> _bookings = [];
  List<ProposalItem> _proposals = [];
  bool _isLoading = true;
  Timer? _pollingTimer;

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
      final provName = widget.user?.fullName.trim().toLowerCase();
      final provId = widget.user?.id.toLowerCase();

      final bookingsFuture = CoordinationApi.getBookings(
        providerId: widget.user?.id,
        providerName: widget.user?.fullName,
      );
      final proposalsFuture = CoordinationApi.getProposals(
        providerId: widget.user?.id,
        providerName: widget.user?.fullName,
      );

      final results = await Future.wait([bookingsFuture, proposalsFuture]);
      final list = results[0] as List<BookingItem>;
      final propList = results[1] as List<ProposalItem>;

      if (mounted) {
        final filteredBookings = list.where((b) {
          if (widget.user == null) return true;
          if (provId != null &&
              b.providerId != null &&
              b.providerId!.toLowerCase() == provId) {
            return true;
          }
          if (provName != null) {
            final bProv = b.providerName.trim().toLowerCase();
            if (bProv.contains(provName) || provName.contains(bProv)) {
              return true;
            }
          }
          return false;
        }).toList();

        final filteredProposals = propList.where((p) {
          final s = p.status.toLowerCase();
          if (s == 'accepted') {
            return false;
          }
          if (widget.user == null) return true;
          if (provId != null &&
              p.providerId != null &&
              p.providerId!.toLowerCase() == provId) {
            return true;
          }
          if (provName != null) {
            final pProv = p.providerName.trim().toLowerCase();
            if (pProv.contains(provName) || provName.contains(pProv)) {
              return true;
            }
          }
          return false;
        }).toList();

        // Deduplicate bookings where one is PR-xxxx and one is TB-xxxx for the same job
        final bookingMap = <String, BookingItem>{};
        for (final b in filteredBookings) {
          final baseKey = b.bookingReference
              .replaceFirst('TB-', '')
              .replaceFirst('PR-', '');
          if (!bookingMap.containsKey(baseKey)) {
            bookingMap[baseKey] = b;
          } else {
            final existing = bookingMap[baseKey]!;
            if (b.isUpcoming || b.isActive || b.isCompleted || b.isCancelled) {
              bookingMap[baseKey] = b;
            } else if (b.isCustomerCountered || b.isProviderCountered) {
              bookingMap[baseKey] = b;
            } else if (!existing.isCustomerCountered &&
                !existing.isProviderCountered &&
                b.bookingReference.startsWith('TB-')) {
              bookingMap[baseKey] = b;
            }
          }
        }
        final dedupedBookings = bookingMap.values.toList();

        setState(() {
          _bookings = dedupedBookings;
          _proposals = filteredProposals;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showProposalReviewModal(BookingItem booking) {
    final palette = AppPalette.of(context);
    String rateType = booking.rateType;
    final scheduleCtrl = TextEditingController(text: booking.schedule);
    final priceCtrl = TextEditingController(
      text: booking.price.toInt().toString(),
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
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.s20,
                    vertical: AppSpacing.s12,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: booking.isCustomerCountered
                                  ? Colors.teal.shade100
                                  : (booking.isProviderCountered
                                        ? Colors.indigo.shade100
                                        : Colors.amber.shade100),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              booking.isCustomerCountered
                                  ? 'CUSTOMER RE-BID'
                                  : (booking.isProviderCountered
                                        ? 'QUOTATION SENT'
                                        : 'NEW PROPOSAL'),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: booking.isCustomerCountered
                                    ? Colors.teal.shade900
                                    : (booking.isProviderCountered
                                          ? Colors.indigo.shade900
                                          : Colors.amber.shade900),
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '#${booking.bookingReference}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      Text(
                        booking.serviceTitle,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Customer: ${booking.customerName} · Location: ${booking.location}',
                        style: TextStyle(fontSize: 13, color: palette.muted),
                      ),
                      const SizedBox(height: 14),

                      if (booking.isCustomerCountered) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.teal.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                size: 18,
                                color: Colors.teal.shade800,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Customer Counter-Offered Terms',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.teal.shade900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Customer proposed Rs. ${booking.price.toInt()} and schedule "${booking.schedule}". Accepting now will immediately confirm this job into your Upcoming bookings.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.teal.shade900,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Customer Requested Time Banner
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

                      const SizedBox(height: 18),

                      // Field 1: Confirmed Attendance Time with Interactive Time Selection
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your Attendance Time',
                            style: TextStyle(
                              fontSize: 14,
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
                                final current = scheduleCtrl.text.trim();
                                String datePart = 'Tomorrow';
                                if (current.contains('·')) {
                                  datePart = current.split('·').first.trim();
                                } else if (current.toLowerCase().contains(
                                  'tomorrow',
                                )) {
                                  datePart = 'Tomorrow';
                                }
                                setSheetState(() {
                                  scheduleCtrl.text = '$datePart at $timeStr';
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
                      const SizedBox(height: 4),
                      Text(
                        'Select or specify the exact arrival time you can attend.',
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: scheduleCtrl,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.access_time_rounded),
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
                                final current = scheduleCtrl.text.trim();
                                String datePart = 'Tomorrow';
                                if (current.contains('·')) {
                                  datePart = current.split('·').first.trim();
                                } else if (current.toLowerCase().contains(
                                  'tomorrow',
                                )) {
                                  datePart = 'Tomorrow';
                                }
                                setSheetState(() {
                                  scheduleCtrl.text = '$datePart at $timeStr';
                                });
                              }
                            },
                          ),
                          hintText: 'e.g., Tomorrow at 10:30 AM',
                          filled: true,
                          fillColor: palette.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Quick time chips
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
                                      scheduleCtrl.text.contains(slot)
                                      ? palette.primary.withValues(alpha: 0.18)
                                      : palette.surface,
                                  side: BorderSide(
                                    color: scheduleCtrl.text.contains(slot)
                                        ? palette.primary
                                        : palette.border,
                                  ),
                                  onPressed: () {
                                    final current = scheduleCtrl.text.trim();
                                    String datePart = 'Tomorrow';
                                    if (current.contains('·')) {
                                      datePart = current
                                          .split('·')
                                          .first
                                          .trim();
                                    } else if (current.toLowerCase().contains(
                                      'tomorrow',
                                    )) {
                                      datePart = 'Tomorrow';
                                    }
                                    setSheetState(() {
                                      scheduleCtrl.text = '$datePart at $slot';
                                    });
                                  },
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
                          fontSize: 14,
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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
                                        color:
                                            rateType.toLowerCase() == 'hourly'
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
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

                      // Field 2: Confirmed Price / Quote
                      Text(
                        rateType.toLowerCase() == 'hourly'
                            ? 'Quoted Hourly Rate (Rs./hr)'
                            : 'Quoted Total Fixed Price (Rs.)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.payments_outlined),
                          suffixText: rateType.toLowerCase() == 'hourly'
                              ? '/ hr'
                              : 'fixed total',
                          suffixStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: palette.muted,
                          ),
                          hintText: 'e.g., 3500',
                          filled: true,
                          fillColor: palette.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Actions: Accept / Decline
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: palette.primary,
                            foregroundColor: palette.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            final parsedPrice =
                                double.tryParse(priceCtrl.text.trim()) ??
                                booking.price;
                            final confSchedule =
                                scheduleCtrl.text.trim().isNotEmpty
                                ? scheduleCtrl.text.trim()
                                : booking.schedule;

                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final success =
                                await CoordinationApi.acceptProposal(
                                  proposalReference: booking.bookingReference,
                                  schedule: confSchedule,
                                  price: parsedPrice,
                                  rateType: rateType,
                                  acceptedByRole: 'Provider',
                                );

                            if (success && mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    booking.isCustomerCountered
                                        ? 'Customer re-bid accepted! Booking confirmed into Upcoming schedule for $confSchedule.'
                                        : 'Proposal accepted! Booking locked into Upcoming schedule for $confSchedule.',
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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                booking.isCustomerCountered
                                    ? 'Accept Re-Bid & Seal Booking'
                                    : 'Accept & Confirm Schedule',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            Navigator.pop(ctx);
                            final success =
                                await CoordinationApi.declineProposal(
                                  proposalReference: booking.bookingReference,
                                );

                            if (success && mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: const Text('Proposal declined.'),
                                  backgroundColor: Colors.orange.shade800,
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
                            'Decline Proposal',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
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

    final requestsList = _proposals
        .where((p) => !p.isCancelled && p.status.toLowerCase() != 'accepted')
        .map((p) => p.toBookingItem())
        .toList();
    final upcomingList = _bookings.where((b) => b.isUpcoming).toList();
    final activeList = _bookings
        .where(
          (b) =>
              (b.isActive ||
                  b.isPendingSignOff ||
                  b.isRevisionRequested ||
                  b.isDisputed) &&
              !b.isCancelled &&
              !b.isCompleted,
        )
        .toList();

    // Past jobs: completed bookings, cancelled bookings, AND cancelled/declined proposals
    final completedOrCancelledBookings = _bookings
        .where((b) => (b.isCompleted || b.isCancelled) && !b.isDisputed)
        .toList();
    final existingPastBookingRefs = completedOrCancelledBookings
        .map((b) => b.bookingReference)
        .toSet();

    final cancelledProposals = _proposals
        .where((p) => p.isCancelled)
        .map((p) => p.toBookingItem())
        .where((p) {
          final altRef = p.bookingReference.replaceFirst('PR-', 'TB-');
          return !existingPastBookingRefs.contains(p.bookingReference) &&
              !existingPastBookingRefs.contains(altRef);
        })
        .toList();

    final pastList = [...completedOrCancelledBookings, ...cancelledProposals]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROVIDER MODE',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your Jobs & Bookings',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: palette.text,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: palette.primary),
                    onPressed: _loadBookings,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              DefaultTabController(
                length: 4,
                child: Expanded(
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                          border: Border.all(color: palette.border),
                        ),
                        child: TabBar(
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(AppRadius.r8),
                          ),
                          indicatorColor: Colors.transparent,
                          labelColor: palette.primary,
                          unselectedLabelColor: palette.muted,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 2,
                          ),
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: [
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Requests (${requestsList.length})'),
                                    if (requestsList.isNotEmpty) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.amber,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Upcoming (${upcomingList.length})',
                                ),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Active (${activeList.length})'),
                              ),
                            ),
                            Tab(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Past (${pastList.length})'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isLoading
                            ? Center(
                                child: CircularProgressIndicator(
                                  color: palette.primary,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : TabBarView(
                                children: [
                                  _buildBookingsList(
                                    requestsList,
                                    BookingStatus.requested,
                                    palette,
                                  ),
                                  _buildBookingsList(
                                    upcomingList,
                                    BookingStatus.upcoming,
                                    palette,
                                  ),
                                  _buildBookingsList(
                                    activeList,
                                    BookingStatus.active,
                                    palette,
                                  ),
                                  _buildBookingsList(
                                    pastList,
                                    BookingStatus.completed,
                                    palette,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList(
    List<BookingItem> list,
    BookingStatus defaultStatus,
    AppPalette palette,
  ) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadBookings,
        color: palette.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 350,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 48,
                  color: palette.muted.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  defaultStatus == BookingStatus.requested
                      ? 'No new proposals received'
                      : 'No ${defaultStatus.label.toLowerCase()} bookings found',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  defaultStatus == BookingStatus.requested
                      ? 'When customers send job proposals, they will appear here.'
                      : 'When jobs are booked, they will show up here.',
                  style: TextStyle(
                    color: palette.muted.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: palette.primary,
      child: ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final b = list[index];
          final parsedStatus = BookingStatus.fromString(b.status);

          String? customLabel;
          Color? tagTextCol;
          Color? tagBgCol;

          if (b.isCancelled) {
            customLabel = b.status.toLowerCase() == 'declined'
                ? 'Declined'
                : 'Cancelled';
            tagTextCol = Colors.red.shade900;
            tagBgCol = Colors.red.shade100;
          } else if (b.isDisputed) {
            customLabel = 'Under Dispute (Admin Review)';
            tagTextCol = Colors.red.shade900;
            tagBgCol = Colors.red.shade100;
          } else if (b.isPendingSignOff) {
            customLabel = 'Awaiting Customer Sign-Off';
            tagTextCol = Colors.purple.shade900;
            tagBgCol = Colors.purple.shade100;
          } else if (b.isRevisionRequested) {
            customLabel = 'Revision Requested';
            tagTextCol = Colors.orange.shade900;
            tagBgCol = Colors.orange.shade100;
          } else if (b.isCustomerCountered) {
            customLabel = 'Re-Bid Received';
            tagTextCol = Colors.teal.shade900;
            tagBgCol = Colors.teal.shade100;
          } else if (b.isProviderCountered) {
            customLabel = 'Quotation Sent';
            tagTextCol = Colors.indigo.shade900;
            tagBgCol = Colors.indigo.shade100;
          } else if (parsedStatus == BookingStatus.requested) {
            customLabel = 'New Proposal';
            tagTextCol = Colors.amber.shade900;
            tagBgCol = Colors.amber.shade100;
          }

          return BookingCardWidget(
            title: b.serviceTitle,
            providerName: b.customerName,
            reference: b.bookingReference,
            schedule: b.schedule,
            price: b.isHourly
                ? 'Rate: Rs. ${b.price.toInt()}/hr'
                : 'Fixed: Rs. ${b.price.toInt()}',
            status: parsedStatus,
            customStatusLabel: customLabel,
            customTagTextColor: tagTextCol,
            customTagBgColor: tagBgCol,
            onTap: () async {
              if (parsedStatus == BookingStatus.requested && !b.isCancelled) {
                _showProposalReviewModal(b);
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProviderJobDetailsPage(booking: b),
                  ),
                );
                _loadBookings();
              }
            },
          );
        },
      ),
    );
  }
}
