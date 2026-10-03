import 'package:flutter/material.dart';

class NotificationModel {
  final String id;
  final String? userId;
  final String? userName;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final String? referenceType;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    this.userId,
    this.userName,
    required this.title,
    required this.message,
    required this.type,
    this.referenceId,
    this.referenceType,
    this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? title,
    String? message,
    String? type,
    String? referenceId,
    String? referenceType,
    Map<String, dynamic>? metadata,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      referenceType: referenceType ?? this.referenceType,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['userId']?.toString(),
      userName: json['userName']?.toString(),
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      type: json['type']?.toString() ?? 'General',
      referenceId: json['referenceId']?.toString(),
      referenceType: json['referenceType']?.toString(),
      metadata: json['metadata'] is Map<String, dynamic>
          ? json['metadata'] as Map<String, dynamic>
          : null,
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'title': title,
    'message': message,
    'type': type,
    'referenceId': referenceId,
    'referenceType': referenceType,
    'metadata': metadata,
    'isRead': isRead,
    'createdAt': createdAt.toIso8601String(),
  };

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  IconData get iconData {
    switch (type) {
      case 'ProposalReceived':
        return Icons.mark_email_unread_rounded;
      case 'ProposalAccepted':
        return Icons.check_circle_rounded;
      case 'ProposalDeclined':
        return Icons.cancel_outlined;
      case 'CounterBid':
        return Icons.monetization_on_rounded;
      case 'JobStarted':
        return Icons.play_circle_filled_rounded;
      case 'JobCompleted':
        return Icons.task_alt_rounded;
      case 'BookingCancelled':
        return Icons.highlight_off_rounded;
      case 'PaymentReceived':
        return Icons.account_balance_wallet_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'ProposalAccepted':
      case 'JobCompleted':
      case 'PaymentReceived':
        return const Color(0xFF10B981); // Emerald Green
      case 'ProposalReceived':
      case 'CounterBid':
        return const Color(0xFF3B82F6); // Blue
      case 'JobStarted':
        return const Color(0xFF8B5CF6); // Purple
      case 'ProposalDeclined':
      case 'BookingCancelled':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF0F766E); // Teal
    }
  }
}
