import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
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

class _CustomerBookingsPageState extends State<CustomerBookingsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<BookingItem> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadBookings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final custName = widget.user?.fullName;
      final bookingsFuture = CoordinationApi.getBookings(
        customerName: custName,
      );
      final proposalsFuture = CoordinationApi.getProposals(
        customerName: custName,
      );

      final results = await Future.wait([bookingsFuture, proposalsFuture]);
      final list = results[0] as List<BookingItem>;
      final propList = results[1] as List<ProposalItem>;

      if (mounted) {
        final custLower = custName?.trim().toLowerCase();

        final filteredBookings = list.where((b) {
          if (custLower == null) return true;
          final bCust = b.customerName.trim().toLowerCase();
          return bCust.contains(custLower) ||
              custLower.contains(bCust) ||
              bCust == 'customer';
        }).toList();

        final filteredProposals = propList
            .where((p) {
              if (custLower == null) return true;
              final pCust = p.customerName.trim().toLowerCase();
              return pCust.contains(custLower) ||
                  custLower.contains(pCust) ||
                  pCust == 'customer';
            })
            .map((p) => p.toBookingItem())
            .toList();

        final combinedMap = <String, BookingItem>{};

        for (final p in filteredProposals) {
          combinedMap[p.bookingReference] = p;
        }

        for (final b in filteredBookings) {
          final isPr = b.bookingReference.startsWith('PR-');
          if (isPr && combinedMap.containsKey(b.bookingReference)) {
            final prop = combinedMap[b.bookingReference]!;
            if (prop.isCancelled) {
              combinedMap[b.bookingReference] = b.copyWith(status: prop.status);
            } else {
              combinedMap[b.bookingReference] = b;
            }
          } else {
            final altPr = b.bookingReference.startsWith('TB-')
                ? b.bookingReference.replaceFirst('TB-', 'PR-')
                : null;
            if (altPr != null && combinedMap.containsKey(altPr)) {
              final prop = combinedMap[altPr]!;
              combinedMap.remove(altPr);
              if (b.isCancelled || prop.isCancelled) {
                combinedMap[b.bookingReference] = b.copyWith(
                  status: 'Cancelled',
                );
              } else {
                combinedMap[b.bookingReference] = b;
              }
            } else {
              combinedMap[b.bookingReference] = b;
            }
          }
        }

        final combined = combinedMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        setState(() {
          _bookings = combined;
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Yes, Cancel',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
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
            content: Text(
              'Request #${booking.bookingReference} has been cancelled.',
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
  }

  void _showCustomerProposalReviewModal(BookingItem booking) {
    final palette = AppPalette.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: AppSpacing.s20,
              right: AppSpacing.s20,
              top: AppSpacing.s8,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.s24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag & Reference
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: booking.isProviderCountered
                            ? Colors.green.shade100
                            : (booking.isCustomerCountered
                                  ? Colors.orange.shade100
                                  : Colors.amber.shade100),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        booking.isProviderCountered
                            ? 'PROVIDER REVISED QUOTE'
                            : (booking.isCustomerCountered
                                  ? 'YOUR RE-BID SENT'
                                  : 'QUOTATION REQUESTED'),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: booking.isProviderCountered
                              ? Colors.green.shade900
                              : (booking.isCustomerCountered
                                    ? Colors.orange.shade900
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
                  'Provider: ${booking.providerName} · Location: ${booking.location}',
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
                const SizedBox(height: 14),

                // Status Banner
                if (booking.isProviderCountered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: palette.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.local_offer_rounded,
                          size: 20,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Provider's Counter-Offer",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${booking.providerName} updated the quotation to ${booking.priceFormatted}. You can accept to complete the booking immediately or propose a counter-offer.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else if (booking.isCustomerCountered)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.schedule_send_rounded,
                          size: 20,
                          color: Colors.orange.shade800,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Re-Bid is Under Review',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'You proposed ${booking.priceFormatted} for ${booking.schedule}. Waiting for ${booking.providerName} to review.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade800,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: palette.soft,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.border, width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.hourglass_top_rounded,
                          size: 20,
                          color: palette.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Awaiting Provider Confirmation',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.text,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Proposal sent to ${booking.providerName}. They will review your requested time and confirm the quotation.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
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

                // Current Offer Breakdown Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Quotation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                booking.priceFormatted,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: palette.primary,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: palette.soft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              booking.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(height: 1, color: palette.border),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.schedule_rounded,
                              size: 16,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              booking.schedule,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: palette.text,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                              ),
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
                            child: Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Button 1: Accept & Complete Booking (Only if provider sent a revised quote)
                if (booking.isProviderCountered) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        final success = await CoordinationApi.acceptProposal(
                          proposalReference: booking.bookingReference,
                          schedule: booking.schedule,
                          price: booking.price,
                          rateType: booking.rateType,
                        );
                        if (success && mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '🎉 Booking confirmed with ${booking.providerName}! Scheduled in Upcoming.',
                              ),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                          await _loadBookings();
                          _tabController.animateTo(1);
                        }
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                      label: const Text(
                        'Accept & Complete Booking',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Button 2: Counter-Offer / Re-Bid
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.primary,
                      side: BorderSide(color: palette.primary, width: 1.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCustomerCounterBidModal(booking);
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 18),
                    label: Text(
                      booking.isCustomerCountered
                          ? 'Modify / Update Re-Bid'
                          : (booking.isProviderCountered
                                ? 'Counter-Offer / Re-Bid'
                                : 'Modify Terms / Re-Bid'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Button 3: Cancel Request
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _cancelBooking(booking);
                    },
                    child: Text(
                      'Cancel Request',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
  }

  void _showCustomerCounterBidModal(BookingItem booking) {
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
      text:
          'Customer proposed counter-offer with updated budget and preferred time.',
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
                          'Counter-Offer / Re-Bid',
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
                      'Job: ${booking.serviceTitle} · Provider: ${booking.providerName}',
                      style: TextStyle(fontSize: 13, color: palette.muted),
                    ),
                    const SizedBox(height: 14),

                    // Customer's Reference to Provider's Previous Offer
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
                                  "Provider's Current Offer:",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: palette.text,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${booking.priceFormatted} · ${booking.schedule}',
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

                    // Your Proposed Budget
                    Text(
                      rateType.toLowerCase() == 'hourly'
                          ? 'Your Proposed Hourly Rate (Rs./hr)'
                          : 'Your Proposed Total Budget (Rs.)',
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

                    // Preferred Attendance Time with time picker & chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Your Preferred Time',
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

                    // Message for Provider
                    Text(
                      'Message / Note for Provider',
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
                        hintText: 'Notes for the provider',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit Re-Bid
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
                                sender: 'customer',
                              );

                          if (success && mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Re-bid of Rs. ${price.toInt()} sent to ${booking.providerName}!',
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
                          'Submit Re-Bid to Provider',
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

  void _switchToProvider() {
    if (widget.user != null && widget.api != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProviderMainPage(user: widget.user!, api: widget.api!),
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

    return Scaffold(
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
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _switchToProvider,
                        borderRadius: BorderRadius.circular(AppRadius.r12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: palette.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadius.r12),
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.swap_horiz_rounded,
                                size: 18,
                                color: palette.primary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Provider',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: palette.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // ── 4 Filter Tabs: Ongoing, Upcoming, Completed, Cancelled ──
              Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  border: Border.all(color: palette.border),
                ),
                child: TabBar(
                  controller: _tabController,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                            palette.primary,
                          ),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          // 1. Ongoing (Requests & In Progress)
                          _BookingsListView(
                            bookings: ongoingList,
                            emptyMessage: 'No ongoing job requests right now.',
                            emptySub:
                                'Requests you initiate via TaskBridge AI will appear here.',
                            onRefresh: _loadBookings,
                            onAction: _showCustomerProposalReviewModal,
                            onCancel: _cancelBooking,
                            isOngoingTab: true,
                          ),
                          // 2. Upcoming (Confirmed locked bookings)
                          _BookingsListView(
                            bookings: upcomingList,
                            emptyMessage: 'No upcoming bookings at the moment.',
                            emptySub:
                                'Accepted quotations and confirmed bookings appear here.',
                            onRefresh: _loadBookings,
                            onAction: null,
                            onCancel: _cancelBooking,
                            isOngoingTab: false,
                          ),
                          // 3. Completed
                          _BookingsListView(
                            bookings: completedList,
                            emptyMessage: 'No completed bookings yet.',
                            emptySub:
                                'Past finished jobs and reviews will be stored here.',
                            onRefresh: _loadBookings,
                            onAction: null,
                            onCancel: null,
                            isOngoingTab: false,
                          ),
                          // 4. Cancelled
                          _BookingsListView(
                            bookings: cancelledList,
                            emptyMessage: 'No cancelled bookings.',
                            emptySub:
                                'Requests that were cancelled or declined appear here.',
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
                  style: TextStyle(fontSize: 12, color: palette.muted),
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

          if (b.isCancelled) {
            badgeColor = AppColors.error;
            badgeText = b.status.toLowerCase() == 'declined'
                ? 'Declined by Provider'
                : 'Cancelled';
          } else if (b.isProviderCountered) {
            badgeColor = Colors.green.shade700;
            badgeText = 'Counter-Bid Received';
          } else if (b.isCustomerCountered) {
            badgeColor = Colors.orange.shade800;
            badgeText = 'Re-Bid Sent';
          } else if (b.isRequested) {
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

          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.r16),
              onTap: onAction != null ? () => onAction!(b) : null,
              child: Container(
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r16),
                  border: Border.all(
                    color: b.isProviderCountered
                        ? palette.primary.withValues(alpha: 0.4)
                        : palette.border,
                    width: b.isProviderCountered ? 1.5 : 1.0,
                  ),
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
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 16,
                              color: palette.primary,
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
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
                          b.providerName.isNotEmpty
                              ? b.providerName
                              : 'Specialist',
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            AppIcons.clock,
                            size: 14,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.schedule,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
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
                          child: Icon(
                            AppIcons.location,
                            size: 14,
                            color: palette.muted,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            b.location,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.muted,
                              height: 1.3,
                            ),
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
                                  side: BorderSide(
                                    color: AppColors.error.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => onCancel!(b),
                                child: const Text(
                                  'Cancel Request',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (onCancel != null && onAction != null)
                            const SizedBox(width: 10),
                          if (onAction != null)
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: palette.primary,
                                  foregroundColor: palette.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                                onPressed: () => onAction!(b),
                                child: Text(
                                  b.isProviderCountered
                                      ? 'Review & Book'
                                      : (b.isCustomerCountered
                                            ? 'View Re-Bid'
                                            : 'View Proposal'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
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
                            side: BorderSide(
                              color: AppColors.error.withValues(alpha: 0.5),
                            ),
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
              ),
            ),
          );
        },
      ),
    );
  }
}
