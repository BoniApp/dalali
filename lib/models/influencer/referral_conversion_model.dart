enum ConversionType { registration, agencyFeePayment, premiumPayment, dealClosed }
enum ConversionStatus { pending, approved, paid, rejected }

/// DB string values for [ConversionType] (snake_case in Postgres).
const Map<ConversionType, String> conversionTypeDbValues = {
  ConversionType.registration: 'registration',
  ConversionType.agencyFeePayment: 'agency_fee_payment',
  ConversionType.premiumPayment: 'premium_payment',
  ConversionType.dealClosed: 'deal_closed',
};

ConversionType conversionTypeFromDb(String? value) {
  return conversionTypeDbValues.entries
      .firstWhere(
        (e) => e.value == value,
        orElse: () => conversionTypeDbValues.entries.first,
      )
      .key;
}

/// ═══════════════════════════════════════════════════════════════
/// REFERRAL CONVERSION MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// A meaningful attributed referral event. Money rows carry
/// commission_amount; the matching ledger row lives in `earnings`.
/// Clients may only insert 'registration' conversions with
/// commission_amount = 0 and status = 'pending'.
///
class ReferralConversionModel {
  final String id;
  final String influencerId;
  final String? linkId;
  final String referredUserId;
  final String? transactionId;
  final String? earningsEntryId;
  final ConversionType conversionType;
  final double commissionAmount;
  final ConversionStatus status;
  final DateTime createdAt;

  const ReferralConversionModel({
    required this.id,
    required this.influencerId,
    this.linkId,
    required this.referredUserId,
    this.transactionId,
    this.earningsEntryId,
    required this.conversionType,
    this.commissionAmount = 0,
    this.status = ConversionStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'influencer_id': influencerId,
        'link_id': linkId,
        'referred_user_id': referredUserId,
        'transaction_id': transactionId,
        'earnings_entry_id': earningsEntryId,
        'conversion_type': conversionTypeDbValues[conversionType],
        'commission_amount': commissionAmount,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReferralConversionModel.fromJson(Map<String, dynamic> json) {
    return ReferralConversionModel(
      id: json['id'] ?? '',
      influencerId: json['influencer_id'] ?? '',
      linkId: json['link_id'],
      referredUserId: json['referred_user_id'] ?? '',
      transactionId: json['transaction_id'],
      earningsEntryId: json['earnings_entry_id'],
      conversionType: conversionTypeFromDb(json['conversion_type']),
      commissionAmount: (json['commission_amount'] as num?)?.toDouble() ?? 0,
      status: ConversionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ConversionStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
