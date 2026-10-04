import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import 'location_picker_page.dart';

class PersonalDetailsPage extends StatefulWidget {
  final AuthApi api;
  final AuthUser user;

  const PersonalDetailsPage({super.key, required this.api, required this.user});

  @override
  State<PersonalDetailsPage> createState() => _PersonalDetailsPageState();
}

class _PersonalDetailsPageState extends State<PersonalDetailsPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _preferencesController;
  late final TextEditingController _locationController;
  late final TextEditingController _addressController;

  final ImagePicker _picker = ImagePicker();
  String? _profilePhotoUrl;
  bool _uploadingPhoto = false;
  bool _saving = false;
  String? _error;

  UserLocation? _pickedLocation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _emailController = TextEditingController(text: widget.user.email);
    _preferencesController = TextEditingController(
      text: widget.user.preferences ?? 'Home maintenance · IT services',
    );
    _locationController = TextEditingController(
      text: LocationService.cleanLocationName(widget.user.location ?? ''),
    );
    _addressController = TextEditingController(
      text: LocationService.cleanLocationName(widget.user.address ?? ''),
    );
    _profilePhotoUrl = widget.user.profilePhotoUrl;
    _initSavedLocation();
  }

  Future<void> _initSavedLocation() async {
    final saved = await LocationService.getSavedLocation();
    if (saved != null && mounted) {
      final cleanShort = LocationService.cleanLocationName(saved.shortName);
      final cleanAddr = LocationService.cleanLocationName(saved.address);
      setState(() {
        if (_locationController.text.trim().isEmpty ||
            LocationService.isPlusCode(_locationController.text)) {
          _locationController.text = cleanShort;
        }
        if (_addressController.text.trim().isEmpty ||
            LocationService.isPlusCode(_addressController.text)) {
          _addressController.text = cleanAddr;
        }
        _pickedLocation = UserLocation(
          shortName: cleanShort.isNotEmpty ? cleanShort : 'Colombo',
          address: cleanAddr.isNotEmpty ? cleanAddr : 'Colombo, Sri Lanka',
          latitude: saved.latitude,
          longitude: saved.longitude,
        );
      });
    }
  }

  Future<void> _pickLocationOnMap() async {
    final cached = _pickedLocation ?? await LocationService.getSavedLocation();
    final initial = cached ?? UserLocation.defaultLocation;

    if (!mounted) return;
    final picked = await Navigator.push<UserLocation>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LocationPickerPage(initialLocation: initial, autoGps: false),
      ),
    );

    if (picked != null && mounted) {
      final cleanShort = LocationService.cleanLocationName(picked.shortName);
      final cleanAddr = LocationService.cleanLocationName(picked.address);
      final sanitized = UserLocation(
        shortName: cleanShort.isNotEmpty ? cleanShort : 'Colombo',
        address: cleanAddr.isNotEmpty ? cleanAddr : 'Colombo, Sri Lanka',
        latitude: picked.latitude,
        longitude: picked.longitude,
      );
      setState(() {
        _pickedLocation = sanitized;
        _locationController.text = sanitized.shortName;
        if (_addressController.text.trim().isEmpty ||
            _addressController.text.trim() == cached?.address ||
            LocationService.isPlusCode(_addressController.text)) {
          _addressController.text = sanitized.address;
        }
      });
      await LocationService.saveLocation(sanitized);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _preferencesController.dispose();
    _locationController.dispose();
    _addressController.dispose();
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
          '$permissionName permission is permanently denied. Please enable it in system settings to update your profile photo.',
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
            content: Text('Profile photo updated!'),
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
    final palette = AppPalette.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: palette.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: palette.soft,
                  child: Icon(
                    Icons.camera_alt_outlined,
                    color: palette.primary,
                  ),
                ),
                title: Text(
                  'Take photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                subtitle: Text(
                  'Use camera to capture a new picture',
                  style: TextStyle(color: palette.muted),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.camera);
                  if (!allowed) return;
                  _pickAndUploadPhoto(ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: palette.soft,
                  child: Icon(
                    Icons.photo_library_outlined,
                    color: palette.primary,
                  ),
                ),
                title: Text(
                  'Choose from gallery',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: palette.text,
                  ),
                ),
                subtitle: Text(
                  'Select a photo from device gallery & media',
                  style: TextStyle(color: palette.muted),
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

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Name cannot be empty.');
      return;
    }

    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final cleanLocation = LocationService.cleanLocationName(
        _locationController.text.trim(),
      );
      final cleanAddress = LocationService.cleanLocationName(
        _addressController.text.trim(),
      );

      final updatedUser = await widget.api.updateProfile(
        fullName: name,
        address: cleanAddress.isNotEmpty ? cleanAddress : null,
        location: cleanLocation.isNotEmpty ? cleanLocation : null,
        preferences: _preferencesController.text.trim().isNotEmpty
            ? _preferencesController.text.trim()
            : null,
        profilePhotoUrl: _profilePhotoUrl,
      );

      if (cleanLocation.isNotEmpty) {
        await LocationService.saveLocation(
          _pickedLocation ??
              UserLocation(
                shortName: cleanLocation,
                address: cleanAddress.isNotEmpty ? cleanAddress : cleanLocation,
                latitude: UserLocation.defaultLocation.latitude,
                longitude: UserLocation.defaultLocation.longitude,
              ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Personal details updated successfully'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.pop(context, updatedUser);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.arrowLeft, color: palette.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Personal details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s20,
            vertical: AppSpacing.s16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Profile Photo Section ──
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: palette.primary.withValues(alpha: 0.25),
                              width: 2,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: palette.soft,
                            backgroundImage:
                                _profilePhotoUrl != null &&
                                    _profilePhotoUrl!.isNotEmpty
                                ? CachedNetworkImageProvider(_profilePhotoUrl!)
                                : null,
                            child:
                                (_profilePhotoUrl == null ||
                                    _profilePhotoUrl!.isEmpty)
                                ? Icon(
                                    Iconsax.user,
                                    size: 42,
                                    color: palette.primary,
                                  )
                                : null,
                          ),
                        ),
                        if (_uploadingPhoto)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox.square(
                                  dimension: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: palette.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: palette.surface,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: _uploadingPhoto ? null : _showPhotoOptions,
                      style: TextButton.styleFrom(
                        foregroundColor: palette.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text(
                        'Change profile photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // ── Name Field ──
                  _buildFieldLabel('Full Name', palette),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── Phone Number (Verified) ──
                  _buildFieldLabel('Phone Number', palette),
                  const SizedBox(height: 6),
                  _buildReadOnlyField(
                    text: widget.user.phone,
                    icon: Icons.phone_iphone_rounded,
                    badgeText: 'Verified',
                    badgeColor: palette.primary,
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── Email Address (Verified) ──
                  _buildFieldLabel('Email Address', palette),
                  const SizedBox(height: 6),
                  _buildReadOnlyField(
                    text: widget.user.email,
                    icon: Icons.mail_outline_rounded,
                    badgeText: 'Linked',
                    badgeColor: palette.primary,
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── Saved Location / City (with Map & GPS) ──
                  _buildFieldLabel('Saved Location / City', palette),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border, width: 1.2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.soft,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: palette.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _locationController,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: palette.text,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: false,
                              fillColor: Colors.transparent,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              hintText: 'e.g. Maharagama, Colombo 03',
                              hintStyle: TextStyle(
                                color: palette.muted,
                                fontSize: 14,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickLocationOnMap,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: palette.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.map_outlined,
                                    size: 14,
                                    color: palette.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Map',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: palette.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── Home / Street Address Field ──
                  _buildFieldLabel('Home / Street Address', palette),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _addressController,
                    hint: 'e.g. No. 24, Park Road, Havelock Town',
                    icon: Icons.home_outlined,
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.s16),

                  // ── Preferences Field ──
                  _buildFieldLabel('Service Preferences', palette),
                  const SizedBox(height: 6),
                  _buildTextField(
                    controller: _preferencesController,
                    hint: 'e.g. Home maintenance, IT services',
                    icon: Icons.category_outlined,
                    palette: palette,
                  ),
                  const SizedBox(height: AppSpacing.s24),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.s16),
                  ],

                  // ── Save Changes Button ──
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _saving ? null : _saveChanges,
                      child: _saving
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  palette.onPrimary,
                                ),
                              ),
                            )
                          : const Text(
                              'Save changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label, AppPalette palette) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppPalette palette,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: palette.muted, fontSize: 14),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String text,
    required IconData icon,
    required String badgeText,
    required Color badgeColor,
    required AppPalette palette,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border, width: 1.2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: palette.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: palette.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: palette.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.verified_rounded, size: 13, color: badgeColor),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
