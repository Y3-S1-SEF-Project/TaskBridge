import 'package:flutter/material.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class ProviderJobsPage extends StatelessWidget {
  const ProviderJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

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
                          tabs: const [
                            Tab(text: 'Active (2)'),
                            Tab(text: 'Scheduled (3)'),
                            Tab(text: 'Past (14)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: TabBarView(
                          children: [
                            ListView(
                              children: const [
                                _JobItem(
                                  title: 'Kitchen Sink Leak Repair',
                                  customer: 'Anura Wickramasinghe',
                                  location: 'Colombo 07',
                                  status: 'In Progress',
                                  price: 'Rs. 3,500',
                                ),
                                SizedBox(height: 12),
                                _JobItem(
                                  title: 'Bathroom Shower Pipe Fixed',
                                  customer: 'Dilani Perera',
                                  location: 'Rajagiriya',
                                  status: 'En Route',
                                  price: 'Rs. 4,200',
                                ),
                              ],
                            ),
                            ListView(
                              children: const [
                                _JobItem(
                                  title: 'Water Filter Cartridge Swap',
                                  customer: 'Chathura Fernando',
                                  location: 'Nawala',
                                  status: 'Tomorrow, 9:00 AM',
                                  price: 'Rs. 2,800',
                                ),
                              ],
                            ),
                            ListView(
                              children: const [
                                _JobItem(
                                  title: 'Full Plumbing Inspection',
                                  customer: 'Kasun Jayawardena',
                                  location: 'Battaramulla',
                                  status: 'Completed',
                                  price: 'Rs. 8,500',
                                ),
                              ],
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
}

class _JobItem extends StatelessWidget {
  final String title;
  final String customer;
  final String location;
  final String status;
  final String price;

  const _JobItem({
    required this.title,
    required this.customer,
    required this.location,
    required this.status,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: palette.text,
                  ),
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$customer · $location',
            style: TextStyle(fontSize: 13, color: palette.muted),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: palette.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
