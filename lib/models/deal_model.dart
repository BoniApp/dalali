enum DealStatus {
  matched,
  viewingScheduled,
  viewingCompleted,
  negotiating,
  tenancyConfirmed,
  agencyFeePending,
  agencyFeePaid,
  closed,
}

/// ═══════════════════════════════════════════════════════════════
/// DEAL MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Tracks the lifecycle from property match to confirmed tenancy
/// and agency fee payout. Each deal links a property listing,
/// the listing creator, the seeker, and the landlord.
///
class DealModel {
  final String dealId;
  final String propertyId;
  final String listingCreatorId;
  final String? seekerId;
  final String landlordPhone;
  final DealStatus status;
  final DateTime? viewingDate;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  // Dual confirmation flags
  final bool tenantConfirmed;
  final bool landlordConfirmed;
  final DateTime? tenantConfirmedAt;
  final DateTime? landlordConfirmedAt;

  const DealModel({
    required this.dealId,
    required this.propertyId,
    required this.listingCreatorId,
    this.seekerId,
    required this.landlordPhone,
    this.status = DealStatus.matched,
    this.viewingDate,
    required this.createdAt,
    this.confirmedAt,
    this.tenantConfirmed = false,
    this.landlordConfirmed = false,
    this.tenantConfirmedAt,
    this.landlordConfirmedAt,
  });

  bool get isTenancyConfirmed =>
      tenantConfirmed && landlordConfirmed;

  Map<String, dynamic> toJson() => {
        'deal_id': dealId,
        'property_id': propertyId,
        'listing_creator_id': listingCreatorId,
        'seeker_id': seekerId,
        'landlord_phone': landlordPhone,
        'status': status.name,
        'viewing_date': viewingDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
        'confirmed_at': confirmedAt?.toIso8601String(),
        'tenant_confirmed': tenantConfirmed,
        'landlord_confirmed': landlordConfirmed,
        'tenant_confirmed_at': tenantConfirmedAt?.toIso8601String(),
        'landlord_confirmed_at': landlordConfirmedAt?.toIso8601String(),
      };

  factory DealModel.fromJson(Map<String, dynamic> json) {
    return DealModel(
      dealId: json['deal_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      listingCreatorId: json['listing_creator_id'] ?? '',
      seekerId: json['seeker_id'],
      landlordPhone: json['landlord_phone'] ?? '',
      status: DealStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DealStatus.matched,
      ),
      viewingDate: json['viewing_date'] != null
          ? DateTime.tryParse(json['viewing_date'])
          : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'])
          : null,
      tenantConfirmed: json['tenant_confirmed'] ?? false,
      landlordConfirmed: json['landlord_confirmed'] ?? false,
      tenantConfirmedAt: json['tenant_confirmed_at'] != null
          ? DateTime.tryParse(json['tenant_confirmed_at'])
          : null,
      landlordConfirmedAt: json['landlord_confirmed_at'] != null
          ? DateTime.tryParse(json['landlord_confirmed_at'])
          : null,
    );
  }

  DealModel copyWith({
    DealStatus? status,
    DateTime? viewingDate,
    DateTime? confirmedAt,
    bool? tenantConfirmed,
    bool? landlordConfirmed,
    DateTime? tenantConfirmedAt,
    DateTime? landlordConfirmedAt,
  }) {
    return DealModel(
      dealId: dealId,
      propertyId: propertyId,
      listingCreatorId: listingCreatorId,
      seekerId: seekerId,
      landlordPhone: landlordPhone,
      status: status ?? this.status,
      viewingDate: viewingDate ?? this.viewingDate,
      createdAt: createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      tenantConfirmed: tenantConfirmed ?? this.tenantConfirmed,
      landlordConfirmed: landlordConfirmed ?? this.landlordConfirmed,
      tenantConfirmedAt: tenantConfirmedAt ?? this.tenantConfirmedAt,
      landlordConfirmedAt: landlordConfirmedAt ?? this.landlordConfirmedAt,
    );
  }
}
