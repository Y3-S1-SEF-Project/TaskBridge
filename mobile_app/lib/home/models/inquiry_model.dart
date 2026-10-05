class InquiryModel {
  final String id;
  final String inquiryReference;
  final String? userId;
  final String userName;
  final String? userEmail;
  final String? userPhone;
  final String userRole;
  final String subject;
  final String category;
  final String message;
  final List<String> attachmentUrls;
  final String priority;
  final String status;
  final String? adminResponse;
  final String? respondedByAdminName;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const InquiryModel({
    required this.id,
    required this.inquiryReference,
    this.userId,
    required this.userName,
    this.userEmail,
    this.userPhone,
    required this.userRole,
    required this.subject,
    required this.category,
    required this.message,
    required this.attachmentUrls,
    required this.priority,
    required this.status,
    this.adminResponse,
    this.respondedByAdminName,
    this.respondedAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isOpen => status.toLowerCase() == 'open';
  bool get isInProgress => status.toLowerCase() == 'inprogress';
  bool get isResponded => status.toLowerCase() == 'responded';
  bool get isResolved => status.toLowerCase() == 'resolved';

  String get statusDisplay {
    switch (status.toLowerCase()) {
      case 'open':
        return 'Pending Response';
      case 'inprogress':
        return 'In Review';
      case 'responded':
        return 'Admin Responded';
      case 'resolved':
        return 'Resolved';
      default:
        return status;
    }
  }

  factory InquiryModel.fromJson(Map<String, dynamic> json) {
    List<String> attachments = [];
    if (json['attachmentUrls'] is List) {
      attachments = (json['attachmentUrls'] as List)
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return InquiryModel(
      id: json['id']?.toString() ?? '',
      inquiryReference: json['inquiryReference'] as String? ?? 'INQ-1000',
      userId: json['userId']?.toString(),
      userName: json['userName'] as String? ?? 'User',
      userEmail: json['userEmail'] as String?,
      userPhone: json['userPhone'] as String?,
      userRole: json['userRole'] as String? ?? 'Customer',
      subject: json['subject'] as String? ?? 'System Issue',
      category: json['category'] as String? ?? 'General',
      message: json['message'] as String? ?? '',
      attachmentUrls: attachments,
      priority: json['priority'] as String? ?? 'Normal',
      status: json['status'] as String? ?? 'Open',
      adminResponse: json['adminResponse'] as String?,
      respondedByAdminName: json['respondedByAdminName'] as String?,
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'inquiryReference': inquiryReference,
    'userId': userId,
    'userName': userName,
    'userEmail': userEmail,
    'userPhone': userPhone,
    'userRole': userRole,
    'subject': subject,
    'category': category,
    'message': message,
    'attachmentUrls': attachmentUrls,
    'priority': priority,
    'status': status,
    'adminResponse': adminResponse,
    'respondedByAdminName': respondedByAdminName,
    'respondedAt': respondedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };
}
