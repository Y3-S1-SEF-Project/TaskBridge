import 'package:flutter/material.dart';
import '../../auth/data/auth_models.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';

class ProviderDashboardPage extends StatelessWidget {
  final AuthUser user;
  final VoidCallback onSwitchToCustomer;

  const ProviderDashboardPage({
    super.key,
    required this.user,
    required this.onSwitchToCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
                      const Text(
                        'PROVIDER DASHBOARD',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Welcome back,\n${user.fullName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: onSwitchToCustomer,
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: const Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── Quick Metrics Row ──
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'This Month',
                      value: 'Rs. ${(user.providerEarnings ?? 54000).toStringAsFixed(0)}',
                      icon: Icons.trending_up_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _MetricCard(
                      label: 'Active Jobs',
                      value: '3 Pending',
                      icon: Icons.business_center_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: _MetricCard(
                      label: 'Rating',
                      value: '4.9 ★',
                      icon: Icons.star_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Incoming Requests Section ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Incoming Requests',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '3 New',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _JobCard(
                title: 'Bathroom Pipe Leak Repair',
                location: 'Colombo 05 · 1.8 km away',
                price: 'Rs. 4,500',
                time: 'Today, 2:30 PM',
              ),
              const SizedBox(height: 12),
              _JobCard(
                title: 'Kitchen Sink Tap Replacement',
                location: 'Nugegoda · 3.2 km away',
                price: 'Rs. 3,000',
                time: 'Tomorrow, 10:00 AM',
              ),
              const SizedBox(height: 12),
              _JobCard(
                title: 'Main Valve Inspection & Filter',
                location: 'Rajagiriya · 4.5 km away',
                price: 'Rs. 6,000',
                time: 'Mon, 9:00 AM',
              ),
            ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final String title;
  final String location;
  final String price;
  final String time;

  const _JobCard({
    required this.title,
    required this.location,
    required this.price,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                price,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(location, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(time, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {},
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {},
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
