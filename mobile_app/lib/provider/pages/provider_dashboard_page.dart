import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    try {
      final list = await CoordinationApi.getBookings();
      if (mounted) {
        setState(() {
          _bookings = list;
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
    final success = await CoordinationApi.updateBookingStatus(
      bookingReference: booking.bookingReference,
      newStatus: 'Active',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Job #${booking.bookingReference} accepted and moved to Active Jobs!',
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
    final success = await CoordinationApi.updateBookingStatus(
      bookingReference: booking.bookingReference,
      newStatus: 'Cancelled',
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Job #${booking.bookingReference} has been declined.'),
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

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    final incomingRequests = _bookings
        .where((b) => b.status.toLowerCase() == 'upcoming')
        .toList();
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
        : (incomingRequests.isNotEmpty
              ? '${incomingRequests.length} Pending'
              : '0 Active');

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
                    const Expanded(
                      child: _MetricCard(
                        label: 'Rating',
                        value: '4.9 ★',
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
                          'No pending job requests right now. New customer bookings confirmed through Agent 3 will appear here in real time.',
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
                      ),
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

  const _LiveJobCard({
    required this.booking,
    required this.onAccept,
    required this.onDecline,
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
            children: [
              Icon(AppIcons.location, size: 14, color: palette.muted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  booking.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: palette.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(AppIcons.clock, size: 14, color: palette.muted),
              const SizedBox(width: 4),
              Text(
                booking.schedule,
                style: TextStyle(fontSize: 13, color: palette.muted),
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
                  child: const Text('Accept Job'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
