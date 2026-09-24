import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';

class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.back = true,
    this.step,
    this.label,
    this.icon,
  });
  final String title, subtitle;
  final Widget child;
  final bool back;
  final String? step;
  final String? label;
  final IconData? icon;

  // Builds a keyboard-safe authentication page matching the Figma design.
  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final type = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Optional uppercase label ──
                          if (label != null) ...[
                            Text(
                              label!.toUpperCase(),
                              style: type.labelMedium?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s4),
                          ],

                          // ── Title row with optional back arrow ──
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(title, style: type.headlineLarge),
                              ),
                              if (back && Navigator.canPop(context))
                                IconButton(
                                  tooltip: 'Back',
                                  icon: const Icon(AppIcons.arrowLeft),
                                  onPressed: () => Navigator.maybePop(context),
                                ),
                              if (step != null &&
                                  !(back && Navigator.canPop(context)))
                                Text(step!, style: type.bodySmall),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.s8),

                          // ── Subtitle ──
                          Text(
                            subtitle,
                            style: type.bodyLarge?.copyWith(
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s32),

                          // ── Optional icon pill ──
                          if (icon != null) ...[
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.all(AppSpacing.s16),
                                decoration: BoxDecoration(
                                  color: palette.soft,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  icon,
                                  size: 32,
                                  color: palette.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s24),
                          ],

                          // ── Page content ──
                          child,
                        ],
                      ),
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

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;

  // Announces actionable form errors to assistive technology.
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Semantics(
          liveRegion: true,
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.s16),
            padding: const EdgeInsets.all(AppSpacing.s12),
            decoration: BoxDecoration(
              border: Border.all(color: AppPalette.of(context).error),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        );
}
