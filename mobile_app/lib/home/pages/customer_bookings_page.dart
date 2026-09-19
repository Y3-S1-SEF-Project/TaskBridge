import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class CustomerBookingItem {
  final String id;
  final String serviceTitle;
  final String category;
  final IconData categoryIcon;
  final String providerName;
  final double providerRating;
  final String scheduledDate;
  final String scheduledTime;
  final String address;
  final String price;
  final String status; // Confirmed, In Progress, Completed, Cancelled
  final Color statusColor;

  const CustomerBookingItem({
    required this.id,
    required this.serviceTitle,
    required this.category,
    required this.categoryIcon,
    required this.providerName,
    required this.providerRating,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.address,
    required this.price,
    required this.status,
    required this.statusColor,
  });
}

class CustomerBookingsPage extends StatelessWidget {
  final ValueChanged<int>? onSwitchTab;

  const CustomerBookingsPage({super.key, this.onSwitchTab});

  static const List<CustomerBookingItem> _upcomingBookings = [
    CustomerBookingItem(
      id: 'TB-9021',
      serviceTitle: 'Plumbing & Water Pipe Leak Repair',
      category: 'Plumbing',
      categoryIcon: AppIcons.plumbing,
      providerName: 'Kasun Perera',
      providerRating: 4.9,
      scheduledDate: 'Tomorrow, Sep 20',
      scheduledTime: '10:00 AM – 11:30 AM',
      address: '114 Norris Canal Rd, Colombo 10',
      price: 'LKR 3,500',
      status: 'Confirmed',
      statusColor: AppColors.primary,
    ),
    CustomerBookingItem(
      id: 'TB-8842',
      serviceTitle: 'Split AC Deep Cleaning & Servicing',
      category: 'HVAC',
      categoryIcon: AppIcons.hvac,
      providerName: 'Dinesh Wickramasinghe',
      providerRating: 4.8,
      scheduledDate: 'Tue, Sep 23',
      scheduledTime: '02:00 PM – 03:30 PM',
      address: '45 Galle Road, Bambalapitiya',
      price: 'LKR 4,800',
      status: 'In Progress',
      statusColor: AppColors.info,
    ),
  ];

  static const List<CustomerBookingItem> _completedBookings = [
    CustomerBookingItem(
      id: 'TB-7420',
      serviceTitle: 'Home Wi-Fi & Mesh Network Setup',
      category: 'IT Services',
      categoryIcon: AppIcons.itServices,
      providerName: 'Nuwan Alwis',
      providerRating: 5.0,
      scheduledDate: 'Sep 12, 2026',
      scheduledTime: '11:00 AM',
      address: '114 Norris Canal Rd, Colombo 10',
      price: 'LKR 2,500',
      status: 'Completed',
      statusColor: AppColors.success,
    ),
    CustomerBookingItem(
      id: 'TB-6102',
      serviceTitle: 'Smart Doorbell & Camera Installation',
      category: 'Appliances',
      categoryIcon: AppIcons.appliances,
      providerName: 'Suresh Fernando',
      providerRating: 4.7,
      scheduledDate: 'Aug 29, 2026',
      scheduledTime: '03:00 PM',
      address: '114 Norris Canal Rd, Colombo 10',
      price: 'LKR 5,200',
      status: 'Completed',
      statusColor: AppColors.success,
    ),
  ];

  static const List<CustomerBookingItem> _cancelledBookings = [
    CustomerBookingItem(
      id: 'TB-5301',
      serviceTitle: 'Electrical Circuit Breaker Check',
      category: 'Electrical',
      categoryIcon: AppIcons.electrical,
      providerName: 'Rohan Silva',
      providerRating: 4.6,
      scheduledDate: 'Aug 14, 2026',
      scheduledTime: '09:30 AM',
      address: '114 Norris Canal Rd, Colombo 10',
      price: 'LKR 2,000',
      status: 'Cancelled',
      statusColor: AppColors.error,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return DefaultTabController(
      length: 3,
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
                // ── Top Header Tag ──
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

                // ── Title ──
                Text(
                  'My Bookings',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: palette.text,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tabs Header ──
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
                      borderRadius: BorderRadius.circular(AppRadius.r12 - 1),
                    ),
                    indicatorColor: Colors.transparent,
                    labelColor: palette.primary,
                    unselectedLabelColor: palette.muted,
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Upcoming (2)'),
                      Tab(text: 'Completed (2)'),
                      Tab(text: 'Cancelled (1)'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Tab Views ──
                Expanded(
                  child: TabBarView(
                    children: [
                      _BookingsList(
                        bookings: _upcomingBookings,
                        emptyMessage: 'No upcoming bookings at the moment.',
                        onExplore: () => onSwitchTab?.call(0),
                        onOpenChat: () => onSwitchTab?.call(2),
                        isUpcoming: true,
                      ),
                      _BookingsList(
                        bookings: _completedBookings,
                        emptyMessage: 'No past bookings yet.',
                        onExplore: () => onSwitchTab?.call(0),
                        onOpenChat: () => onSwitchTab?.call(2),
                        isUpcoming: false,
                      ),
                      _BookingsList(
                        bookings: _cancelledBookings,
                        emptyMessage: 'No cancelled bookings.',
                        onExplore: () => onSwitchTab?.call(0),
                        onOpenChat: () => onSwitchTab?.call(2),
                        isUpcoming: false,
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

class _BookingsList extends StatelessWidget {
  final List<CustomerBookingItem> bookings;
  final String emptyMessage;
  final VoidCallback onExplore;
  final VoidCallback onOpenChat;
  final bool isUpcoming;

  const _BookingsList({
    required this.bookings,
    required this.emptyMessage,
    required this.onExplore,
    required this.onOpenChat,
    required this.isUpcoming,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                AppIcons.calendar,
                color: AppColors.primary,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onExplore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
              ),
              child: const Text('Book a Service'),
            ),
          ],
        ),
      );
    }

    final palette = AppPalette.of(context);

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: bookings.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final b = bookings[index];
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
              // ── Top Row: Category Icon & Status Badge ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: palette.soft,
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                        child: Icon(
                          b.categoryIcon,
                          color: palette.primary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        b.category,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
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
                      color: b.statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.r12),
                    ),
                    child: Text(
                      b.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: b.statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

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

              // ── Provider Info ──
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: palette.soft,
                    child: Text(
                      b.providerName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    b.providerName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(AppIcons.star, size: 15, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    b.providerRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: palette.muted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    b.price,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: palette.border),
              const SizedBox(height: 10),

              // ── Date & Time Info ──
              Row(
                children: [
                  Icon(
                    AppIcons.clock,
                    size: 15,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${b.scheduledDate} · ${b.scheduledTime}',
                    style: TextStyle(
                      fontSize: 12,
                      color: palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // ── Address ──
              Row(
                children: [
                  Icon(
                    AppIcons.location,
                    size: 15,
                    color: palette.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      b.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Action Buttons ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onOpenChat,
                      icon: const Icon(AppIcons.message, size: 15),
                      label: const Text('Chat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.primary,
                        side: BorderSide(color: palette.primary),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isUpcoming
                                  ? 'Booking ${b.id} details opened.'
                                  : 'Rebooking service ${b.serviceTitle}...',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isUpcoming ? palette.primary : palette.surface,
                        foregroundColor:
                            isUpcoming ? palette.onPrimary : palette.text,
                        elevation: isUpcoming ? 1 : 0,
                        side: isUpcoming
                            ? null
                            : BorderSide(color: palette.border),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.r8),
                        ),
                      ),
                      child: Text(
                        isUpcoming ? 'View Details' : 'Book Again',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
