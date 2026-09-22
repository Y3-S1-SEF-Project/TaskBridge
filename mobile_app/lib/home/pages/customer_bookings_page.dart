import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/models/planning_models.dart';
import '../../ai/pages/quotation_proposal_page.dart';
import '../../ai/services/coordination_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../provider/pages/provider_main_page.dart';

class CustomerBookingsPage extends StatefulWidget {
  final ValueChanged<int>? onSwitchTab;
  final AuthUser? user;
  final AuthApi? api;

  const CustomerBookingsPage({
    super.key,
    this.onSwitchTab,
    this.user,
    this.api,
  });

  @override
  State<CustomerBookingsPage> createState() => _CustomerBookingsPageState();
}

class _CustomerBookingsPageState extends State<CustomerBookingsPage> {
  List<BookingItem> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final list = await CoordinationApi.getBookings(
        customerName: widget.user?.fullName,
      );
      if (mounted) {
        final custName = widget.user?.fullName.trim().toLowerCase();

        final filtered = list.where((b) {
          if (custName == null) return true;
          final bCust = b.customerName.trim().toLowerCase();
          return bCust == custName || bCust == 'customer';
        }).toList();

        setState(() {
          _bookings = filtered;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _cancelBooking(BookingItem booking) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final palette = AppPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Cancel Request?',
            style: TextStyle(fontWeight: FontWeight.w800, color: palette.text),
          ),
          content: Text(
            'Are you sure you want to cancel booking #${booking.bookingReference} for ${booking.serviceTitle}?',
            style: TextStyle(color: palette.muted, fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Keep It', style: TextStyle(color: palette.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final success = await CoordinationApi.cancelBooking(
        bookingReference: booking.bookingReference,
        reason: 'Cancelled by customer',
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request #${booking.bookingReference} has been cancelled.'),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        _loadBookings();
      }
    }
  }

  void _openProposalForBooking(BookingItem b) {
    final proposal = BookingProposalResponse(
      success: true,
      recommendedProviderId: b.providerName,
      recommendedProviderName: b.providerName,
      recommendationReason:
          '${b.providerName} submitted a quotation of ${b.priceFormatted} for ${b.serviceTitle} matching your requested schedule.',
      winningQuotation: ProviderQuotation(
        providerId: b.providerName,
        fullName: b.providerName,
        category: b.category,
        phone: '0771234567',
        quotedPrice: b.price,
        availableTime: b.schedule,
        distanceKm: 2.4,
        rating: 4.8,
        reviewCount: 12,
        notes: 'Includes full service, professional equipment, and cleanup.',
        matchScore: 95,
        isRecommended: true,
      ),
      allQuotations: [
        ProviderQuotation(
          providerId: b.providerName,
          fullName: b.providerName,
          category: b.category,
          phone: '0771234567',
          quotedPrice: b.price,
          availableTime: b.schedule,
          distanceKm: 2.4,
          rating: 4.8,
          reviewCount: 12,
          notes: 'Includes full service, professional equipment, and cleanup.',
          matchScore: 95,
          isRecommended: true,
        ),
      ],
      bookingProposal: BookingDetails(
        bookingReference: b.bookingReference,
        serviceTitle: b.serviceTitle,
        providerName: b.providerName,
        customerName: b.customerName,
        location: b.location,
        schedule: b.schedule,
        price: b.price,
        priceFormatted: b.priceFormatted,
        status: b.status,
      ),
      model: 'TaskBridge-Agent-3',
      latencyMs: 10,
    );

    final jobPlan = JobPlan(
      serviceTitle: b.serviceTitle,
      category: b.category,
      description: 'Customer requested quotation for ${b.serviceTitle}',
      location: b.location,
      scheduledDate: b.schedule,
      scheduledTime: b.schedule,
      budget: b.price,
      budgetDisplay: b.priceFormatted,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuotationProposalPage(
          jobPlan: jobPlan,
          proposalResponse: proposal,
        ),
      ),
    ).then((_) => _loadBookings());
  }

  void _switchToProvider() {
    if (widget.user != null && widget.api != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderMainPage(
            user: widget.user!,
            api: widget.api!,
          ),
        ),
      ).then((_) => _loadBookings());
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final ongoingList = _bookings.where((b) => b.isOngoing).toList();
    final upcomingList = _bookings.where((b) => b.isUpcoming).toList();
    final completedList = _bookings.where((b) => b.isCompleted).toList();
    final cancelledList = _bookings.where((b) => b.isCancelled).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.s20,
              right: AppSpacing.s20,
              top: AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Top Header with Quick Role Switcher ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR RESERVATIONS',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'My Bookings',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: palette.text,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    if (widget.user != null)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: palette.primary,
                          side: BorderSide(color: palette.primary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        onPressed: _switchToProvider,
                        icon: const Icon(AppIcons.switchMode, size: 16),
                        label: const Text(
                          'Provider',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── 4 Tabs Header ──
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(3),
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
                    labelPadding: const EdgeInsets.symmetric(horizontal: 2),
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
                          child: Text('Ongoing (${ongoingList.length})'),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Upcoming (${upcomingList.length})'),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Completed (${completedList.length})'),
                        ),
                      ),
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Cancelled (${cancelledList.length})'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tab Views ──
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(palette.primary),
                          ),
                        )
                      : TabBarView(
                          children: [
                            // 1. Ongoing (Requests & In Progress)
                            _BookingsListView(
                              bookings: ongoingList,
                              emptyMessage: 'No ongoing job requests right now.',
                              emptySub: 'Requests you initiate via TaskBridge AI will appear here.',
                              onRefresh: _loadBookings,
                              onAction: _openProposalForBooking,
                              onCancel: _cancelBooking,
                              isOngoingTab: true,
                            ),
                            // 2. Upcoming (Confirmed locked bookings)
                            _BookingsListView(
                              bookings: upcomingList,
                              emptyMessage: 'No upcoming bookings at the moment.',
                              emptySub: 'Accepted quotations and confirmed bookings appear here.',
                              onRefresh: _loadBookings,
                              onAction: null,
                              onCancel: _cancelBooking,
                              isOngoingTab: false,
                            ),
                            // 3. Completed
                            _BookingsListView(
                              bookings: completedList,
                              emptyMessage: 'No completed bookings yet.',
                              emptySub: 'Past finished jobs and reviews will be stored here.',
                              onRefresh: _loadBookings,
                              onAction: null,
                              onCancel: null,
                              isOngoingTab: false,
                            ),
                            // 4. Cancelled
                            _BookingsListView(
                              bookings: cancelledList,
                              emptyMessage: 'No cancelled bookings.',
                              emptySub: 'Requests that were cancelled or declined appear here.',
                              onRefresh: _loadBookings,
                              onAction: null,
                              onCancel: null,
                              isOngoingTab: false,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingsListView extends StatelessWidget {
  final List<BookingItem> bookings;
  final String emptyMessage;
  final String emptySub;
  final Future<void> Function() onRefresh;
  final void Function(BookingItem)? onAction;
  final void Function(BookingItem)? onCancel;
  final bool isOngoingTab;

  const _BookingsListView({
    required this.bookings,
    required this.emptyMessage,
    required this.emptySub,
    required this.onRefresh,
    this.onAction,
    this.onCancel,
    required this.isOngoingTab,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    if (bookings.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: palette.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: 380,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    AppIcons.calendar,
                    color: palette.primary,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  emptyMessage,
                  style: TextStyle(
                    fontSize: 15,
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  emptySub,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.primary,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: bookings.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final b = bookings[index];

          Color badgeColor;
          String badgeText;

          if (b.isRequested) {
            badgeColor = Colors.amber.shade800;
            badgeText = 'Quotation Requested';
          } else if (b.isActive) {
            badgeColor = palette.primary;
            badgeText = 'In Progress';
          } else if (b.isUpcoming) {
            badgeColor = Colors.teal;
            badgeText = 'Upcoming (Confirmed)';
          } else if (b.isCompleted) {
            badgeColor = Colors.blue.shade700;
            badgeText = 'Completed';
          } else {
            badgeColor = AppColors.error;
            badgeText = 'Cancelled';
          }

          return Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.r16),
              border: Border.all(color: palette.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Row: Reference & Status Badge ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 16, color: palette.primary),
                        const SizedBox(width: 6),
                        Text(
                          '#${b.bookingReference}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: palette.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Service Title ──
                Text(
                  b.serviceTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Specialist & Price Row ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: palette.soft,
                      child: Text(
                        b.providerName.isNotEmpty
                            ? b.providerName.substring(0, 1).toUpperCase()
                            : 'P',
                        style: TextStyle(
                          fontSize: 11,
                          color: palette.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      b.providerName.isNotEmpty ? b.providerName : 'Specialist',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      b.priceFormatted,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: palette.border),
                const SizedBox(height: 8),

                // ── Schedule & Location ──
                Row(
                  children: [
                    Icon(AppIcons.clock, size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.schedule,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(AppIcons.location, size: 14, color: palette.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        b.location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: palette.muted),
                      ),
                    ),
                  ],
                ),

                // ── Action Buttons for Ongoing / Cancellable Items ──
                if (b.isRequested) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (onCancel != null)
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => onCancel!(b),
                            child: const Text(
                              'Cancel Request',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (onCancel != null && onAction != null) const SizedBox(width: 10),
                      if (onAction != null)
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.primary,
                              foregroundColor: palette.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => onAction!(b),
                            child: const Text(
                              'View Proposal',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else if (b.isUpcoming && onCancel != null) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => onCancel!(b),
                      child: const Text('Cancel Booking'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
