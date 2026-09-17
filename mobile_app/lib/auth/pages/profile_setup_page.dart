import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/design_system.dart';
import '../../home/pages/home_page.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../widgets/auth_input.dart';
import '../widgets/auth_layout.dart';

class ProfileSetupPage extends StatefulWidget {
  final AuthApi api;
  final AuthUser user;

  const ProfileSetupPage({
    super.key,
    required this.api,
    required this.user,
  });

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _nameController;
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _locationController =
      TextEditingController(text: 'Colombo 05');
  final TextEditingController _preferencesController =
      TextEditingController(text: 'Home maintenance · IT services');

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _locationController.dispose();
    _preferencesController.dispose();
    super.dispose();
  }

  void _skip() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => HomePage(user: widget.user, api: widget.api),
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
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        location: _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        preferences: _preferencesController.text.trim().isNotEmpty
            ? _preferencesController.text.trim()
            : null,
      );

      if (!mounted) return;
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
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
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
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Column(
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
                        const SizedBox(height: AppSpacing.s20),

                        // ── Name Field ──
                        AuthInput(
                          label: 'Name',
                          controller: _nameController,
                          enabled: !_busy,
                        ),

                        // ── Address Field ──
                        AuthInput(
                          label: 'Address',
                          hint: '24 Park Road',
                          controller: _addressController,
                          enabled: !_busy,
                        ),

                        // ── Location Field ──
                        AuthInput(
                          label: 'Location',
                          hint: 'Colombo 05',
                          controller: _locationController,
                          enabled: !_busy,
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
