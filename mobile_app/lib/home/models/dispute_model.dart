class DisputeItem {
  final String id;
  final String disputeReference;
  final String? bookingId;
  final String bookingReference;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final String? providerId;
  final String providerName;
  final String serviceTitle;
  final String category;
  final double feeAmount;
  final String reasonCategory;
  final String description;
  final String desiredResolution;
  final List<String> beforePhotoUrls;
  final List<String> afterPhotoUrls;
  final List<String> customerEvidencePhotoUrls;
  final String status;
  final String? resolutionSummary;
  final String? resolutionAction;
  final String? resolvedByAdminName;
  final DateTime? resolvedAt;
  final DateTime createdAt;

  const DisputeItem({
    required this.id,
    required this.disputeReference,
    this.bookingId,
    required this.bookingReference,
    this.customerId,
    required this.customerName,
    this.customerPhone,
    this.providerId,
    required this.providerName,
    required this.serviceTitle,
    required this.category,
    required this.feeAmount,
    required this.reasonCategory,
    required this.description,
    required this.desiredResolution,
    required this.beforePhotoUrls,
    required this.afterPhotoUrls,
    required this.customerEvidencePhotoUrls,
    required this.status,
    this.resolutionSummary,
    this.resolutionAction,
    this.resolvedByAdminName,
    this.resolvedAt,
    required this.createdAt,
  });

  bool get isResolved =>
      status.toLowerCase() == 'resolved' ||
      status.toLowerCase().startsWith('resolved_');

  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'canceled';

  bool get isPending =>
      !isResolved && !isCancelled;

  String get statusDisplay {
    if (isResolved) return 'Resolved';
    if (isCancelled) return 'Cancelled';
    return 'Under Admin Review';
  }

  factory DisputeItem.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw is List) {
        return raw.map((e) => e.toString()).toList();
      }
      return [];
    }

    return DisputeItem(
      id: json['id']?.toString() ?? '',
      disputeReference: json['disputeReference']?.toString() ?? 'DSP-XXXX',
      bookingId: json['bookingId']?.toString(),
      bookingReference: json['bookingReference']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString() ?? 'Customer',
      customerPhone: json['customerPhone']?.toString(),
      providerId: json['providerId']?.toString(),
      providerName: json['providerName']?.toString() ?? 'Specialist',
      serviceTitle: json['serviceTitle']?.toString() ?? 'Service',
      category: json['category']?.toString() ?? 'General',
      feeAmount: (json['feeAmount'] is num)
          ? (json['feeAmount'] as num).toDouble()
          : 0.0,
      reasonCategory: json['reasonCategory']?.toString() ?? 'General',
      description: json['description']?.toString() ?? '',
      desiredResolution: json['desiredResolution']?.toString() ?? 'Admin Mediation',
      beforePhotoUrls: parseList(json['beforePhotoUrls']),
      afterPhotoUrls: parseList(json['afterPhotoUrls']),
      customerEvidencePhotoUrls: parseList(json['customerEvidencePhotoUrls']),
      status: json['status']?.toString() ?? 'PendingAdminReview',
      resolutionSummary: json['resolutionSummary']?.toString(),
      resolutionAction: json['resolutionAction']?.toString(),
      resolvedByAdminName: json['resolvedByAdminName']?.toString(),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
