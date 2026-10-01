import 'dart:developer' as developer;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationsService {
  static final LocalNotificationsService _instance = LocalNotificationsService._internal();
  factory LocalNotificationsService() => _instance;
  LocalNotificationsService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  static const String _channelId = 'taskbridge_notifications_channel';
  static const String _channelName = 'TaskBridge Alerts';
  static const String _channelDesc = 'Real-time notifications for bookings, proposals, and task updates.';

  /// Callback when user taps a system notification from the drawer or lock-screen
  static void Function(String? payload)? onNotificationTapped;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
        defaultPresentAlert: true,
        defaultPresentSound: true,
        defaultPresentBadge: true,
        defaultPresentBanner: true,
        defaultPresentList: true,
      );

      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iosInit,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          developer.log('🔔 [LocalNotifications] Notification tapped with payload: ${response.payload}');
          onNotificationTapped?.call(response.payload);
        },
      );

      // Create high-importance Android Notification Channel
      final androidImplementation = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        const channel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        );
        await androidImplementation.createNotificationChannel(channel);
      }

      _isInitialized = true;
      developer.log('✅ [LocalNotificationsService] Initialized channels successfully');
    } catch (e) {
      developer.log('⚠️ [LocalNotificationsService] Initialization failed: $e');
    }
  }

  /// Explicitly requests notification permissions on Android 13+ and iOS.
  /// Called when the user has signed in/registered and reaches the home screen.
  Future<void> requestPermissions() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.requestNotificationsPermission();
      }

      final ios = _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        developer.log('📲 [LocalNotificationsService] iOS notifications permission granted: $granted');
      }
      developer.log('📲 [LocalNotificationsService] Requested notifications permission');
    } catch (e) {
      developer.log('⚠️ [LocalNotificationsService] Failed requesting permission: $e');
    }
  }

  /// Displays a heads-up system push notification in the phone's notification bar
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'TaskBridge Alert',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.active,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: details,
        payload: payload,
      );

      developer.log('📲 [LocalNotifications] Displayed system notification: $title');
    } catch (e) {
      developer.log('⚠️ [LocalNotifications] Failed to display notification: $e');
    }
  }
}
