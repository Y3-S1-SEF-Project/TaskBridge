import 'package:flutter/material.dart';
import '../../ai/models/coordination_models.dart';
import '../../ai/services/coordination_api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../home/widgets/booking_card_widget.dart';

class ProviderJobsPage extends StatefulWidget {
  const ProviderJobsPage({super.key});

  @override
  State<ProviderJobsPage> createState() => _ProviderJobsPageState();
}

class _ProviderJobsPageState extends State<ProviderJobsPage> {
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

  Future<void> _updateStatus(BookingItem booking, String newStatus) async {
    final success = await CoordinationApi.updateBookingStatus(
      bookingReference: booking.bookingReference,
      newStatus: newStatus,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking #${booking.bookingReference} marked as $newStatus.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _loadBookings();
    }
  }

  void _showJobActionsModal(BookingItem booking) {
    final palette = AppPalette.of(context);
    final status = BookingStatus.fromString(booking.status);

    showModalBottomSheet(
      context: context,
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
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                  style: TextStyle(fontSize: 14, color: palette.text, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Earnings: Rs. ${booking.price.toInt()}',
                  style: TextStyle(fontSize: 16, color: palette.primary, fontWeight: FontWeight.w800),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(booking, 'Active');
                      },
                      child: const Text('Start Job (Set Active)', style: TextStyle(fontWeight: FontWeight.w700)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _updateStatus(booking, 'Completed');
                      },
                      child: const Text('Mark as Completed', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

    final activeList = _bookings
        .where((b) => b.status.toLowerCase() == 'active' || b.status.toLowerCase() == 'in progress')
        .toList();
    final upcomingList = _bookings
        .where((b) => b.status.toLowerCase() == 'upcoming')
        .toList();
    final pastList = _bookings
        .where((b) => b.status.toLowerCase() == 'completed' || b.status.toLowerCase() == 'cancelled')
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
                length: 3,
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
                          tabs: [
                            Tab(text: 'Upcoming (${upcomingList.length})'),
                            Tab(text: 'Active (${activeList.length})'),
                            Tab(text: 'Past (${pastList.length})'),
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
                                  _buildBookingsList(upcomingList, BookingStatus.upcoming, palette),
                                  _buildBookingsList(activeList, BookingStatus.active, palette),
                                  _buildBookingsList(pastList, BookingStatus.completed, palette),
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

  Widget _buildBookingsList(List<BookingItem> list, BookingStatus defaultStatus, AppPalette palette) {
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
                  'No ${defaultStatus.label.toLowerCase()} bookings found',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'When jobs are booked, they will show up here.',
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
            price: 'Rs. ${b.price.toInt()}',
            status: parsedStatus,
            onTap: () => _showJobActionsModal(b),
          );
        },
      ),
    );
  }
}
