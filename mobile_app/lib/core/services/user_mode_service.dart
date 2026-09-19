import 'package:shared_preferences/shared_preferences.dart';

enum UserMode {
  customer,
  provider,
}

class UserModeService {
  static const String _keyUserMode = 'taskbridge_active_user_mode';

  /// Gets the persisted active mode, defaulting to customer if not set.
  static Future<UserMode> getMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final modeStr = prefs.getString(_keyUserMode);
      if (modeStr == 'provider') {
        return UserMode.provider;
      }
      return UserMode.customer;
    } catch (_) {
      return UserMode.customer;
    }
  }

  /// Persists the active user mode ('customer' or 'provider').
  static Future<void> setMode(UserMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyUserMode,
        mode == UserMode.provider ? 'provider' : 'customer',
      );
    } catch (_) {}
  }
}
