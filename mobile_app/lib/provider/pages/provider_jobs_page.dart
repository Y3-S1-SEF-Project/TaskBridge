import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class ProviderJobsPage extends StatelessWidget {
  const ProviderJobsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PROVIDER MODE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your Jobs & Bookings',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
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
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.r12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const TabBar(
                          indicatorColor: AppColors.primary,
                          labelColor: AppColors.primary,
                          unselectedLabelColor: AppColors.textSecondary,
                          tabs: [
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
                                  title: 'Kitchen Sink Tap Replacement',
                                  customer: 'Saman Jayasinghe',
                                  location: 'Colombo 05',
                                  status: 'In Progress',
                                  price: 'Rs. 3,500',
                                ),
                                SizedBox(height: 12),
                                _JobItem(
                                  title: 'Overhead Tank Float Valve Repair',
                                  customer: 'Nilmini Perera',
                                  location: 'Nugegoda',
                                  status: 'On the way',
                                  price: 'Rs. 4,800',
                                ),
                              ],
                            ),
                            ListView(
                              children: const [
                                _JobItem(
                                  title: 'Bathroom Pipeline Diagnostic',
                                  customer: 'Rohan Silva',
                                  location: 'Battaramulla',
                                  status: 'Tomorrow 9:00 AM',
                                  price: 'Rs. 5,000',
                                ),
                              ],
                            ),
                            ListView(
                              children: const [
                                _JobItem(
                                  title: 'Shower Mixer Replacement',
                                  customer: 'Anura Wickrama',
                                  location: 'Colombo 07',
                                  status: 'Completed',
                                  price: 'Rs. 4,200',
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$customer · $location',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
