import 'package:flutter/material.dart';
import 'app_metrics.dart';
import 'app_palette.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

import 'package:flutter/services.dart';

/// Source: https://www.figma.com/design/vyFvCE5DxjCFs1TAS3qVf8 (page 0:1).
/// Light primitives, type, geometry and zero elevation preserve Figma.
/// Dark roles are derived in AppPalette, not an authored Figma dark mode.
/// Internal showcase entry point: lib/main_showcase.dart.
abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, AppPalette.light);
  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);

  static SystemUiOverlayStyle systemOverlayStyle(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: isDark ? const Color(0xFF101713) : Colors.white,
      systemNavigationBarIconBrightness:
          isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
    );
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final type = AppTypography.textTheme(p.text);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.r16),
    );
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.primary,
      onPrimary: p.onPrimary,
      primaryContainer: p.soft,
      onPrimaryContainer: p.onSoft,
      secondary: p.soft,
      onSecondary: p.onSoft,
      secondaryContainer: p.soft,
      onSecondaryContainer: p.onSoft,
      tertiary: p.info,
      onTertiary: p.onPrimary,
      error: p.error,
      onError: p.onPrimary,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.muted,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.soft,
      surfaceContainerHighest: p.disabled,
      surfaceTint: Colors.transparent,
      outline: p.border,
      outlineVariant: p.border,
      inverseSurface: p.text,
      onInverseSurface: p.background,
    );
    ButtonStyle style(Color bg, Color fg, {bool primary = false}) =>
        ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppMetrics.buttonHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(
              horizontal: AppSpacing.s16,
              vertical: AppSpacing.s12,
            ),
          ),
          textStyle: WidgetStatePropertyAll(type.labelLarge),
          elevation: const WidgetStatePropertyAll(AppMetrics.elevation),
          shape: WidgetStatePropertyAll(shape),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? p.disabled
                : primary && states.contains(WidgetState.pressed)
                ? p.pressed
                : bg,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled) ? p.muted : fg,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? p.primary
                  : Colors.transparent,
              width: AppMetrics.focusWidth,
            ),
          ),
        );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
          borderSide: BorderSide(color: color, width: width),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [p],
      textTheme: type,
      cardColor: p.surface,
      scaffoldBackgroundColor: p.background,
      dividerColor: p.border,
      disabledColor: p.muted,
      iconTheme: IconThemeData(color: p.primary, size: AppMetrics.iconSize),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: systemOverlayStyle(brightness),
        titleTextStyle: type.headlineMedium,
        surfaceTintColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: style(p.primary, p.onPrimary, primary: true),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: style(p.primary, p.onPrimary, primary: true),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: style(p.soft, p.onSoft),
      ),
      textButtonTheme: TextButtonThemeData(
        style: style(Colors.transparent, p.primary),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.all(AppSpacing.s16),
        border: border(p.border),
        enabledBorder: border(p.border),
        focusedBorder: border(p.primary, AppMetrics.focusWidth),
        errorBorder: border(p.error),
        focusedErrorBorder: border(p.error, 2),
        disabledBorder: border(p.border),
        labelStyle: type.labelMedium?.copyWith(color: p.text),
        hintStyle: type.bodyMedium?.copyWith(color: p.muted),
        helperStyle: type.bodySmall?.copyWith(color: p.muted),
        errorStyle: type.bodySmall?.copyWith(color: p.error),
        prefixIconColor: p.primary,
        suffixIconColor: p.muted,
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: shape.copyWith(side: BorderSide(color: p.border)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 88,
        backgroundColor: p.surface,
        elevation: 0,
        indicatorColor: p.soft,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => type.bodySmall?.copyWith(
            color: s.contains(WidgetState.selected) ? p.primary : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.primary : p.muted,
            size: 24,
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.primary,
        unselectedLabelColor: p.muted,
        labelStyle: type.bodySmall,
        unselectedLabelStyle: type.bodySmall,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AppRadius.r8),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.soft,
        selectedColor: p.soft,
        disabledColor: p.disabled,
        labelStyle: type.bodySmall?.copyWith(color: p.onSoft),
        side: BorderSide.none,
        padding: const EdgeInsets.all(AppSpacing.s8),
        shape: shape,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        titleTextStyle: type.headlineSmall,
        contentTextStyle: type.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        modalBackgroundColor: p.surface,
        elevation: 0,
        modalElevation: 0,
        showDragHandle: true,
        dragHandleColor: p.border,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.r20),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: p.border,
        thickness: 1,
        space: AppSpacing.s24,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.primary,
        linearTrackColor: p.soft,
        circularTrackColor: p.soft,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.primary : p.border,
        ),
        thumbColor: WidgetStatePropertyAll(p.surface),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.text,
        contentTextStyle: type.bodyMedium?.copyWith(color: p.background),
      ),
    );
  }
}
