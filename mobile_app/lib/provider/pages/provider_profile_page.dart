import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/pages/login_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import 'provider_setup_page.dart';

class ProviderProfilePage extends StatefulWidget {
  final AuthUser user;
  final AuthApi api;
  final VoidCallback onSwitchToCustomer;

  const ProviderProfilePage({
    super.key,
    required this.user,
    required this.api,
    required this.onSwitchToCustomer,
  });

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  late AuthUser _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  String get _initials {
    final name = _currentUser.fullName.trim();
    final parts = name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      final first = parts[0];
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'KA';
  }

  String get _providerTitle {
    final skills = _currentUser.providerSkills;
    if (skills != null && skills.isNotEmpty) {
      final firstSkill = skills.split(RegExp(r'[·,]')).first.trim();
      return 'Verified $firstSkill specialist';
    }
    return 'Verified service specialist';
  }

  void _editProviderDetails() async {
    final updated = await Navigator.push<AuthUser>(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderSetupPage(user: _currentUser, api: widget.api),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }

  void _showEarningsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Earnings Overview',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Earned This Month',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs. ${(_currentUser.providerEarnings ?? 54000).toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const ListTile(
                leading: Icon(Icons.check_circle_outline, color: AppColors.primary),
                title: Text('14 Completed Jobs'),
                subtitle: Text('Average rating 4.9 ★'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Provider Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_outlined, color: AppColors.primary),
                title: const Text('Edit Provider Profile'),
                onTap: () {
                  Navigator.pop(ctx);
                  _editProviderDetails();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                title: const Text('Switch to Customer Mode'),
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onSwitchToCustomer();
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout_rounded, color: AppColors.error),
                title: const Text('Log out', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await widget.api.logout();
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => LoginPage(api: widget.api)),
                    (_) => false,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

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
              // ── Header: PROVIDER MODE & Title ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'PROVIDER MODE',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Provider profile',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.arrowLeft),
                    onPressed: widget.onSwitchToCustomer,
                    tooltip: 'Back to Customer',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s20),

              // ── White Profile Card (P43) ──
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r20),
                  border: Border.all(color: AppColors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(AppSpacing.s20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentUser.fullName.isNotEmpty ? _currentUser.fullName : 'Kamal Perera',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _providerTitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.mint,
                      backgroundImage: (_currentUser.profilePhotoUrl != null &&
                              _currentUser.profilePhotoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(_currentUser.profilePhotoUrl!)
                          : null,
                      child: (_currentUser.profilePhotoUrl == null ||
                              _currentUser.profilePhotoUrl!.isEmpty)
                          ? Text(
                              _initials,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Details Menu List (P43) ──
              _ProviderDetailTile(
                icon: Icons.business_center_outlined,
                title: 'Skills & services',
                subtitle: _currentUser.providerSkills != null && _currentUser.providerSkills!.isNotEmpty
                    ? '${_currentUser.providerSkills} · ${_currentUser.providerServices ?? ""}'
                    : 'Plumbing · Tap repair',
                onTap: _editProviderDetails,
              ),
              _ProviderDetailTile(
                icon: Icons.file_upload_outlined,
                title: 'Certifications',
                subtitle: _currentUser.providerCertifications != null &&
                        _currentUser.providerCertifications!.isNotEmpty
                    ? 'Uploaded · Verified'
                    : 'NVQ Plumbing',
                onTap: _editProviderDetails,
              ),
              _ProviderDetailTile(
                icon: Icons.location_on_outlined,
                title: 'Service areas',
                subtitle: _currentUser.providerServiceAreas != null &&
                        _currentUser.providerServiceAreas!.isNotEmpty
                    ? _currentUser.providerServiceAreas!
                    : 'Colombo and Nugegoda',
                onTap: _editProviderDetails,
              ),
              _ProviderDetailTile(
                icon: Icons.access_time_outlined,
                title: 'Availability',
                subtitle: _currentUser.providerAvailability != null &&
                        _currentUser.providerAvailability!.isNotEmpty
                    ? _currentUser.providerAvailability!
                    : 'Mon–Sat · 8 AM–6 PM',
                onTap: _editProviderDetails,
              ),
              _ProviderDetailTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Earnings',
                subtitle: 'Rs. ${(_currentUser.providerEarnings ?? 54000).toStringAsFixed(0)} this month',
                onTap: _showEarningsSheet,
              ),
              _ProviderDetailTile(
                icon: Icons.settings_outlined,
                title: 'Settings',
                subtitle: 'Account and notifications',
                onTap: _showSettingsSheet,
              ),
              const SizedBox(height: 24),

              // ── Switch to Customer Button (P43) ──
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                    ),
                  ),
                  onPressed: widget.onSwitchToCustomer,
                  child: const Text(
                    'Switch to Customer',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: bottomInset > 0 ? bottomInset + 16 : 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderDetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProviderDetailTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
