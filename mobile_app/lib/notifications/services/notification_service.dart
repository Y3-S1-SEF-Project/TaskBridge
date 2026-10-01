import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:signalr_netcore/signalr_client.dart';
import '../../auth/data/auth_api.dart';
import '../../auth/data/auth_models.dart';
import '../../core/config/api_config.dart';
import '../models/notification_model.dart';
import 'local_notifications_service.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  HubConnection? _hubConnection;
  bool _isConnecting = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentRole;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;

  List<NotificationModel> get notifications => List.unmodifiable(_notifications);
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void _safeNotifyListeners() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Hook for showing in-app floating banner when a notification arrives while the app is active
  static void Function(NotificationModel notification)? onInAppNotificationReceived;

  static String? _workingBaseUrl;
  static List<String> get _candidateUrls {
    if (_workingBaseUrl != null) return [_workingBaseUrl!];
    return ApiConfig.candidateUrls;
  }

  static Future<Map<String, String>> _authHeaders() async {
    final token = await AuthApi.getCachedToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Initializes both local notification channels and real-time SignalR connection.
  /// If [requestPermissions] is true, prompts the user for notification permissions
  /// (used after user has signed in/registered and reaches the home screen).
  Future<void> initialize({
    AuthUser? user,
    String? role,
    bool requestPermissions = false,
  }) async {
    await LocalNotificationsService().initialize();
    if (requestPermissions) {
      await LocalNotificationsService().requestPermissions();
    }

    if (user != null) {
      _currentUserId = user.id;
      _currentUserName = user.fullName;
      _currentRole = role ?? (user.isProvider ? 'provider' : 'customer');
    } else {
      final cached = await AuthApi.getCachedUser();
      if (cached != null) {
        _currentUserId = cached.id;
        _currentUserName = cached.fullName;
        _currentRole = role ?? (cached.isProvider ? 'provider' : 'customer');
      }
    }

    await connectSignalR();
    await fetchNotifications();
  }

  /// Connects to the backend SignalR NotificationHub
  Future<void> connectSignalR() async {
    if (_hubConnection != null && _hubConnection!.state == HubConnectionState.Connected) {
      return;
    }
    if (_isConnecting) return;
    _isConnecting = true;

    for (final base in _candidateUrls) {
      final hubUrl = '$base/hubs/notifications';
      try {
        final token = await AuthApi.getCachedToken();
        final options = HttpConnectionOptions(
          accessTokenFactory: () async => token ?? '',
        );

        _hubConnection = HubConnectionBuilder()
            .withUrl(hubUrl, options: options)
            .withAutomaticReconnect()
            .build();

        _hubConnection!.onclose(({error}) {
          developer.log('⚠️ [NotificationSignalR] Disconnected: $error');
          _scheduleReconnect();
        });

        _hubConnection!.onreconnecting(({error}) {
          developer.log('🔄 [NotificationSignalR] Reconnecting: $error');
        });

        _hubConnection!.onreconnected(({connectionId}) {
          developer.log('✅ [NotificationSignalR] Reconnected. ConnId: $connectionId');
          _registerChannels();
        });

        // Listen for real-time notifications dispatched from backend controllers
        _hubConnection!.on('ReceiveNotification', _handleIncomingNotification);

        await _hubConnection!.start();
        _workingBaseUrl = base;
        developer.log('✅ [NotificationSignalR] Connected to $hubUrl');
        await _registerChannels();
        _isConnecting = false;
        return;
      } catch (e) {
        developer.log('⚠️ [NotificationSignalR] Failed on $hubUrl: $e');
      }
    }

    _isConnecting = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 8), () {
      if (_hubConnection == null || _hubConnection!.state != HubConnectionState.Connected) {
        connectSignalR();
      }
    });
  }

  Future<void> _registerChannels() async {
    if (_hubConnection == null || _hubConnection!.state != HubConnectionState.Connected) return;

    try {
      await _hubConnection!.invoke('RegisterChannel', args: [
        _currentUserId ?? '',
        _currentUserName ?? '',
        _currentRole ?? 'customer',
      ]);
      developer.log('🔔 [NotificationSignalR] Registered channel for user: $_currentUserName ($_currentRole)');
    } catch (e) {
      developer.log('⚠️ [NotificationSignalR] RegisterChannel failed: $e');
    }
  }

  void _handleIncomingNotification(List<dynamic>? arguments) {
    if (arguments == null || arguments.isEmpty) return;

    try {
      final raw = arguments[0];
      final Map<String, dynamic> json = raw is Map<String, dynamic>
          ? raw
          : jsonDecode(raw.toString());

      final notif = NotificationModel.fromJson(json);

      // Prepend to in-memory notification feed
      _notifications.insert(0, notif);
      _unreadCount++;
      _safeNotifyListeners();

      // Trigger native Phone Notification (Drawer / Lock-screen with sound & vibration)
      final notifId = notif.id.hashCode & 0x7FFFFFFF;
      LocalNotificationsService().showNotification(
        id: notifId,
        title: notif.title,
        body: notif.message,
        payload: jsonEncode({
          'type': notif.type,
          'referenceId': notif.referenceId,
          'referenceType': notif.referenceType,
        }),
      );

      // Trigger In-App Floating Alert
      onInAppNotificationReceived?.call(notif);
    } catch (e) {
      developer.log('⚠️ [NotificationService] Error parsing incoming notification: $e');
    }
  }

  /// REST: Fetch notifications list from PostgreSQL
  Future<List<NotificationModel>> fetchNotifications({bool unreadOnly = false}) async {
    _isLoading = true;
    _safeNotifyListeners();

    final headers = await _authHeaders();
    final queryParams = <String, String>{};
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      queryParams['userId'] = _currentUserId!;
    }
    if (_currentUserName != null && _currentUserName!.isNotEmpty) {
      queryParams['userName'] = _currentUserName!;
    }
    if (unreadOnly) {
      queryParams['unreadOnly'] = 'true';
    }

    final query = queryParams.isNotEmpty
        ? '?${Uri(queryParameters: queryParams).query}'
        : '';

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/notifications$query');
      try {
        final res = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          final List list = jsonDecode(res.body);
          _notifications = list
              .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
              .toList();
          _unreadCount = _notifications.where((n) => !n.isRead).length;
          _isLoading = false;
          _safeNotifyListeners();
          return _notifications;
        }
      } catch (e) {
        developer.log('⚠️ [NotificationService] fetchNotifications failed on $base: $e');
      }
    }

    _isLoading = false;
    _safeNotifyListeners();
    return _notifications;
  }

  /// REST: Mark a notification as read
  Future<bool> markAsRead(String id) async {
    final headers = await _authHeaders();
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index] = _notifications[index].copyWith(isRead: true);
      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      _safeNotifyListeners();
    }

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/notifications/$id/read');
      try {
        final res = await http.put(uri, headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// REST: Mark all notifications as read
  Future<bool> markAllAsRead() async {
    final headers = await _authHeaders();
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
    _unreadCount = 0;
    _safeNotifyListeners();

    final queryParams = <String, String>{};
    if (_currentUserId != null) queryParams['userId'] = _currentUserId!;
    if (_currentUserName != null) queryParams['userName'] = _currentUserName!;
    final query = queryParams.isNotEmpty ? '?${Uri(queryParameters: queryParams).query}' : '';

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/notifications/mark-all-read$query');
      try {
        final res = await http.put(uri, headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// REST: Delete a notification
  Future<bool> deleteNotification(String id) async {
    final headers = await _authHeaders();
    _notifications.removeWhere((n) => n.id == id);
    _unreadCount = _notifications.where((n) => !n.isRead).length;
    _safeNotifyListeners();

    for (final base in _candidateUrls) {
      final uri = Uri.parse('$base/api/notifications/$id');
      try {
        final res = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          _workingBaseUrl = base;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  @override
  void dispose() {
    _hubConnection?.stop();
    super.dispose();
  }
}
