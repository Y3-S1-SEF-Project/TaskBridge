class ProviderQuotation {
  final String providerId;
  final String fullName;
  final String category;
  final String? profilePhotoUrl;
  final String phone;
  final double quotedPrice;
  final String availableTime;
  final double distanceKm;
  final double rating;
  final int reviewCount;
  final String notes;
  final int matchScore;
  final bool isRecommended;

  const ProviderQuotation({
    required this.providerId,
    required this.fullName,
    required this.category,
    this.profilePhotoUrl,
    required this.phone,
    required this.quotedPrice,
    required this.availableTime,
    required this.distanceKm,
    required this.rating,
    required this.reviewCount,
    required this.notes,
    this.matchScore = 90,
    this.isRecommended = false,
  });

  factory ProviderQuotation.fromJson(Map<String, dynamic> json) {
    return ProviderQuotation(
      providerId: json['providerId'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'Specialist',
      category: json['category'] as String? ?? 'General',
      profilePhotoUrl: json['profilePhotoUrl'] as String?,
      phone: json['phone'] as String? ?? '',
      quotedPrice: (json['quotedPrice'] as num?)?.toDouble() ?? 4500.0,
      availableTime: json['availableTime'] as String? ?? 'Tomorrow at 4:00 PM',
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 2.4,
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      reviewCount: json['reviewCount'] as int? ?? 12,
      notes: json['notes'] as String? ?? '',
      matchScore: json['matchScore'] as int? ?? 90,
      isRecommended: json['isRecommended'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'providerId': providerId,
    'fullName': fullName,
    'category': category,
    'profilePhotoUrl': profilePhotoUrl,
    'phone': phone,
    'quotedPrice': quotedPrice,
    'availableTime': availableTime,
    'distanceKm': distanceKm,
    'rating': rating,
    'reviewCount': reviewCount,
    'notes': notes,
    'matchScore': matchScore,
    'isRecommended': isRecommended,
  };
}

class BookingDetails {
  final String bookingReference;
  final String serviceTitle;
  final String providerName;
  final String? customerId;
  final String customerName;
  final String location;
  final String schedule;
  final double price;
  final String priceFormatted;
  final String? notes;
  final String status;

  const BookingDetails({
    required this.bookingReference,
    required this.serviceTitle,
    required this.providerName,
    this.customerId,
    required this.customerName,
    required this.location,
    required this.schedule,
    required this.price,
    required this.priceFormatted,
    this.notes,
    this.status = 'Upcoming',
  });

  factory BookingDetails.fromJson(Map<String, dynamic> json) {
    return BookingDetails(
      bookingReference: json['bookingReference'] as String? ?? 'TB-1042',
      serviceTitle: json['serviceTitle'] as String? ?? 'Service Request',
      providerName: json['providerName'] as String? ?? 'Specialist',
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String? ?? 'Customer',
      location: json['location'] as String? ?? 'Colombo 05',
      schedule: json['schedule'] as String? ?? '17 Sep · 4:00 PM · Colombo 05',
      price: (json['price'] as num?)?.toDouble() ?? 4500.0,
      priceFormatted: json['priceFormatted'] as String? ?? 'Rs. 4,500',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'Upcoming',
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingReference': bookingReference,
    'serviceTitle': serviceTitle,
    'providerName': providerName,
    if (customerId != null) 'customerId': customerId,
    'customerName': customerName,
    'location': location,
    'schedule': schedule,
    'price': price,
    'priceFormatted': priceFormatted,
    if (notes != null) 'notes': notes,
    'status': status,
  };
}

class BookingProposalResponse {
  final bool success;
  final String recommendedProviderId;
  final String recommendedProviderName;
  final String recommendationReason;
  final ProviderQuotation winningQuotation;
  final List<ProviderQuotation> allQuotations;
  final BookingDetails bookingProposal;
  final String model;
  final int latencyMs;

  const BookingProposalResponse({
    required this.success,
    required this.recommendedProviderId,
    required this.recommendedProviderName,
    required this.recommendationReason,
    required this.winningQuotation,
    required this.allQuotations,
    required this.bookingProposal,
    required this.model,
    required this.latencyMs,
  });

  factory BookingProposalResponse.fromJson(Map<String, dynamic> json) {
    final rawQuotes = json['allQuotations'] as List<dynamic>? ?? [];
    final quotes = rawQuotes
        .map((q) => ProviderQuotation.fromJson(q as Map<String, dynamic>))
        .toList();

    return BookingProposalResponse(
      success: json['success'] as bool? ?? true,
      recommendedProviderId: json['recommendedProviderId'] as String? ?? '',
      recommendedProviderName: json['recommendedProviderName'] as String? ?? '',
      recommendationReason: json['recommendationReason'] as String? ?? '',
      winningQuotation: ProviderQuotation.fromJson(
        json['winningQuotation'] as Map<String, dynamic>? ?? {},
      ),
      allQuotations: quotes,
      bookingProposal: BookingDetails.fromJson(
        json['bookingProposal'] as Map<String, dynamic>? ?? {},
      ),
      model: json['model'] as String? ?? 'gpt-4o-mini',
      latencyMs: json['latencyMs'] as int? ?? 0,
    );
  }
}

class BookingItem {
  final String id;
  final String bookingReference;
  final String serviceTitle;
  final String category;
  final String providerName;
  final String? providerId;
  final String customerName;
  final String location;
  final String schedule;
  final double price;
  final String rateType;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const BookingItem({
    required this.id,
    required this.bookingReference,
    required this.serviceTitle,
    required this.category,
    required this.providerName,
    this.providerId,
    required this.customerName,
    required this.location,
    required this.schedule,
    required this.price,
    this.rateType = 'Hourly',
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory BookingItem.fromJson(Map<String, dynamic> json) {
    return BookingItem(
      id: json['id']?.toString() ?? '',
      bookingReference: json['bookingReference'] as String? ?? 'TB-1042',
      serviceTitle: json['serviceTitle'] as String? ?? 'Home Service',
      category: json['category'] as String? ?? 'General',
      providerName: json['providerName'] as String? ?? 'Specialist',
      providerId: json['providerId']?.toString(),
      customerName: json['customerName'] as String? ?? 'Customer',
      location: json['location'] as String? ?? 'Colombo',
      schedule: json['schedule'] as String? ?? '17 Sep · 4:00 PM · Colombo 05',
      price: (json['price'] as num?)?.toDouble() ?? 4500.0,
      rateType: json['rateType'] as String? ?? 'Hourly',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'Upcoming',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isHourly => rateType.toLowerCase() == 'hourly';
  String get priceFormatted =>
      isHourly ? 'Rs. ${price.toInt()}/hr' : 'Rs. ${price.toInt()}';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'canceled' ||
      status.toLowerCase() == 'declined' ||
      status.toLowerCase() == 'rejected';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isProviderCountered =>
      !isCancelled &&
      (status.toLowerCase() == 'providercountered' ||
          status.toLowerCase() == 'counterbidreceived');
  bool get isCustomerCountered =>
      !isCancelled && status.toLowerCase() == 'customercountered';
  bool get isRequested =>
      !isCancelled &&
      !isCompleted &&
      (status.toLowerCase() == 'requested' ||
          status.toLowerCase() == 'pending' ||
          status.toLowerCase() == 'quotationpending' ||
          isProviderCountered ||
          isCustomerCountered);
  bool get isUpcoming => !isCancelled && status.toLowerCase() == 'upcoming';
  bool get isActive =>
      !isCancelled &&
      (status.toLowerCase() == 'active' ||
          status.toLowerCase() == 'in progress');
  bool get isPendingSignOff =>
      status.toLowerCase() == 'pendingcustomersignoff';
  bool get isRevisionRequested =>
      status.toLowerCase() == 'revisionrequested';
  bool get isOngoing =>
      (isRequested || isActive || isPendingSignOff || isRevisionRequested) &&
      !isCancelled &&
      !isCompleted;

  BookingItem copyWith({
    String? status,
    String? rateType,
    double? price,
    String? schedule,
    String? notes,
  }) {
    return BookingItem(
      id: id,
      bookingReference: bookingReference,
      serviceTitle: serviceTitle,
      category: category,
      providerName: providerName,
      providerId: providerId,
      customerName: customerName,
      location: location,
      schedule: schedule ?? this.schedule,
      price: price ?? this.price,
      rateType: rateType ?? this.rateType,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class ProposalItem {
  final String id;
  final String proposalReference;
  final String serviceTitle;
  final String category;
  final String providerName;
  final String? providerId;
  final String customerName;
  final String location;
  final String preferredSchedule;
  final double estimatedRate;
  final String rateType;
  final String? notes;
  final String status;
  final DateTime createdAt;

  const ProposalItem({
    required this.id,
    required this.proposalReference,
    required this.serviceTitle,
    required this.category,
    required this.providerName,
    this.providerId,
    required this.customerName,
    required this.location,
    required this.preferredSchedule,
    required this.estimatedRate,
    this.rateType = 'Hourly',
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory ProposalItem.fromJson(Map<String, dynamic> json) {
    return ProposalItem(
      id: json['id']?.toString() ?? '',
      proposalReference: json['proposalReference'] as String? ?? 'PR-1026',
      serviceTitle: json['serviceTitle'] as String? ?? 'Home Service',
      category: json['category'] as String? ?? 'General',
      providerName: json['providerName'] as String? ?? 'Specialist',
      providerId: json['providerId']?.toString(),
      customerName: json['customerName'] as String? ?? 'Customer',
      location: json['location'] as String? ?? 'Colombo',
      preferredSchedule: json['preferredSchedule'] as String? ?? '',
      estimatedRate: (json['estimatedRate'] as num?)?.toDouble() ?? 3500.0,
      rateType: json['rateType'] as String? ?? 'Hourly',
      notes: json['notes'] as String?,
      status: json['status'] as String? ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  bool get isHourly => rateType.toLowerCase() == 'hourly';
  String get priceFormatted => isHourly
      ? 'Rs. ${estimatedRate.toInt()}/hr'
      : 'Rs. ${estimatedRate.toInt()}';
  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' ||
      status.toLowerCase() == 'canceled' ||
      status.toLowerCase() == 'declined' ||
      status.toLowerCase() == 'rejected';
  bool get isDeclined => status.toLowerCase() == 'declined';
  bool get isRequested =>
      !isCancelled &&
      (status.toLowerCase() == 'pending' ||
          status.toLowerCase() == 'requested' ||
          status.toLowerCase() == 'quotationpending' ||
          status.toLowerCase() == 'providercountered' ||
          status.toLowerCase() == 'counterbidreceived' ||
          status.toLowerCase() == 'customercountered');

  ProposalItem copyWith({
    String? status,
    String? rateType,
    double? estimatedRate,
    String? preferredSchedule,
    String? notes,
  }) {
    return ProposalItem(
      id: id,
      proposalReference: proposalReference,
      serviceTitle: serviceTitle,
      category: category,
      providerName: providerName,
      providerId: providerId,
      customerName: customerName,
      location: location,
      preferredSchedule: preferredSchedule ?? this.preferredSchedule,
      estimatedRate: estimatedRate ?? this.estimatedRate,
      rateType: rateType ?? this.rateType,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }

  BookingItem toBookingItem() {
    return BookingItem(
      id: id,
      bookingReference: proposalReference,
      serviceTitle: serviceTitle,
      category: category,
      providerName: providerName,
      providerId: providerId,
      customerName: customerName,
      location: location,
      schedule: preferredSchedule,
      price: estimatedRate,
      rateType: rateType,
      notes: notes,
      status: status,
      createdAt: createdAt,
    );
  }
}
