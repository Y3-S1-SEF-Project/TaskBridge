class ChatConversationModel {
  final String id;
  final String? bookingReference;
  final String customerId;
  final String customerName;
  final String providerId;
  final String providerName;
  final DateTime lastMessageAt;
  final String? lastMessageSnippet;
  final int unreadCount;
  final DateTime createdAt;

  ChatConversationModel({
    required this.id,
    this.bookingReference,
    required this.customerId,
    required this.customerName,
    required this.providerId,
    required this.providerName,
    required this.lastMessageAt,
    this.lastMessageSnippet,
    this.unreadCount = 0,
    required this.createdAt,
  });

  factory ChatConversationModel.fromJson(Map<String, dynamic> json) {
    return ChatConversationModel(
      id: json['id']?.toString() ?? '',
      bookingReference: json['bookingReference']?.toString(),
      customerId: json['customerId']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Customer',
      providerId: json['providerId']?.toString() ?? '',
      providerName: json['providerName']?.toString() ?? 'Provider',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ?? DateTime.now(),
      lastMessageSnippet: json['lastMessageSnippet']?.toString(),
      unreadCount: json['unreadCount'] is int ? json['unreadCount'] : 0,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  String otherPartyName(String currentUserId) {
    return currentUserId == customerId ? providerName : customerName;
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String messageType; // "Text" or "Image"
  final String content;
  final String? mediaUrl;
  final bool isRead;
  final DateTime createdAt;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.messageType,
    required this.content,
    this.mediaUrl,
    this.isRead = false,
    required this.createdAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? '',
      recipientId: json['recipientId']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'Text',
      content: json['content']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  bool isSender(String currentUserId) => senderId == currentUserId;
  bool get isImage => messageType.toUpperCase() == 'IMAGE' || (mediaUrl != null && mediaUrl!.isNotEmpty);

  ChatMessageModel copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? senderName,
    String? recipientId,
    String? messageType,
    String? content,
    String? mediaUrl,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      recipientId: recipientId ?? this.recipientId,
      messageType: messageType ?? this.messageType,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
