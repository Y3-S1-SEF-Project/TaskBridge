import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../ai/models/review_models.dart';
import '../../ai/services/review_api.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/pages/login_page.dart';
import '../../core/services/theme_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_palette.dart';
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
  List<FeedbackModel> _feedbacks = [];
  bool _isLoadingFeedbacks = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoadingFeedbacks = true);
    final list = await ReviewApi.getProviderFeedbacks(_currentUser.id);
    if (mounted) {
      setState(() {
        _isLoadingFeedbacks = false;
        _feedbacks = list;
      });
    }
  }

  double get _averageRating {
    if (_feedbacks.isEmpty) return 5.0;
    final sum = _feedbacks.fold<double>(
      0.0,
      (acc, f) => acc + f.rating.toDouble(),
    );
    return sum / _feedbacks.length;
  }

  String get _initials {
    final name = _currentUser.fullName.trim();
    final parts = name
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
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
        builder: (_) => ProviderSetupPage(
          user: _currentUser,
          api: widget.api,
          isFirstTime: false,
        ),
      ),
    );
    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }

  void _showEarningsSheet() {
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: palette.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Earnings Overview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.soft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Total Earned This Month',
                      style: TextStyle(
                        fontSize: 13,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs. ${(_currentUser.providerEarnings ?? 54000).toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: palette.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  Icons.check_circle_outline,
                  color: palette.primary,
                ),
                title: Text(
                  'Completed Jobs & Feedback',
                  style: TextStyle(color: palette.text),
                ),
                subtitle: Text(
                  _feedbacks.isEmpty
                      ? 'No ratings yet'
                      : 'Average rating ${_averageRating.toStringAsFixed(1)} ★ (${_feedbacks.length} ${_feedbacks.length == 1 ? 'review' : 'reviews'})',
                  style: TextStyle(color: palette.muted),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFeedbacksSheet() {
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: palette.surface,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s20,
              vertical: AppSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Client Reviews',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    if (_feedbacks.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF59E0B),
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: palette.text,
                            ),
                          ),
                          Text(
                            ' (${_feedbacks.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: palette.muted,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoadingFeedbacks
                      ? const Center(child: CircularProgressIndicator())
                      : _feedbacks.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.rate_review_outlined,
                                    size: 48,
                                    color: palette.muted,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No reviews yet',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Completed jobs with client ratings will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              controller: scrollController,
                              itemCount: _feedbacks.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final fb = _feedbacks[i];
                            return Container(
                              padding: const EdgeInsets.all(AppSpacing.s16),
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: palette.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        fb.customerName.isNotEmpty
                                            ? fb.customerName
                                            : 'Customer',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: palette.text,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          ...List.generate(5, (starIdx) {
                                            return Icon(
                                              starIdx < fb.rating.floor()
                                                  ? Icons.star_rounded
                                                  : (starIdx < fb.rating
                                                      ? Icons.star_half_rounded
                                                      : Icons
                                                          .star_outline_rounded),
                                              color: const Color(0xFFF59E0B),
                                              size: 16,
                                            );
                                          }),
                                          const SizedBox(width: 4),
                                          Text(
                                            fb.rating.toStringAsFixed(1),
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: palette.text,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Booking #${fb.bookingReference}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: palette.muted,
                                    ),
                                  ),
                                  if (fb.comment.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      fb.comment,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: palette.text,
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet() {
    final palette = AppPalette.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: palette.surface,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sheetIsDark = ThemeService.instance.isDarkMode(ctx);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Provider Settings',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.text,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      sheetIsDark ? Iconsax.moon : Iconsax.sun_1,
                      color: palette.primary,
                    ),
                    title: Text(
                      'Dark Mode',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                      ),
                    ),
                    subtitle: Text(
                      sheetIsDark ? 'Dark theme enabled' : 'Light theme enabled',
                      style: TextStyle(color: palette.muted, fontSize: 13),
                    ),
                    trailing: Switch.adaptive(
                      value: sheetIsDark,
                      activeTrackColor: palette.primary,
                      activeThumbColor: Colors.white,
                      onChanged: (val) async {
                        await ThemeService.instance.toggleTheme(context);
                        setSheetState(() {});
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.edit_outlined,
                      color: palette.primary,
                    ),
                    title: Text(
                      'Edit Provider Profile',
                      style: TextStyle(color: palette.text),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _editProviderDetails();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.swap_horiz_rounded,
                      color: palette.primary,
                    ),
                    title: Text(
                      'Switch to Customer Mode',
                      style: TextStyle(color: palette.text),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onSwitchToCustomer();
                    },
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                    ),
                    title: const Text(
                      'Log out',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await widget.api.logout();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LoginPage(api: widget.api),
                        ),
                        (_) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmLogout() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        title: const Text('Log out'),
        content: const Text(
          'Are you sure you want to log out of your provider account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true && mounted) {
        await widget.api.logout();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => LoginPage(api: widget.api)),
          (_) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final isDark = ThemeService.instance.isDarkMode(context);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Title ──
              Text(
                'Provider profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: palette.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Profile Info (Clean, no box container) ──
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: palette.soft,
                      backgroundImage:
                          (_currentUser.profilePhotoUrl != null &&
                              _currentUser.profilePhotoUrl!.isNotEmpty)
                          ? CachedNetworkImageProvider(
                              _currentUser.profilePhotoUrl!,
                            )
                          : null,
                      child:
                          (_currentUser.profilePhotoUrl == null ||
                              _currentUser.profilePhotoUrl!.isEmpty)
                          ? Text(
                              _initials,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: palette.primary,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentUser.fullName.isNotEmpty
                          ? _currentUser.fullName
                          : 'Kamal Perera',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _providerTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _showFeedbacksSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: palette.soft,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 16,
                              color: Color(0xFFF59E0B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _feedbacks.isEmpty
                                  ? 'New Provider'
                                  : '${_averageRating.toStringAsFixed(1)} (${_feedbacks.length} ${_feedbacks.length == 1 ? 'review' : 'reviews'})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: palette.text,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 14,
                              color: palette.muted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Group 1: Services & Work Details ──
              _buildSectionLabel('SERVICES & WORK DETAILS', palette),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: Iconsax.briefcase,
                    title: 'Skills & services',
                    subtitle:
                        (_currentUser.providerServices != null &&
                            _currentUser.providerServices!.trim().isNotEmpty)
                        ? _currentUser.providerServices!
                        : ((_currentUser.providerSkills != null &&
                                  _currentUser.providerSkills!
                                      .trim()
                                      .isNotEmpty)
                              ? _currentUser.providerSkills!
                              : 'Tap to add services'),
                    iconBgColor: palette.soft,
                    iconColor: palette.primary,
                    onTap: _editProviderDetails,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.shield_tick,
                    title: 'Certifications',
                    subtitle:
                        _currentUser.providerCertifications != null &&
                            _currentUser.providerCertifications!.isNotEmpty
                        ? 'Uploaded · Verified'
                        : 'Tap to upload certificates',
                    iconBgColor: const Color(0xFFEBF3FF),
                    iconColor: const Color(0xFF2563EB),
                    onTap: _editProviderDetails,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.location,
                    title: 'Location & service radius',
                    subtitle:
                        (_currentUser.providerServiceAreas != null &&
                            _currentUser.providerServiceAreas!
                                .trim()
                                .isNotEmpty)
                        ? _currentUser.providerServiceAreas!
                        : ((_currentUser.location != null &&
                                  _currentUser.location!.trim().isNotEmpty)
                              ? _currentUser.location!
                              : 'Tap to set location and radius'),
                    iconBgColor: const Color(0xFFEDFAF1),
                    iconColor: const Color(0xFF16A34A),
                    onTap: _editProviderDetails,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.clock,
                    title: 'Availability',
                    subtitle:
                        _currentUser.providerAvailability != null &&
                            _currentUser.providerAvailability!.trim().isNotEmpty
                        ? _currentUser.providerAvailability!
                        : 'Set working hours',
                    iconBgColor: const Color(0xFFFEF9C3),
                    iconColor: const Color(0xFFCA8A04),
                    onTap: _editProviderDetails,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.star,
                    title: 'Client reviews & ratings',
                    subtitle: _feedbacks.isEmpty
                        ? 'No client reviews yet'
                        : '${_averageRating.toStringAsFixed(1)} ★ (${_feedbacks.length} ${_feedbacks.length == 1 ? 'review' : 'reviews'})',
                    iconBgColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    onTap: _showFeedbacksSheet,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.wallet_2,
                    title: 'Earnings overview',
                    subtitle:
                        'Rs. ${(_currentUser.providerEarnings ?? 54000).toStringAsFixed(0)} this month',
                    iconBgColor: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    showDivider: false,
                    onTap: _showEarningsSheet,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Switch Mode Section (Below Earnings overview) ──
              _buildSectionLabel('SWITCH MODE', palette),
              _MenuCard(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onSwitchToCustomer,
                      borderRadius: BorderRadius.circular(AppRadius.r16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: palette.soft,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Icon(
                                  Iconsax.repeat,
                                  size: 20,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer mode',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: palette.text,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Switch to customer dashboard',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: palette.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: false,
                              activeTrackColor: palette.primary,
                              activeThumbColor: Colors.white,
                              onChanged: (val) {
                                if (val) widget.onSwitchToCustomer();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Group 2: Preferences ──
              _buildSectionLabel('PREFERENCES', palette),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: isDark ? Iconsax.moon : Iconsax.sun_1,
                    title: 'Dark mode',
                    subtitle:
                        isDark ? 'Dark theme enabled' : 'Light theme enabled',
                    iconBgColor: isDark
                        ? palette.soft
                        : const Color(0xFFFEF3C7),
                    iconColor: isDark
                        ? palette.primary
                        : const Color(0xFFD97706),
                    trailing: Switch.adaptive(
                      value: isDark,
                      activeTrackColor: palette.primary,
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        ThemeService.instance.toggleTheme(context);
                      },
                    ),
                    onTap: () {
                      ThemeService.instance.toggleTheme(context);
                    },
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.setting_2,
                    title: 'Settings',
                    subtitle: 'Account, notifications and security',
                    iconBgColor: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF475569),
                    showDivider: false,
                    onTap: _showSettingsSheet,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Group 3: Account Actions ──
              _buildSectionLabel('ACCOUNT ACTIONS', palette),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: Iconsax.logout,
                    title: 'Log out',
                    subtitle: 'Safely sign out from provider account',
                    iconBgColor: const Color(0xFFFEE2E2),
                    iconColor: AppColors.error,
                    textColor: AppColors.error,
                    trailing: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: AppColors.error,
                    ),
                    showDivider: false,
                    onTap: _confirmLogout,
                  ),
                ],
              ),
              SizedBox(height: bottomInset > 0 ? bottomInset + 16 : 24),
            ],
          ),
        ),
      ),
    );
  }


