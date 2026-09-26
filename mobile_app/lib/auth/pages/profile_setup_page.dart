import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';
import '../../home/pages/home_page.dart';
import '../../home/pages/location_picker_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';

class ProfileSetupPage extends StatefulWidget {
  final AuthApi api;
  final AuthUser user;

  const ProfileSetupPage({super.key, required this.api, required this.user});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _nameController;
  final TextEditingController _preferencesController = TextEditingController(
    text: 'Home maintenance · IT services',
  );

  UserLocation? _selectedLocation;
  bool _isDetectingLocation = false;

  final ImagePicker _picker = ImagePicker();
  String? _profilePhotoUrl;
  bool _uploadingPhoto = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _profilePhotoUrl = widget.user.profilePhotoUrl;
    _initLocation();
  }

  Future<void> _initLocation() async {
    // 1. Check existing saved location or existing user profile location
    try {
      final cached = await LocationService.getSavedLocation();
      if (cached != null && mounted) {
        setState(() {
          _selectedLocation = cached;
        });
      } else if ((widget.user.location != null &&
              widget.user.location!.isNotEmpty) ||
          (widget.user.address != null && widget.user.address!.isNotEmpty)) {
        setState(() {
          _selectedLocation = UserLocation(
            shortName: widget.user.location ?? 'My Location',
            address: widget.user.address ?? widget.user.location!,
            latitude: UserLocation.defaultLocation.latitude,
            longitude: UserLocation.defaultLocation.longitude,
          );
        });
      }
    } catch (_) {}

    // 2. Automatically get the phone's live GPS location
    if (mounted) setState(() => _isDetectingLocation = true);
    try {
      final live = await LocationService.determineCurrentPosition();
      if (live != null && mounted) {
        setState(() {
          _selectedLocation = live;
        });
        await LocationService.saveLocation(live);
      }
    } catch (_) {
      if (_selectedLocation == null && mounted) {
        setState(() {
          _selectedLocation = UserLocation.defaultLocation;
        });
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _openLocationPicker() async {
    final picked = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerPage(
          initialLocation: _selectedLocation ?? UserLocation.defaultLocation,
          autoGps:
              _selectedLocation == null ||
              _selectedLocation == UserLocation.defaultLocation,
        ),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedLocation = picked;
      });
      await LocationService.saveLocation(picked);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _preferencesController.dispose();
    super.dispose();
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

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploadingPhoto = true);

      final updated = await widget.api.uploadProfilePhoto(
        picked.path,
        userId: widget.user.id,
      );

      if (mounted) {
        setState(() {
          _profilePhotoUrl = updated.profilePhotoUrl;
          _uploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().contains('denied')
                  ? 'Permission denied: Please enable gallery/media access in Settings.'
                  : 'Could not upload photo: $e',
            ),
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
            ],
          ),
        ),
      ),
    );
  }

  void _skip() {
    final userWithPhoto = widget.user.copyWith(
      profilePhotoUrl: _profilePhotoUrl,
      location: _selectedLocation?.shortName,
      address: _selectedLocation?.address,
    );
    if (Navigator.canPop(context)) {
      Navigator.pop(context, userWithPhoto);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(user: userWithPhoto, api: widget.api),
      ),
      (_) => false,
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updatedUser = await widget.api.updateProfile(
        fullName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : widget.user.fullName,
        address: _selectedLocation?.address ?? _selectedLocation?.shortName,
        location: _selectedLocation?.shortName ?? _selectedLocation?.address,
        preferences: _preferencesController.text.trim().isNotEmpty
            ? _preferencesController.text.trim()
            : null,
        profilePhotoUrl: _profilePhotoUrl,
      );

      if (_selectedLocation != null) {
        await LocationService.saveLocation(_selectedLocation!);
      }

      if (!mounted) return;
      if (Navigator.canPop(context)) {
        Navigator.pop(context, updatedUser);
        return;
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomePage(user: updatedUser, api: widget.api),
        ),
        (_) => false,
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Tag Row: PROFILE SETUP · DO LATER ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'PROFILE SETUP',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            GestureDetector(
                              onTap: _skip,
                              child: const Text(
                                'DO LATER',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s4),

                        // ── Title with Back Button ──
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Make yourself at home',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (Navigator.canPop(context))
                              IconButton(
                                icon: const Icon(AppIcons.arrowLeft),
                                onPressed: () => Navigator.pop(context),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── Profile Photo Box ──
                        InkWell(
                          onTap: _uploadingPhoto ? null : _showPhotoOptions,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    _profilePhotoUrl != null &&
                                        _profilePhotoUrl!.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.border,
                                width:
                                    _profilePhotoUrl != null &&
                                        _profilePhotoUrl!.isNotEmpty
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 20,
                              horizontal: 16,
                            ),
                            child: _uploadingPhoto
                                ? const Center(
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox.square(
                                            dimension: 28,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.primary,
                                                  ),
                                            ),
                                          ),
                                          SizedBox(height: 10),
                                          Text(
                                            'Uploading photo…',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : (_profilePhotoUrl != null &&
                                      _profilePhotoUrl!.isNotEmpty)
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: AppColors.mint,
                                        backgroundImage:
                                            CachedNetworkImageProvider(
                                              _profilePhotoUrl!,
                                            ),
                                      ),
                                      const SizedBox(width: 16),
                                      const Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: AppColors.primary,
                                                size: 18,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Photo uploaded',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Tap to change photo',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  )
                                : Column(
                                    children: const [
                                      Icon(
                                        Icons.camera_alt_outlined,
                                        size: 30,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Add profile photo',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Help providers recognize you',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── Name Field ──
                        AuthInput(
                          label: 'Name',
                          controller: _nameController,
                          enabled: !_busy,
                        ),

                        // ── Location Selector (Pin on Map & Auto GPS) ──
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 4, bottom: 8),
                              child: Text(
                                'Location',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: _busy ? null : _openLocationPicker,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _selectedLocation != null
                                        ? AppColors.primary.withValues(
                                            alpha: 0.35,
                                          )
                                        : AppColors.border,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        AppIcons.location,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (_isDetectingLocation &&
                                              _selectedLocation == null)
                                            Row(
                                              children: const [
                                                SizedBox.square(
                                                  dimension: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(AppColors.primary),
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  'Detecting your location…',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            )
                                          else ...[
                                            Text(
                                              _selectedLocation?.shortName ??
                                                  'Set location',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              _selectedLocation?.address ??
                                                  'Tap to pinpoint on map',
                                              style: const TextStyle(
                                                fontSize: 12.5,
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.mint,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.map_rounded,
                                            size: 14,
                                            color: AppColors.primary,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            'Pin on map',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s16),
                          ],
                        ),

                        // ── Preferences Field ──
                        AuthInput(
                          label: 'Preferences',
                          hint: 'Home maintenance · IT services',
                          controller: _preferencesController,
                          enabled: !_busy,
                        ),

                        if (_error != null) ...[
                          AuthError(_error),
                          const SizedBox(height: 12),
                        ],

                        const SizedBox(height: AppSpacing.s16),

                        // ── Continue Button ──
                        AppButton(
                          label: 'Continue',
                          loading: _busy,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: AppSpacing.s16),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
