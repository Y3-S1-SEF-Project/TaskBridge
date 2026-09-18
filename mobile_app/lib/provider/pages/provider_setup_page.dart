import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../auth/widgets/auth_input.dart';
import '../../auth/widgets/auth_layout.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';
import 'provider_main_page.dart';

class ProviderSetupPage extends StatefulWidget {
  final AuthUser user;
  final AuthApi api;

  const ProviderSetupPage({
    super.key,
    required this.user,
    required this.api,
  });

  @override
  State<ProviderSetupPage> createState() => _ProviderSetupPageState();
}

class _ProviderSetupPageState extends State<ProviderSetupPage> {
  late final TextEditingController _skillsController;
  late final TextEditingController _servicesController;
  late final TextEditingController _experienceController;
  late final TextEditingController _serviceAreasController;
  late final TextEditingController _availabilityController;
  late final TextEditingController _bioController;

  final ImagePicker _picker = ImagePicker();
  String? _certificationUrl;
  bool _uploadingCert = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _skillsController = TextEditingController(
      text: widget.user.providerSkills ?? 'Plumbing · Leak detection',
    );
    _servicesController = TextEditingController(
      text: widget.user.providerServices ?? 'Tap repair · Pipe replacement',
    );
    _experienceController = TextEditingController(
      text: widget.user.providerExperience ?? '8 years',
    );
    _serviceAreasController = TextEditingController(
      text: widget.user.providerServiceAreas ?? 'Colombo 03, 04, 05, 06',
    );
    _availabilityController = TextEditingController(
      text: widget.user.providerAvailability ?? 'Mon–Sat · 8 AM–6 PM',
    );
    _bioController = TextEditingController(
      text: widget.user.providerBio ?? 'Experienced plumbing & leak detection professional.',
    );
    _certificationUrl = widget.user.providerCertifications;
  }

  @override
  void dispose() {
    _skillsController.dispose();
    _servicesController.dispose();
    _experienceController.dispose();
    _serviceAreasController.dispose();
    _availabilityController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<bool> _ensurePermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      final status = await Permission.camera.request();
      return status.isGranted || status.isLimited;
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
      return status.isGranted || status.isLimited;
    }
  }

  Future<void> _pickAndUploadCert() async {
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
                'Upload Certification',
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
                  child: Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                ),
                title: const Text('Take photo of certificate', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.camera);
                  if (!allowed) return;
                  _processCertUpload(ImageSource.camera);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(Icons.photo_library_outlined, color: AppColors.primary),
                ),
                title: const Text('Choose from gallery / files', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final allowed = await _ensurePermission(ImageSource.gallery);
                  if (!allowed) return;
                  _processCertUpload(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processCertUpload(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1500,
        maxHeight: 1500,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _uploadingCert = true);

      final updated = await widget.api.uploadCertification(
        picked.path,
        userId: widget.user.id,
      );

      if (mounted) {
        setState(() {
          _certificationUrl = updated.providerCertifications;
          _uploadingCert = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Certification uploaded successfully!'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingCert = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not upload certification: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _skipAndEnterProviderMode() async {
    // If skipped, mark provider enabled and enter provider mode
    setState(() => _busy = true);
    try {
      final updated = await widget.api.saveProviderProfile(
        skills: widget.user.providerSkills ?? 'Plumbing · Leak detection',
        services: widget.user.providerServices ?? 'Tap repair · Pipe replacement',
        experience: widget.user.providerExperience ?? '8 years',
        serviceAreas: widget.user.providerServiceAreas ?? 'Colombo and Nugegoda',
        availability: widget.user.providerAvailability ?? 'Mon–Sat · 8 AM–6 PM',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderMainPage(user: updated, api: widget.api),
        ),
      );
    } catch (e) {
      // Fallback directly to provider mode even if network fails
      final fallbackUser = widget.user.copyWith(isProvider: true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderMainPage(user: fallbackUser, api: widget.api),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final updated = await widget.api.saveProviderProfile(
        skills: _skillsController.text.trim(),
        services: _servicesController.text.trim(),
        experience: _experienceController.text.trim(),
        certifications: _certificationUrl,
        serviceAreas: _serviceAreasController.text.trim(),
        availability: _availabilityController.text.trim(),
        bio: _bioController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ProviderMainPage(user: updated, api: widget.api),
        ),
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
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Top Tag Row with "Do Later" / "Skip this" ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'YOUR EXPERTISE, YOUR OPPORTUNITY',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            GestureDetector(
                              onTap: _skipAndEnterProviderMode,
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

                        // ── Title Row with Back Arrow ──
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Set up your provider\nprofile',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(AppIcons.arrowLeft),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.s20),

                        // ── 1. Skills Field ──
                        AuthInput(
                          label: 'Skills',
                          hint: 'Plumbing · Leak detection',
                          controller: _skillsController,
                          enabled: !_busy,
                        ),

                        // ── 2. Services Field ──
                        AuthInput(
                          label: 'Services',
                          hint: 'Tap repair · Pipe replacement',
                          controller: _servicesController,
                          enabled: !_busy,
                        ),

                        // ── 3. Experience Field ──
                        AuthInput(
                          label: 'Experience',
                          hint: '8 years',
                          controller: _experienceController,
                          enabled: !_busy,
                        ),

                        // ── 4. Upload Certifications Card (P10) ──
                        InkWell(
                          onTap: _uploadingCert ? null : _pickAndUploadCert,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _certificationUrl != null && _certificationUrl!.isNotEmpty
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: _certificationUrl != null && _certificationUrl!.isNotEmpty ? 1.5 : 1,
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            child: _uploadingCert
                                ? const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox.square(
                                          dimension: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          'Uploading certification to Cloudflare R2…',
                                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  )
                                : Column(
                                    children: [
                                      Icon(
                                        _certificationUrl != null && _certificationUrl!.isNotEmpty
                                            ? Icons.check_circle_rounded
                                            : Icons.camera_alt_outlined,
                                        size: 32,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _certificationUrl != null && _certificationUrl!.isNotEmpty
                                            ? 'Certifications uploaded'
                                            : 'Upload certifications',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _certificationUrl != null && _certificationUrl!.isNotEmpty
                                            ? 'Tap to update or add more'
                                            : 'PDF or photo · Optional',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.s16),

                        // ── 5. Service Areas Field ──
                        AuthInput(
                          label: 'Service areas',
                          hint: 'Colombo 03, 04, 05, 06',
                          controller: _serviceAreasController,
                          enabled: !_busy,
                        ),

                        // ── 6. Availability Field ──
                        AuthInput(
                          label: 'Availability',
                          hint: 'Mon–Sat · 8 AM–6 PM',
                          controller: _availabilityController,
                          enabled: !_busy,
                        ),

                        // ── 7. Bio Field ──
                        AuthInput(
                          label: 'Bio (Optional)',
                          hint: 'Short professional introduction',
                          controller: _bioController,
                          enabled: !_busy,
                        ),

                        if (_error != null) ...[
                          AuthError(_error),
                          const SizedBox(height: 12),
                        ],

                        const SizedBox(height: AppSpacing.s16),

                        // ── Finish Setup Button ──
                        AppButton(
                          label: 'Finish Setup',
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
