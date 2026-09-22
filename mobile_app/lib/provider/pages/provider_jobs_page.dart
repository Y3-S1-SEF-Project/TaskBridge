import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/widgets/booking_card_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
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
        status: 'Pending',
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

        setState(() {
          _bookings = filteredBookings;
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

  Future<void> _updateStatus(
    BookingItem booking,
    String newStatus, {
    String? schedule,
    double? price,
  }) async {
    final success = await CoordinationApi.updateBookingStatus(
      bookingReference: booking.bookingReference,
      newStatus: newStatus,
      schedule: schedule,
      price: price,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'Upcoming'
                ? 'Proposal accepted! Booking locked into Upcoming schedule.'
                : 'Booking #${booking.bookingReference} updated to $newStatus.',
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

  void _showProposalReviewModal(BookingItem booking) {
    final palette = AppPalette.of(context);
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
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'NEW PROPOSAL',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.amber.shade900,
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

                      // Field 2: Confirmed Price / Quote
                      Text(
                        'Quoted Price / Final Amount (Rs.)',
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
                                );

                            if (success && mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Proposal accepted! Booking locked into Upcoming schedule for $confSchedule.',
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
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Accept & Confirm Schedule',
                                style: TextStyle(
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

  void _showJobActionsModal(BookingItem booking) {
    final palette = AppPalette.of(context);
    final status = BookingStatus.fromString(booking.status);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.serviceTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customer: ${booking.customerName} · #${booking.bookingReference}',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Schedule: ${booking.schedule}',
                  style: TextStyle(
                    fontSize: 14,
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earnings: Rs. ${booking.price.toInt()}',
                  style: TextStyle(
                    fontSize: 16,
                    color: palette.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 20),

                // Action buttons based on current status
                if (status == BookingStatus.upcoming) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(booking, 'Active');
                      },
                      child: const Text(
                        'Start Job (Set Active)',
                        style: TextStyle(fontWeight: FontWeight.w700),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(booking, 'Cancelled');
                      },
                      child: const Text('Cancel Job'),
                    ),
                  ),
                ] else if (status == BookingStatus.active) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(booking, 'Completed');
                      },
                      child: const Text(
                        'Mark as Completed',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final requestsList = _proposals.map((p) => p.toBookingItem()).toList();
    final upcomingList = _bookings.where((b) => b.isUpcoming).toList();
    final activeList = _bookings.where((b) => b.isActive).toList();
    final pastList = _bookings
        .where((b) => b.isCompleted || b.isCancelled)
        .toList();

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
                          indicatorColor: palette.primary,
                          labelColor: palette.primary,
                          unselectedLabelColor: palette.muted,
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
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

          return BookingCardWidget(
            title: b.serviceTitle,
            providerName: b.customerName,
            reference: b.bookingReference,
            schedule: b.schedule,
            price: parsedStatus == BookingStatus.requested
                ? 'Rate: Rs. ${b.price.toInt()}/hr'
                : 'Rs. ${b.price.toInt()}',
            status: parsedStatus,
            onTap: () {
              if (parsedStatus == BookingStatus.requested) {
                _showProposalReviewModal(b);
              } else {
                _showJobActionsModal(b);
              }
            },
          );
        },
      ),
    );
  }
}
