enum AgencyFeeStatus { pending, approved, paid, cancelled }

/// ═══════════════════════════════════════════════════════════════
/// AGENCY FEE MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Represents a single agency fee of 20,000 TZS owed to the
/// listing creator when a tenancy is confirmed.
///
class AgencyFeeModel {
  final String feeId;
  final String dealId;
  final String propertyId;
  final String listingCreatorId;
  final double amount;
  final String currency;
  final AgencyFeeStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? paidAt;
  final String? approvedBy;
  final String? payoutReference;

  const AgencyFeeModel({
    required this.feeId,
    required this.dealId,
    required this.propertyId,
    required this.listingCreatorId,
    this.amount = 20000,
    this.currency = 'TZS',
    this.status = AgencyFeeStatus.pending,
    required this.createdAt,
    this.approvedAt,
    this.paidAt,
    this.approvedBy,
    this.payoutReference,
  });

  Map<String, dynamic> toJson() => {
        'fee_id': feeId,
        'deal_id': dealId,
        'property_id': propertyId,
        'listing_creator_id': listingCreatorId,
        'amount': amount,
        'currency': currency,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
        'approved_at': approvedAt?.toIso8601String(),
        'paid_at': paidAt?.toIso8601String(),
        'approved_by': approvedBy,
        'payout_reference': payoutReference,
      };

  factory AgencyFeeModel.fromJson(Map<String, dynamic> json) {
    return AgencyFeeModel(
      feeId: json['fee_id'] ?? '',
      dealId: json['deal_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      listingCreatorId: json['listing_creator_id'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 20000,
      currency: json['currency'] ?? 'TZS',
      status: AgencyFeeStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AgencyFeeStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      approvedAt: json['approved_at'] != null
          ? DateTime.tryParse(json['approved_at'])
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.tryParse(json['paid_at'])
          : null,
      approvedBy: json['approved_by'],
      payoutReference: json['payout_reference'],
    );
  }

  AgencyFeeModel copyWith({
    AgencyFeeStatus? status,
    DateTime? approvedAt,
    DateTime? paidAt,
    String? approvedBy,
    String? payoutReference,
  }) {
    return AgencyFeeModel(
      feeId: feeId,
      dealId: dealId,
      propertyId: propertyId,
      listingCreatorId: listingCreatorId,
      amount: amount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      paidAt: paidAt ?? this.paidAt,
      approvedBy: approvedBy ?? this.approvedBy,
      payoutReference: payoutReference ?? this.payoutReference,
    );
  }
}
