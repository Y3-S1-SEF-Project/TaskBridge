import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/pages/profile_setup_page.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../widgets/taskbridge_bottom_nav.dart';

class ProfilePage extends StatefulWidget {
  final AuthUser? user;
  final AuthApi? api;
  final VoidCallback? onBackToHome;
  final ValueChanged<int>? onTabChange;

  const ProfilePage({
    super.key,
    this.user,
    this.api,
    this.onBackToHome,
    this.onTabChange,
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
                onTap: () {
                  Navigator.pop(ctx);
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
                subtitle: const Text('Select a photo from your device library'),
                onTap: () {
                  Navigator.pop(ctx);
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
              // ── Header Tag ──
              const Text(
                'CUSTOMER MODE',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),

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

              // ── Profile Card: Centered Circle Photo, Name, and Mobile Number ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.r20),
                  border: Border.all(color: AppColors.border, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Profile photo in circle center with tap-to-upload & camera badge
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _showPhotoOptions,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.mint.withValues(
                              alpha: 0.7,
                            ),
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
                                      fontSize: 24,
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
                                  width: 2,
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
                    const SizedBox(height: 14),

                    // Name center below profile circle
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

                    // Mobile number center below name
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

              // ── Menu Options List ──
              _MenuItemRow(
                icon: Icons.person_outline_rounded,
                title: 'Edit profile',
                onTap: _openEditProfile,
              ),
              _MenuItemRow(
                icon: Icons.location_on_outlined,
                title: 'Saved addresses',
                onTap: _openSavedAddresses,
              ),
              _MenuItemRow(
                icon: Icons.shopping_bag_outlined,
                title: 'Payment methods',
                onTap: () => _showFeatureNotice('Payment methods'),
              ),
              _MenuItemRow(
                icon: Icons.star_border_rounded,
                title: 'My reviews',
                onTap: () => _showFeatureNotice('My reviews'),
              ),
              _MenuItemRow(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => _showFeatureNotice('Notifications'),
              ),
              _MenuItemRow(
                icon: Icons.settings_outlined,
                title: 'Settings',
                onTap: _openSettings,
              ),
              const SizedBox(height: 24),

              // ── Switch to Provider Button ──
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
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Provider Mode coming soon! Use your same account to offer services.',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: const Text(
                    'Switch to Provider',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Caption below button ──
              const Text(
                'Same account. A different way to use your skills.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              SizedBox(height: bottomInset > 0 ? bottomInset + 16 : 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: TaskBridgeBottomNav(
        currentIndex: 3,
        onTap: (index) {
          if (index == 0) {
            _handleBack();
          } else if (widget.onTabChange != null) {
            widget.onTabChange!(index);
          } else if (index == 0) {
            _handleBack();
          }
        },
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItemRow({
    required this.icon,
    required this.title,
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
            Icon(icon, size: 24, color: AppColors.primaryDark),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
