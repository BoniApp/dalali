enum EarningsEntryType { agencyFee, bonus, adjustment }
enum EarningsEntryStatus { pending, available, withdrawn, cancelled }

/// ═══════════════════════════════════════════════════════════════
/// EARNINGS ENTRY MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// A single row in the user's earnings ledger. Replaces generic
/// wallet transactions with purpose-built agency-fee tracking.
///
class EarningsEntryModel {
  final String entryId;
  final String userId;
  final String? dealId;
  final String? propertyId;
  final String? propertyTitle;
  final EarningsEntryType type;
  final EarningsEntryStatus status;
  final double amount;
  final String currency;
  final DateTime createdAt;
  final DateTime? availableAt;
  final DateTime? withdrawnAt;
  final String? withdrawalId;

  const EarningsEntryModel({
    required this.entryId,
    required this.userId,
    this.dealId,
    this.propertyId,
    this.propertyTitle,
    required this.type,
    required this.status,
    required this.amount,
    this.currency = 'TZS',
    required this.createdAt,
    this.availableAt,
    this.withdrawnAt,
    this.withdrawalId,
  });

  bool get isAvailable => status == EarningsEntryStatus.available;
  bool get isPending => status == EarningsEntryStatus.pending;
  bool get isWithdrawn => status == EarningsEntryStatus.withdrawn;

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'user_id': userId,
        'deal_id': dealId,
        'property_id': propertyId,
        'property_title': propertyTitle,
        'type': type.name,
        'status': status.name,
        'amount': amount,
        'currency': currency,
        'created_at': createdAt.toIso8601String(),
        'available_at': availableAt?.toIso8601String(),
        'withdrawn_at': withdrawnAt?.toIso8601String(),
        'withdrawal_id': withdrawalId,
      };

  factory EarningsEntryModel.fromJson(Map<String, dynamic> json) {
    return EarningsEntryModel(
      entryId: json['entry_id'] ?? '',
      userId: json['user_id'] ?? '',
      dealId: json['deal_id'],
      propertyId: json['property_id'],
      propertyTitle: json['property_title'],
      type: EarningsEntryType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => EarningsEntryType.agencyFee,
      ),
      status: EarningsEntryStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EarningsEntryStatus.pending,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? 'TZS',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      availableAt: json['available_at'] != null
          ? DateTime.tryParse(json['available_at'])
          : null,
      withdrawnAt: json['withdrawn_at'] != null
          ? DateTime.tryParse(json['withdrawn_at'])
          : null,
      withdrawalId: json['withdrawal_id'],
    );
  }

  EarningsEntryModel copyWith({
    EarningsEntryStatus? status,
    DateTime? availableAt,
    DateTime? withdrawnAt,
    String? withdrawalId,
  }) {
    return EarningsEntryModel(
      entryId: entryId,
      userId: userId,
      dealId: dealId,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      type: type,
      status: status ?? this.status,
      amount: amount,
      currency: currency,
      createdAt: createdAt,
      availableAt: availableAt ?? this.availableAt,
      withdrawnAt: withdrawnAt ?? this.withdrawnAt,
      withdrawalId: withdrawalId ?? this.withdrawalId,
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// EARNINGS SUMMARY MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Lightweight aggregate for dashboards.
///
class EarningsSummaryModel {
  final double totalEarned;
  final double pendingEarnings;
  final double withdrawableBalance;
  final int successfulListings;
  final int pendingListings;

  const EarningsSummaryModel({
    this.totalEarned = 0,
    this.pendingEarnings = 0,
    this.withdrawableBalance = 0,
    this.successfulListings = 0,
    this.pendingListings = 0,
  });

  EarningsSummaryModel copyWith({
    double? totalEarned,
    double? pendingEarnings,
    double? withdrawableBalance,
    int? successfulListings,
    int? pendingListings,
  }) {
    return EarningsSummaryModel(
      totalEarned: totalEarned ?? this.totalEarned,
      pendingEarnings: pendingEarnings ?? this.pendingEarnings,
      withdrawableBalance: withdrawableBalance ?? this.withdrawableBalance,
      successfulListings: successfulListings ?? this.successfulListings,
      pendingListings: pendingListings ?? this.pendingListings,
    );
  }
}
