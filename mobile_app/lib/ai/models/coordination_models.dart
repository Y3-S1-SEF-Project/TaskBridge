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
  final String customerName;
  final String location;
  final String schedule;
  final double price;
  final String priceFormatted;
  final String status;

  const BookingDetails({
    required this.bookingReference,
    required this.serviceTitle,
    required this.providerName,
    required this.customerName,
    required this.location,
    required this.schedule,
    required this.price,
    required this.priceFormatted,
    this.status = 'Upcoming',
  });

  factory BookingDetails.fromJson(Map<String, dynamic> json) {
    return BookingDetails(
      bookingReference: json['bookingReference'] as String? ?? 'TB-1042',
      serviceTitle: json['serviceTitle'] as String? ?? 'Service Request',
      providerName: json['providerName'] as String? ?? 'Specialist',
      customerName: json['customerName'] as String? ?? 'Customer',
      location: json['location'] as String? ?? 'Colombo 05',
      schedule: json['schedule'] as String? ?? '17 Sep · 4:00 PM · Colombo 05',
      price: (json['price'] as num?)?.toDouble() ?? 4500.0,
      priceFormatted: json['priceFormatted'] as String? ?? 'Rs. 4,500',
      status: json['status'] as String? ?? 'Upcoming',
    );
  }

  Map<String, dynamic> toJson() => {
    'bookingReference': bookingReference,
    'serviceTitle': serviceTitle,
    'providerName': providerName,
    'customerName': customerName,
    'location': location,
    'schedule': schedule,
    'price': price,
    'priceFormatted': priceFormatted,
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
  final String customerName;
  final String location;
  final String schedule;
  final double price;
  final String status;
  final DateTime createdAt;

  const BookingItem({
    required this.id,
    required this.bookingReference,
    required this.serviceTitle,
    required this.category,
    required this.providerName,
    required this.customerName,
    required this.location,
    required this.schedule,
    required this.price,
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
      customerName: json['customerName'] as String? ?? 'Customer',
      location: json['location'] as String? ?? 'Colombo',
      schedule: json['schedule'] as String? ?? '17 Sep · 4:00 PM · Colombo 05',
      price: (json['price'] as num?)?.toDouble() ?? 4500.0,
      status: json['status'] as String? ?? 'Upcoming',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get priceFormatted => 'Rs. ${price.toInt()}';
  bool get isUpcoming => status.toLowerCase() == 'upcoming';
  bool get isActive =>
      status.toLowerCase() == 'active' || status.toLowerCase() == 'in progress';
  bool get isCompleted => status.toLowerCase() == 'completed';
  bool get isCancelled => status.toLowerCase() == 'cancelled';

  BookingItem copyWith({String? status}) {
    return BookingItem(
      id: id,
      bookingReference: bookingReference,
      serviceTitle: serviceTitle,
      category: category,
      providerName: providerName,
      customerName: customerName,
      location: location,
      schedule: schedule,
      price: price,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}
