import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Inter styles extracted from TaskBridge Figma (size / line height / weight).
/// Google Fonts retrieves Inter at runtime on first use; no offline font assets
/// are bundled by this source-only change.
abstract final class AppTypography {
  static const display = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const h1 = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
  static const h2 = TextStyle(
    fontSize: 22,
    height: 30 / 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const h3 = TextStyle(
    fontSize: 18,
    height: 26 / 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const bodySmall = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 18 / 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
  static const label = TextStyle(
    fontSize: 13,
    height: 20 / 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static const button = TextStyle(
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
  static TextTheme textTheme(Color foreground) => GoogleFonts.interTextTheme(
    TextTheme(
      displayLarge: display,
      displayMedium: display,
      displaySmall: display,
      headlineLarge: h1,
      headlineMedium: h2,
      headlineSmall: h3,
      titleLarge: h3,
      titleMedium: label,
      titleSmall: label,
      bodyLarge: body,
      bodyMedium: bodySmall,
      bodySmall: caption,
      labelLarge: button,
      labelMedium: label,
      labelSmall: caption,
    ).apply(bodyColor: foreground, displayColor: foreground),
  );
}
