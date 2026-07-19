enum PropertyType { apartment, house, villa, bedsitter, office, shop, room, selfContainedRoom, plot, frame }
enum PropertyStatus { available, occupied, pending }
enum ListingType { basic, featured }
enum ListingSource { landlordListing, userMoveListing, agentListing }
enum ListingStatus { draft, active, viewing, negotiating, tenancyConfirmed, closed }

// ─── Rental Payment Terms Enums ───────────────────────────
enum PaymentTerm { monthly, threeMonths, sixMonths, twelveMonths, negotiable }

// ─── Utility Responsibility Enums ───────────────────────────
enum UtilityResponsibility { tenant, landlord, shared }
enum InternetType { included, tenant, notAvailable }
enum SecurityType { included, notIncluded }

/// Utility breakdown for Tanzanian rental transparency.
class PropertyUtilities {
  final UtilityResponsibility water;
  final UtilityResponsibility electricity;
  final InternetType internet;
  final UtilityResponsibility wasteCollection;
  final SecurityType security;

  const PropertyUtilities({
    this.water = UtilityResponsibility.shared,
    this.electricity = UtilityResponsibility.shared,
    this.internet = InternetType.notAvailable,
    this.wasteCollection = UtilityResponsibility.shared,
    this.security = SecurityType.notIncluded,
  });

  Map<String, dynamic> toJson() => {
    'water': water.name,
    'electricity': electricity.name,
    'internet': internet.name,
    'wasteCollection': wasteCollection.name,
    'security': security.name,
  };

  factory PropertyUtilities.fromJson(Map<String, dynamic> json) {
    return PropertyUtilities(
      water: UtilityResponsibility.values.firstWhere(
        (e) => e.name == json['water'],
        orElse: () => UtilityResponsibility.shared,
      ),
      electricity: UtilityResponsibility.values.firstWhere(
        (e) => e.name == json['electricity'],
        orElse: () => UtilityResponsibility.shared,
      ),
      internet: InternetType.values.firstWhere(
        (e) => e.name == json['internet'],
        orElse: () => InternetType.notAvailable,
      ),
      wasteCollection: UtilityResponsibility.values.firstWhere(
        (e) => e.name == json['wasteCollection'],
        orElse: () => UtilityResponsibility.shared,
      ),
      security: SecurityType.values.firstWhere(
        (e) => e.name == json['security'],
        orElse: () => SecurityType.notIncluded,
      ),
    );
  }

  PropertyUtilities copyWith({
    UtilityResponsibility? water,
    UtilityResponsibility? electricity,
    InternetType? internet,
    UtilityResponsibility? wasteCollection,
    SecurityType? security,
  }) {
    return PropertyUtilities(
      water: water ?? this.water,
      electricity: electricity ?? this.electricity,
      internet: internet ?? this.internet,
      wasteCollection: wasteCollection ?? this.wasteCollection,
      security: security ?? this.security,
    );
  }
}

class PropertyModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final String street;
  final String district;
  final String ward;
  final double latitude;
  final double longitude;
  final double rentPrice;
  final int bedrooms;
  final int bathrooms;
  final PropertyType propertyType;
  final bool isFurnished;
  final bool hasWater;
  final bool hasParking;
  final bool hasSecurity;
  final bool sharedCompound;
  final bool hasBorehole;
  final bool hasElectricity;
  final bool hasInternet;
  final bool hasGym;
  final bool hasSwimmingPool;
  final bool hasBalcony;
  final bool hasGarden;
  final bool hasBackupGenerator;
  final bool hasCctv;
  final bool hasElevator;
  final bool petFriendly;
  final bool hasAirConditioning;
  final bool hasFittedKitchen;
  final List<String> images;
  final String? videoUrl;
  final PropertyStatus status;
  final ListingType listingType;
  final ListingSource sourceType;
  final String landlordId;
  final String landlordName;
  final String landlordPhone;
  final bool isLandlordVerified;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int viewCount;
  final int inquiryCount;
  final bool isApproved;

  // ═══ Listing Ownership & Registry ═══════════════════════════
  final String listingCreatorId;
  final String listingCreatorRole;
  final String? registryId;
  final bool agencyFeeEligible;
  final bool tenancyConfirmed;
  final ListingStatus listingStatus;

  /// Straight-line distance in meters from a reference point.
  /// Populated only by geo queries (`properties_nearby` RPC) or live
  /// GPS updates on the Near Me map; `null` everywhere else.
  final double? distanceMeters;

  // ═══ Scaling / ranking fields ══════════════════════════════
  final double rating;
  final int reviewCount;
  final bool isBoosted;
  final DateTime? boostExpiresAt;
  final List<String> tags;

  // ═══ HTN Utility Transparency ══════════════════════════════
  final PropertyUtilities utilities;

  // ═══ Safety Intelligence ═══════════════════════════════════
  final double safetyScore;
  final int incidentCount;

  // ═══ Rental Payment Terms ══════════════════════════════════
  final double rentAmount;
  final List<PaymentTerm> paymentOptions;
  final PaymentTerm? minimumAcceptedTerm;
  final bool depositRequired;
  final double depositAmount;

  PropertyModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    this.street = '',
    this.district = '',
    this.ward = '',
    required this.latitude,
    required this.longitude,
    required this.rentPrice,
    required this.bedrooms,
    required this.bathrooms,
    required this.propertyType,
    required this.isFurnished,
    required this.hasWater,
    required this.hasParking,
    required this.hasSecurity,
    this.sharedCompound = false,
    this.hasBorehole = false,
    this.hasElectricity = true,
    this.hasInternet = false,
    this.hasGym = false,
    this.hasSwimmingPool = false,
    this.hasBalcony = false,
    this.hasGarden = false,
    this.hasBackupGenerator = false,
    this.hasCctv = false,
    this.hasElevator = false,
    this.petFriendly = false,
    this.hasAirConditioning = false,
    this.hasFittedKitchen = false,
    required this.images,
    this.videoUrl,
    this.status = PropertyStatus.available,
    this.listingType = ListingType.basic,
    this.sourceType = ListingSource.landlordListing,
    required this.landlordId,
    required this.landlordName,
    required this.landlordPhone,
    this.isLandlordVerified = false,
    required this.createdAt,
    this.updatedAt,
    this.viewCount = 0,
    this.inquiryCount = 0,
    this.isApproved = true,
    this.listingCreatorId = '',
    this.listingCreatorRole = '',
    this.registryId,
    this.agencyFeeEligible = false,
    this.tenancyConfirmed = false,
    this.listingStatus = ListingStatus.draft,
    this.distanceMeters,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isBoosted = false,
    this.boostExpiresAt,
    this.tags = const [],
    this.utilities = const PropertyUtilities(),
    this.safetyScore = 80.0,
    this.incidentCount = 0,
    this.rentAmount = 0,
    this.paymentOptions = const [PaymentTerm.monthly],
    this.minimumAcceptedTerm,
    this.depositRequired = false,
    this.depositAmount = 0,
  });

  /// Maps a Supabase `properties` row to a [PropertyModel].
  /// (Previously a private helper in `DataService`; behavior identical.)
  factory PropertyModel.fromJson(Map<String, dynamic> json) {
    final utilitiesJson = json['utilities'];
    return PropertyModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      rentPrice: (json['rent_price'] as num?)?.toDouble() ?? 0.0,
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      propertyType: PropertyType.values.firstWhere(
        (e) => e.name == json['property_type'],
        orElse: () => PropertyType.apartment,
      ),
      isFurnished: json['is_furnished'] ?? false,
      hasWater: json['has_water'] ?? false,
      hasParking: json['has_parking'] ?? false,
      hasSecurity: json['has_security'] ?? false,
      sharedCompound: json['shared_compound'] ?? false,
      hasBorehole: json['has_borehole'] ?? false,
      hasElectricity: json['has_electricity'] ?? true,
      hasInternet: json['has_internet'] ?? false,
      hasGym: json['has_gym'] ?? false,
      hasSwimmingPool: json['has_swimming_pool'] ?? false,
      hasBalcony: json['has_balcony'] ?? false,
      hasGarden: json['has_garden'] ?? false,
      hasBackupGenerator: json['has_backup_generator'] ?? false,
      hasCctv: json['has_cctv'] ?? false,
      hasElevator: json['has_elevator'] ?? false,
      petFriendly: json['pet_friendly'] ?? false,
      hasAirConditioning: json['has_air_conditioning'] ?? false,
      hasFittedKitchen: json['has_fitted_kitchen'] ?? false,
      images: List<String>.from(json['images'] ?? []),
      videoUrl: json['video_url'],
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.available,
      ),
      listingType: ListingType.values.firstWhere(
        (e) => e.name == json['listing_type'],
        orElse: () => ListingType.basic,
      ),
      sourceType: ListingSource.values.firstWhere(
        (e) => e.name == json['source_type'],
        orElse: () => ListingSource.landlordListing,
      ),
      landlordId: json['landlord_id'] ?? '',
      landlordName: json['landlord_name'] ?? '',
      landlordPhone: json['landlord_phone'] ?? '',
      isLandlordVerified: json['is_landlord_verified'] ?? false,
      listingCreatorId: json['listing_creator_id'] ?? '',
      listingCreatorRole: json['listing_creator_role'] ?? '',
      registryId: json['registry_id'],
      agencyFeeEligible: json['agency_fee_eligible'] ?? false,
      tenancyConfirmed: json['tenancy_confirmed'] ?? false,
      street: json['street'] ?? '',
      district: json['district'] ?? '',
      ward: json['ward'] ?? '',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble(),
      listingStatus: ListingStatus.values.firstWhere(
        (e) => e.name == json['listing_status'],
        orElse: () => ListingStatus.draft,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      viewCount: json['view_count'] ?? 0,
      inquiryCount: json['inquiry_count'] ?? 0,
      isApproved: json['is_approved'] ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      isBoosted: json['is_boosted'] ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.tryParse(json['boost_expires_at'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      utilities: utilitiesJson is Map<String, dynamic>
          ? PropertyUtilities.fromJson(utilitiesJson)
          : const PropertyUtilities(),
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 80.0,
      incidentCount: json['incident_count'] ?? 0,
      rentAmount: (json['rent_amount'] as num?)?.toDouble() ?? 0.0,
      paymentOptions: (json['payment_options'] as List<dynamic>?)
              ?.map((e) => PaymentTerm.values.firstWhere(
                    (t) => t.name == e,
                    orElse: () => PaymentTerm.monthly,
                  ))
              .toList() ??
          const [PaymentTerm.monthly],
      minimumAcceptedTerm: json['minimum_accepted_term'] != null
          ? PaymentTerm.values.firstWhere(
              (e) => e.name == json['minimum_accepted_term'],
              orElse: () => PaymentTerm.monthly,
            )
          : null,
      depositRequired: json['deposit_required'] ?? false,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  PropertyModel copyWith({
    String? id,
    String? title,
    String? description,
    String? location,
    double? latitude,
    double? longitude,
    double? rentPrice,
    int? bedrooms,
    int? bathrooms,
    PropertyType? propertyType,
    bool? isFurnished,
    bool? hasWater,
    bool? hasParking,
    bool? hasSecurity,
    bool? sharedCompound,
    bool? hasBorehole,
    bool? hasElectricity,
    bool? hasInternet,
    bool? hasGym,
    bool? hasSwimmingPool,
    bool? hasBalcony,
    bool? hasGarden,
    bool? hasBackupGenerator,
    bool? hasCctv,
    bool? hasElevator,
    bool? petFriendly,
    bool? hasAirConditioning,
    bool? hasFittedKitchen,
    List<String>? images,
    String? videoUrl,
    PropertyStatus? status,
    ListingType? listingType,
    ListingSource? sourceType,
    String? landlordId,
    String? landlordName,
    String? landlordPhone,
    bool? isLandlordVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? viewCount,
    int? inquiryCount,
    bool? isApproved,
    String? listingCreatorId,
    String? listingCreatorRole,
    String? registryId,
    bool? agencyFeeEligible,
    bool? tenancyConfirmed,
    ListingStatus? listingStatus,
    double? distanceMeters,
    double? rating,
    String? street,
    String? district,
    String? ward,
    int? reviewCount,
    bool? isBoosted,
    DateTime? boostExpiresAt,
    List<String>? tags,
    PropertyUtilities? utilities,
    double? safetyScore,
    int? incidentCount,
    double? rentAmount,
    List<PaymentTerm>? paymentOptions,
    PaymentTerm? minimumAcceptedTerm,
    bool? depositRequired,
    double? depositAmount,
  }) {
    return PropertyModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      rentPrice: rentPrice ?? this.rentPrice,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      propertyType: propertyType ?? this.propertyType,
      isFurnished: isFurnished ?? this.isFurnished,
      hasWater: hasWater ?? this.hasWater,
      hasParking: hasParking ?? this.hasParking,
      hasSecurity: hasSecurity ?? this.hasSecurity,
      sharedCompound: sharedCompound ?? this.sharedCompound,
      hasBorehole: hasBorehole ?? this.hasBorehole,
      hasElectricity: hasElectricity ?? this.hasElectricity,
      hasInternet: hasInternet ?? this.hasInternet,
      hasGym: hasGym ?? this.hasGym,
      hasSwimmingPool: hasSwimmingPool ?? this.hasSwimmingPool,
      hasBalcony: hasBalcony ?? this.hasBalcony,
      hasGarden: hasGarden ?? this.hasGarden,
      hasBackupGenerator: hasBackupGenerator ?? this.hasBackupGenerator,
      hasCctv: hasCctv ?? this.hasCctv,
      hasElevator: hasElevator ?? this.hasElevator,
      petFriendly: petFriendly ?? this.petFriendly,
      hasAirConditioning: hasAirConditioning ?? this.hasAirConditioning,
      hasFittedKitchen: hasFittedKitchen ?? this.hasFittedKitchen,
      images: images ?? this.images,
      videoUrl: videoUrl ?? this.videoUrl,
      status: status ?? this.status,
      listingType: listingType ?? this.listingType,
      sourceType: sourceType ?? this.sourceType,
      landlordId: landlordId ?? this.landlordId,
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      isLandlordVerified: isLandlordVerified ?? this.isLandlordVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      viewCount: viewCount ?? this.viewCount,
      inquiryCount: inquiryCount ?? this.inquiryCount,
      isApproved: isApproved ?? this.isApproved,
      listingCreatorId: listingCreatorId ?? this.listingCreatorId,
      listingCreatorRole: listingCreatorRole ?? this.listingCreatorRole,
      registryId: registryId ?? this.registryId,
      agencyFeeEligible: agencyFeeEligible ?? this.agencyFeeEligible,
      tenancyConfirmed: tenancyConfirmed ?? this.tenancyConfirmed,
      listingStatus: listingStatus ?? this.listingStatus,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      rating: rating ?? this.rating,
      street: street ?? this.street,
      district: district ?? this.district,
      ward: ward ?? this.ward,
      reviewCount: reviewCount ?? this.reviewCount,
      isBoosted: isBoosted ?? this.isBoosted,
      boostExpiresAt: boostExpiresAt ?? this.boostExpiresAt,
      tags: tags ?? this.tags,
      utilities: utilities ?? this.utilities,
      safetyScore: safetyScore ?? this.safetyScore,
      incidentCount: incidentCount ?? this.incidentCount,
      rentAmount: rentAmount ?? this.rentAmount,
      paymentOptions: paymentOptions ?? this.paymentOptions,
      minimumAcceptedTerm: minimumAcceptedTerm ?? this.minimumAcceptedTerm,
      depositRequired: depositRequired ?? this.depositRequired,
      depositAmount: depositAmount ?? this.depositAmount,
    );
  }
}
