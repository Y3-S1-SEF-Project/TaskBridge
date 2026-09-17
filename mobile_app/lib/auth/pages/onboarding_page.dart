import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/design_system.dart';
import '../data/auth_api.dart';
import 'login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key, required this.api});
  final AuthApi api;

  // Creates the three-step introduction state.
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int index = 0;

  /// Each step matches the Figma C02–C04 onboarding screens.
  static const steps = [
    (
      title: 'The right skill.\nRight around you.',
      description:
          'Find trusted local specialists for everything your home needs.',
      image: 'assets/images/onboarding_1.jpg',
      icon: AppIcons.searchNormal,
      tag: 'Local skills, real people',
    ),
    (
      title: 'Good work starts\nwith trust.',
      description:
          'Compare verified profiles, agree a price and book a time that works for you.',
      image: 'assets/images/onboarding_2.jpg',
      icon: AppIcons.shieldTick,
      tag: 'Verified. Reviewed. Reliable.',
    ),
    (
      title: 'A little help\nfinding the right help.',
      description:
          'Describe the problem. TaskBridge AI helps you choose, while you stay in control.',
      image: 'assets/images/onboarding_3.jpg',
      icon: AppIcons.magicpen,
      tag: 'AI assistance is always optional',
    ),
  ];

  // Opens login without retaining onboarding in the back stack.
  void _openLogin() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => LoginPage(api: widget.api)),
  );

  void _next() {
    if (index == 2) {
      _openLogin();
    } else {
      setState(() => index++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final type = Theme.of(context).textTheme;
    final step = steps[index];

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              const SizedBox(height: AppSpacing.s12),
              Text(
                'Welcome to\nTaskBridge',
                style: AppTypography.h1.copyWith(color: palette.text),
              ),
              const SizedBox(height: AppSpacing.s24),

              // ── Scrollable content area ──
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Illustration card with generated art ──
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.r16),
                        child: Container(
                          width: double.infinity,
                          height: 210,
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(AppRadius.r16),
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: Image.asset(
                            step.image,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Icon(
                                step.icon,
                                size: 48,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // ── Tag chip ──
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s12,
                          vertical: AppSpacing.s8,
                        ),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadius.r24),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              AppIcons.tickCircle,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: AppSpacing.s8),
                            Flexible(
                              child: Text(
                                step.tag,
                                style: type.bodySmall?.copyWith(
                                  color: palette.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s24),

                      // ── Title ──
                      Text(
                        step.title,
                        style: AppTypography.display.copyWith(
                          color: palette.text,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.s12),

                      // ── Description ──
                      Text(
                        step.description,
                        style: type.bodyLarge?.copyWith(color: palette.muted),
                      ),
                      const SizedBox(height: AppSpacing.s16),

                      // ── Page counter ──
                      Text(
                        '${index + 1} / 3',
                        style: type.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom actions ──
              const SizedBox(height: AppSpacing.s16),
              AppButton(
                label: index == 2 ? 'Get Started' : 'Next',
                onPressed: _next,
              ),
              const SizedBox(height: AppSpacing.s8),
              Center(
                child: TextButton(
                  onPressed: _openLogin,
                  child: Text(
                    'Skip',
                    style: type.bodyMedium?.copyWith(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s12),
            ],
          ),
        ),
      ),
    );
  }
}
