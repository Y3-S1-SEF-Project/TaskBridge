import 'package:flutter/foundation.dart';

/// Central reactive event-driven sync service for instant state updates
/// across Customer and Provider views.
///
/// NOTE: Purely event-driven — zero background polling timers to avoid
/// spamming backend database queries or server logs.
class BookingsSyncService extends ChangeNotifier {
  static final BookingsSyncService instance = BookingsSyncService._internal();

  BookingsSyncService._internal();

  /// Immediately notifies all listening pages (Customer Bookings, Provider Jobs, etc.)
  /// whenever an action occurs (Accept, Counter-Bid, Cancel, Status Change).
  void triggerImmediateUpdate() {
    notifyListeners();
  }

  // Deprecated no-ops preserved for clean API compatibility
  void startAutoSync({Duration? interval}) {}
  void stopAutoSync() {}
}
