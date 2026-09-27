import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:signalr_netcore/signalr_client.dart';
import '../../auth/data/auth_api.dart';
import '../../core/config/api_config.dart';
import '../models/chat_models.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  HubConnection? _hubConnection;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final StreamController<ChatMessageModel> _messageStreamController =
      StreamController<ChatMessageModel>.broadcast();
  Stream<ChatMessageModel> get messageStream => _messageStreamController.stream;

  final StreamController<Map<String, dynamic>> _typingStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get typingStream =>
      _typingStreamController.stream;

  final StreamController<Map<String, dynamic>> _readReceiptStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get readReceiptStream =>
      _readReceiptStreamController.stream;

  final StreamController<Map<String, dynamic>> _deleteMessageStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get deleteMessageStream =>
      _deleteMessageStreamController.stream;

  /// Resolves a working base URL from ApiConfig or candidate URLs dynamically.
  Future<String> _resolveBaseUrl() async {
    if (ApiConfig.hasWorkingBaseUrl) {
      return ApiConfig.baseUrl;
    }

    final candidates = ApiConfig.candidateUrls;
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/providers');
        final res = await http
            .get(uri)
            .timeout(const Duration(milliseconds: 1500));
        if (res.statusCode < 500) {
          ApiConfig.setWorkingBaseUrl(candidate);
          return candidate;
        }
      } catch (_) {}
    }
    return ApiConfig.baseUrl;
  }

  /// Initializes and starts the SignalR WebSocket connection.
  Future<bool> initSignalR() async {
    if (_hubConnection != null &&
        _hubConnection!.state == HubConnectionState.Connected) {
      _isConnected = true;
      return true;
    }

    final token = await AuthApi.getCachedToken();
    if (token == null || token.isEmpty) {
      debugPrint('[ChatService] Cannot connect: No auth token cached.');
      return false;
    }

    try {
      final base = await _resolveBaseUrl();
      final hubUrl = '$base/hubs/chat';
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            hubUrl,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => token,
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.on('ReceiveMessage', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          try {
            final raw = Map<String, dynamic>.from(args[0] as Map);
            final message = ChatMessageModel.fromJson(raw);
            _messageStreamController.add(message);
          } catch (e) {
            debugPrint('[ChatService] Error parsing incoming message: $e');
          }
        }
      });

      _hubConnection!.on('UserTyping', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          _typingStreamController.add(
            Map<String, dynamic>.from(args[0] as Map),
          );
        }
      });

      _hubConnection!.on('MessagesRead', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          _readReceiptStreamController.add(
            Map<String, dynamic>.from(args[0] as Map),
          );
        }
      });

      _hubConnection!.on('MessageDeleted', (args) {
        if (args != null && args.isNotEmpty && args[0] is Map) {
          _deleteMessageStreamController.add(
            Map<String, dynamic>.from(args[0] as Map),
          );
        }
      });

      _hubConnection!.onclose(({error}) {
        _isConnected = false;
        debugPrint('[ChatService] SignalR Connection closed: $error');
      });

      await _hubConnection!.start();
      _isConnected = true;
      debugPrint('[ChatService] SignalR connected successfully to $hubUrl');
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('[ChatService] SignalR connection failed: $e');
      return false;
    }
  }

  /// Joins a conversation room for instant group delivery.
  Future<void> joinConversation(String conversationId) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection!.invoke('JoinConversation', args: [conversationId]);
    }
  }

  /// Leaves a conversation room.
  Future<void> leaveConversation(String conversationId) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      await _hubConnection!.invoke('LeaveConversation', args: [conversationId]);
    }
  }

  /// Sends a text message or image attachment over SignalR.
  Future<bool> sendMessage({
    required String conversationId,
    required String recipientId,
    required String content,
    String? mediaUrl,
    String messageType = 'Text',
  }) async {
    if (_hubConnection?.state != HubConnectionState.Connected) {
      await initSignalR();
    }

    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke(
          'SendMessage',
          args: [
            conversationId,
            recipientId,
            content,
            mediaUrl ?? '',
            messageType,
          ],
        );
        return true;
      } catch (e) {
        debugPrint('[ChatService] SendMessage error: $e');
      }
    }
    return false;
  }

  /// Notifies the recipient that this user is currently typing.
  Future<void> sendTyping(
    String conversationId,
    String recipientId,
    bool isTyping,
  ) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke(
          'SendTyping',
          args: [conversationId, recipientId, isTyping],
        );
      } catch (_) {}
    }
  }

  /// Marks a conversation as read.
  Future<void> markAsRead(String conversationId) async {
    if (_hubConnection?.state == HubConnectionState.Connected) {
      try {
        await _hubConnection!.invoke('MarkAsRead', args: [conversationId]);
      } catch (_) {}
    }
  }

  /// Deletes a message over SignalR for instant synchronization and REST API.
  Future<bool> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    try {
      if (_hubConnection?.state == HubConnectionState.Connected) {
        await _hubConnection!.invoke(
          'DeleteMessage',
          args: [conversationId, messageId],
        );
      }

      final headers = await _authHeaders();
      final base = await _resolveBaseUrl();
      final uri = Uri.parse('$base/api/chat/messages/$messageId');
      final res = await http
          .delete(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      return res.statusCode == 200;
    } catch (e) {
      debugPrint('[ChatService] deleteMessage error: $e');
      return false;
    }
  }

  // ────────────────────────────────────────────────────────────────
  // REST API Helpers
  // ────────────────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await AuthApi.getCachedToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Fetches all active conversations for the current user.
  Future<List<ChatConversationModel>> fetchConversations() async {
    try {
      final headers = await _authHeaders();
      final base = await _resolveBaseUrl();
      final uri = Uri.parse('$base/api/chat/conversations');
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list
            .map(
              (item) =>
                  ChatConversationModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('[ChatService] fetchConversations error: $e');
    }
    return [];
  }

  /// Finds an existing conversation or creates a new one between customer & provider.
  Future<ChatConversationModel?> findOrCreateConversation({
    required String providerId,
    String? customerId,
    String? bookingReference,
  }) async {
    try {
      final headers = await _authHeaders();
      final base = await _resolveBaseUrl();
      final uri = Uri.parse('$base/api/chat/conversations/find-or-create');
      final body = jsonEncode({
        'providerId': providerId,
        ...?customerId != null ? {'customerId': customerId} : null,
        ...?bookingReference != null
            ? {'bookingReference': bookingReference}
            : null,
      });

      final res = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        return ChatConversationModel.fromJson(jsonDecode(res.body));
      } else {
        debugPrint(
          '[ChatService] findOrCreateConversation HTTP ${res.statusCode}: ${res.body}',
        );
      }
    } catch (e) {
      debugPrint('[ChatService] findOrCreateConversation error: $e');
    }
    return null;
  }

  /// Fetches messages for a conversation (server decrypts at-rest content).
  Future<List<ChatMessageModel>> fetchMessages(String conversationId) async {
    try {
      final headers = await _authHeaders();
      final base = await _resolveBaseUrl();
      final uri = Uri.parse(
        '$base/api/chat/conversations/$conversationId/messages?limit=100',
      );
      final res = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        return list
            .map(
              (item) => ChatMessageModel.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('[ChatService] fetchMessages error: $e');
    }
    return [];
  }

  /// Uploads an image attachment to Cloudflare R2 / S3 via the backend API.
  Future<String?> uploadAttachment(XFile file, {String? bookingRef}) async {
    try {
      final token = await AuthApi.getCachedToken();
      final base = await _resolveBaseUrl();
      final uri = Uri.parse('$base/api/chat/upload-attachment');
      final request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      if (bookingRef != null) {
        request.fields['bookingRef'] = bookingRef;
      }

      final bytes = await file.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: file.name.isNotEmpty ? file.name : 'chat_image.jpg',
      );
      request.files.add(multipartFile);

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        debugPrint(
          '[ChatService] uploadAttachment failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[ChatService] uploadAttachment error: $e');
    }
    return null;
  }

  void dispose() {
    _hubConnection?.stop();
    _messageStreamController.close();
    _typingStreamController.close();
  }
}
