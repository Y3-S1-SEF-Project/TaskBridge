import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/profile_setup_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/services/user_mode_service.dart';
import '../../provider/pages/provider_main_page.dart';
import '../../provider/pages/provider_setup_page.dart';
import '../widgets/taskbridge_bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  final AuthUser? user;
  final AuthApi? api;
  final VoidCallback? onBackToHome;
  final ValueChanged<int>? onTabChange;
  final bool showBottomNav;

  const ProfilePage({
    super.key,
    this.user,
    this.api,
    this.onBackToHome,
    this.onTabChange,
    this.showBottomNav = true,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late AuthUser? _currentUser;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  String get _initials {
    final name = _currentUser?.fullName.trim() ?? 'Kavindu Alwis';
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

  String get _formattedPhone {
    final phone = _currentUser?.phone.trim();
    if (phone != null && phone.isNotEmpty) {
      if (phone.startsWith('+')) return phone;
      if (phone.startsWith('0') && phone.length >= 10) {
        return '+94 ${phone.substring(1, 3)} ${phone.substring(3, 6)} ${phone.substring(6)}';
      }
      return '+94 $phone';
    }
    return '+94 77 123 4567';
  }

  void _handleBack() {
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  void _openEditProfile() async {
    if (_currentUser == null || widget.api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile details are not loaded yet.')),
      );
      return;
    }

    final updated = await Navigator.push<AuthUser>(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupPage(api: widget.api!, user: _currentUser!),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _currentUser = updated);
    }
  }

  void _openSavedAddresses() {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saved addresses',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.home_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Primary Home',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentUser?.address != null &&
                                  _currentUser!.address!.isNotEmpty
                              ? '${_currentUser!.address}, ${_currentUser!.location ?? "Colombo"}'
                              : '754, Baseline Road, Colombo 05',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _openSettings() {
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
                'Settings & Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.info_outline,
                  color: AppColors.primary,
                ),
                title: const Text('App Version'),
                trailing: const Text(
                  '1.0.0 (Build 4)',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
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
                  if (widget.api != null) {
                    await widget.api!.logout();
                  }
                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoginPage(api: widget.api ?? AuthApi()),
                    ),
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

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r16),
        ),
        title: const Text(
          'Log out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out of your TaskBridge account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.r12),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final api = widget.api ?? AuthApi();
              await api.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => LoginPage(api: api)),
                (_) => false,
              );
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  void _switchToProvider() async {
    if (_currentUser == null || widget.api == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while user details are loaded.'),
        ),
      );
      return;
    }

    if (!_currentUser!.isProvider) {
      final hasDetails =
          (_currentUser!.providerSkills?.trim().isNotEmpty == true) ||
          (_currentUser!.providerServices?.trim().isNotEmpty == true);
      // First time: navigate to Provider Setup screen P10
      final updated = await Navigator.push<AuthUser>(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderSetupPage(
            user: _currentUser!,
            api: widget.api!,
            isFirstTime: !hasDetails,
          ),
        ),
      );
      if (updated != null && mounted) {
        setState(() => _currentUser = updated);
      }
    } else {
      // Already a provider: switch directly to Provider Mode!
      await UserModeService.setMode(UserMode.provider);
      if (!mounted) return;
      final updated = await Navigator.push<AuthUser>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ProviderMainPage(user: _currentUser!, api: widget.api!),
        ),
      );
      await UserModeService.setMode(UserMode.customer);
      if (updated != null && mounted) {
        setState(() => _currentUser = updated);
      }
    }
  }

  void _showFeatureNotice(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$featureName will be available in the next release.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);

      final api = widget.api ?? AuthApi();
      final updated = await api.uploadProfilePhoto(
        picked.path,
        userId: _currentUser?.id,
      );

      if (mounted) {
        setState(() {
          _currentUser = updated;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied && mounted) {
          _showSettingsDialog('Camera');
        }
        return false;
      }
      return true;
    } else {
      PermissionStatus status;
      if (Platform.isAndroid) {
        status = await Permission.photos.request();
        if (status.isDenied) {
          status = await Permission.storage.request();
        }
      } else {
        status = await Permission.photos.request();
      }

      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied && mounted) {
          _showSettingsDialog('Photos & Media');
        }
        return false;
      }
      return true;
    }
  }

  void _showSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$permissionName Permission Required'),
        content: Text(
          '$permissionName permission is permanently denied. Please enable it in system settings to upload your profile photo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Take photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Use camera to capture a new picture'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.camera);
                  if (!allowed) return;
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text(
                  'Choose from gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Select a photo from device gallery & media',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.gallery);
                  if (!allowed) return;
                  _pickAndUploadPhoto(ImageSource.gallery);
                },
              ),
              if (_currentUser?.profilePhotoUrl != null &&
                  _currentUser!.profilePhotoUrl!.isNotEmpty) ...[
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.error.withValues(alpha: 0.1),
                    child: const Icon(
                      Icons.delete_outline,
                      color: AppColors.error,
                    ),
                  ),
                  title: const Text(
                    'Remove photo',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    try {
                      setState(() => _isUploadingPhoto = true);
                      final api = widget.api ?? AuthApi();
                      final updated = await api.updateProfile(
                        profilePhotoUrl: '',
                      );
                      if (mounted) {
                        setState(() {
                          _currentUser = updated.copyWith(profilePhotoUrl: '');
                          _isUploadingPhoto = false;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isUploadingPhoto = false);
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
              ],
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
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Title ──
              const Text(
                'Your profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),

              // ── Profile Info (Clean, no box container) ──
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: AppColors.primaryLight,
                            backgroundImage:
                                (_currentUser?.profilePhotoUrl != null &&
                                    _currentUser!.profilePhotoUrl!.isNotEmpty)
                                ? CachedNetworkImageProvider(
                                    _currentUser!.profilePhotoUrl!,
                                  )
                                : null,
                            child: _isUploadingPhoto
                                ? const SizedBox.square(
                                    dimension: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                    ),
                                  )
                                : (_currentUser?.profilePhotoUrl == null ||
                                      _currentUser!.profilePhotoUrl!.isEmpty)
                                ? Text(
                                    _initials,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _currentUser?.fullName ?? 'Kavindu Alwis',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formattedPhone,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Group 1: Account & Services ──
              _buildSectionLabel('ACCOUNT & SERVICES'),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: Iconsax.user_edit,
                    title: 'Personal details',
                    subtitle: 'Name, phone & profile picture',
                    iconBgColor: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    onTap: _openEditProfile,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.location,
                    title: 'Saved addresses',
                    subtitle:
                        _currentUser?.address != null &&
                            _currentUser!.address!.isNotEmpty
                        ? _currentUser!.address!
                        : 'Delivery and service locations',
                    iconBgColor: const Color(0xFFEBF3FF),
                    iconColor: const Color(0xFF2563EB),
                    onTap: _openSavedAddresses,
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.wallet_2,
                    title: 'Payment methods',
                    subtitle: 'Cards, payment preferences & history',
                    iconBgColor: const Color(0xFFEDFAF1),
                    iconColor: const Color(0xFF16A34A),
                    onTap: () => _showFeatureNotice('Payment methods'),
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.star,
                    title: 'My reviews',
                    subtitle: 'Ratings & feedback given to specialists',
                    iconBgColor: const Color(0xFFFEF9C3),
                    iconColor: const Color(0xFFCA8A04),
                    showDivider: false,
                    onTap: () => _showFeatureNotice('My reviews'),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Switch Mode Section (Below My reviews) ──
              _buildSectionLabel('SWITCH MODE'),
              _MenuCard(
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _switchToProvider,
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
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Icon(
                                  Iconsax.repeat,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Provider mode',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Switch to provider dashboard',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: false,
                              activeTrackColor: AppColors.primary,
                              activeThumbColor: Colors.white,
                              onChanged: (val) {
                                if (val) _switchToProvider();
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
              _buildSectionLabel('PREFERENCES'),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: Iconsax.notification,
                    title: 'Notifications',
                    subtitle: 'Alerts, booking updates & reminders',
                    iconBgColor: const Color(0xFFF3E8FF),
                    iconColor: const Color(0xFF9333EA),
                    onTap: () => _showFeatureNotice('Notifications'),
                  ),
                  _SleekMenuTile(
                    icon: Iconsax.setting_2,
                    title: 'Settings & Privacy',
                    subtitle: 'App preferences, security & terms',
                    iconBgColor: const Color(0xFFF1F5F9),
                    iconColor: const Color(0xFF475569),
                    showDivider: false,
                    onTap: _openSettings,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Group 3: Account Actions ──
              _buildSectionLabel('ACCOUNT ACTIONS'),
              _MenuCard(
                children: [
                  _SleekMenuTile(
                    icon: Iconsax.logout,
                    title: 'Log out',
                    subtitle: 'Safely sign out from this device',
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
              const SizedBox(height: 24),

              SizedBox(height: bottomInset > 0 ? bottomInset + 16 : 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? TaskBridgeBottomNav(
              currentIndex: 3,
              onTap: (index) {
                if (widget.onTabChange != null) {
                  widget.onTabChange!(index);
                } else if (index == 0) {
                  _handleBack();
                }
              },
            )
          : null,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;

  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(color: AppColors.border, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _SleekMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final Color? textColor;
  final Widget? trailing;
  final bool showDivider;

  const _SleekMenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.textColor,
    this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.r16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBgColor ?? AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor ?? AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textColor ?? AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                trailing ??
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
              ],
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 68, right: 14),
            child: Divider(
              height: 1,
              thickness: 0.8,
              color: AppColors.border.withValues(alpha: 0.6),
            ),
          ),
      ],
    );
  }
}
