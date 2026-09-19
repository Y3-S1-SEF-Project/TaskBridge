import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const String _keyThemeMode = 'taskbridge_theme_mode';

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  /// Initializes the service from SharedPreferences.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyThemeMode);
      if (modeStr == 'dark') {
        themeModeNotifier.value = ThemeMode.dark;
      } else if (modeStr == 'light') {
        themeModeNotifier.value = ThemeMode.light;
      } else if (modeStr == 'system') {
        themeModeNotifier.value = ThemeMode.system;
      } else {
        // Default to light for clean first-time experience
        themeModeNotifier.value = ThemeMode.light;
      }
    } catch (_) {
      themeModeNotifier.value = ThemeMode.light;
    }
  }

  /// Current active ThemeMode.
  ThemeMode get themeMode => themeModeNotifier.value;

  /// Returns whether dark mode is active for the current context.
  bool isDarkMode(BuildContext context) {
    if (themeMode == ThemeMode.dark) return true;
    if (themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Sets and persists the theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String modeStr;
      switch (mode) {
        case ThemeMode.dark:
          modeStr = 'dark';
          break;
        case ThemeMode.light:
          modeStr = 'light';
          break;
        case ThemeMode.system:
          modeStr = 'system';
          break;
      }
      await prefs.setString(_keyThemeMode, modeStr);
    } catch (_) {}
  }

  /// Toggles between light and dark mode.
  Future<void> toggleTheme(BuildContext context) async {
    final currentIsDark = isDarkMode(context);
    await setThemeMode(currentIsDark ? ThemeMode.light : ThemeMode.dark);
  }
}
