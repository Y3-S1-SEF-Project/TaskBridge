import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Semantic roles. Dark values are derived; they do not exist in Figma.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({required this.background, required this.surface, required this.text, required this.muted, required this.border, required this.primary, required this.pressed, required this.onPrimary, required this.soft, required this.onSoft, required this.success, required this.warning, required this.error, required this.info, required this.disabled});
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color primary;
  final Color pressed;
  final Color onPrimary;
  final Color soft;
  final Color onSoft;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;
  static Color blend(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  static const light = AppPalette(background: AppColors.background, surface: AppColors.surface, text: AppColors.textPrimary, muted: AppColors.textSecondary, border: AppColors.border, primary: AppColors.primary, pressed: AppColors.primaryDark, onPrimary: AppColors.surface, soft: AppColors.primaryLight, onSoft: AppColors.primary, success: AppColors.success, warning: AppColors.warning, error: AppColors.error, info: AppColors.info, disabled: AppColors.border);
  static final dark = AppPalette(background: AppColors.textPrimary, surface: blend(AppColors.textPrimary, AppColors.surface, .04), text: AppColors.background, muted: AppColors.mint, border: blend(AppColors.textPrimary, AppColors.surface, .20), primary: AppColors.mint, pressed: AppColors.primaryLight, onPrimary: AppColors.primaryDark, soft: AppColors.primaryDark, onSoft: AppColors.primaryLight, success: blend(AppColors.success, AppColors.surface, .45), warning: blend(AppColors.warning, AppColors.surface, .25), error: blend(AppColors.error, AppColors.surface, .45), info: blend(AppColors.info, AppColors.surface, .45), disabled: blend(AppColors.textPrimary, AppColors.surface, .20));
  static AppPalette of(BuildContext context) => Theme.of(context).extension<AppPalette>()!;
  @override
  AppPalette copyWith({Color? background, Color? surface, Color? text, Color? muted, Color? border, Color? primary, Color? pressed, Color? onPrimary, Color? soft, Color? onSoft, Color? success, Color? warning, Color? error, Color? info, Color? disabled}) => AppPalette(background: background ?? this.background, surface: surface ?? this.surface, text: text ?? this.text, muted: muted ?? this.muted, border: border ?? this.border, primary: primary ?? this.primary, pressed: pressed ?? this.pressed, onPrimary: onPrimary ?? this.onPrimary, soft: soft ?? this.soft, onSoft: onSoft ?? this.onSoft, success: success ?? this.success, warning: warning ?? this.warning, error: error ?? this.error, info: info ?? this.info, disabled: disabled ?? this.disabled);
  @override
  AppPalette lerp(covariant AppPalette? other, double t) {
    if (other == null) return this;
    return AppPalette(background: Color.lerp(background, other.background, t)!, surface: Color.lerp(surface, other.surface, t)!, text: Color.lerp(text, other.text, t)!, muted: Color.lerp(muted, other.muted, t)!, border: Color.lerp(border, other.border, t)!, primary: Color.lerp(primary, other.primary, t)!, pressed: Color.lerp(pressed, other.pressed, t)!, onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!, soft: Color.lerp(soft, other.soft, t)!, onSoft: Color.lerp(onSoft, other.onSoft, t)!, success: Color.lerp(success, other.success, t)!, warning: Color.lerp(warning, other.warning, t)!, error: Color.lerp(error, other.error, t)!, info: Color.lerp(info, other.info, t)!, disabled: Color.lerp(disabled, other.disabled, t)!);
  }
}
