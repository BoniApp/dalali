/// Transaction status through the escrow lifecycle.
enum TransactionStatus { pending, processing, locked, available, completed, failed, reversed }

/// Type of wallet transaction.
enum TransactionType { agencyFee, revenueShare, withdrawal, refund, adminAdjustment }

/// Status of a withdrawal request.
enum WithdrawalStatus { pending, processing, completed, failed }

/// Supported mobile money / bank providers for payouts.
enum PaymentProvider { mpesa, airtelMoney, tigoPesa, haloPesa, bankTransfer }

/// User wallet document stored in Firestore.
class WalletModel {
  final String userId;
  final double availableBalance;
  final double pendingBalance;
  final double lockedBalance;
  final double totalEarned;
  final double totalWithdrawn;
  final DateTime updatedAt;

  const WalletModel({
    required this.userId,
    this.availableBalance = 0,
    this.pendingBalance = 0,
    this.lockedBalance = 0,
    this.totalEarned = 0,
    this.totalWithdrawn = 0,
    required this.updatedAt,
  });

  double get totalBalance => availableBalance + pendingBalance + lockedBalance;

  WalletModel copyWith({
    double? availableBalance,
    double? pendingBalance,
    double? lockedBalance,
    double? totalEarned,
    double? totalWithdrawn,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      userId: userId,
      availableBalance: availableBalance ?? this.availableBalance,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      lockedBalance: lockedBalance ?? this.lockedBalance,
      totalEarned: totalEarned ?? this.totalEarned,
      totalWithdrawn: totalWithdrawn ?? this.totalWithdrawn,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'availableBalance': availableBalance,
    'pendingBalance': pendingBalance,
    'lockedBalance': lockedBalance,
    'totalEarned': totalEarned,
    'totalWithdrawn': totalWithdrawn,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory WalletModel.fromJson(Map<String, dynamic> json) {
    return WalletModel(
      userId: json['userId'] ?? '',
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0,
      pendingBalance: (json['pendingBalance'] as num?)?.toDouble() ?? 0,
      lockedBalance: (json['lockedBalance'] as num?)?.toDouble() ?? 0,
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0,
      totalWithdrawn: (json['totalWithdrawn'] as num?)?.toDouble() ?? 0,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

/// A single financial transaction in the ledger.
class TransactionModel {
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final double amount;
  final String currency;
  final String? payerId;
  final String? payeeId;
  final String? propertyId;
  final String? propertyTitle;
  final String paymentMethod;
  final Map<String, double>? split;
  final String? selcomTransactionId;
  final String? idempotencyKey;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? settledAt;
  final DateTime? reversedAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    this.currency = 'TZS',
    this.payerId,
    this.payeeId,
    this.propertyId,
    this.propertyTitle,
    this.paymentMethod = 'selcom',
    this.split,
    this.selcomTransactionId,
    this.idempotencyKey,
    this.failureReason,
    required this.createdAt,
    this.settledAt,
    this.reversedAt,
  });

  TransactionModel copyWith({
    TransactionStatus? status,
    Map<String, double>? split,
    String? selcomTransactionId,
    String? failureReason,
    DateTime? settledAt,
    DateTime? reversedAt,
  }) {
    return TransactionModel(
      id: id,
      type: type,
      status: status ?? this.status,
      amount: amount,
      currency: currency,
      payerId: payerId,
      payeeId: payeeId,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      paymentMethod: paymentMethod,
      split: split ?? this.split,
      selcomTransactionId: selcomTransactionId ?? this.selcomTransactionId,
      idempotencyKey: idempotencyKey,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt,
      settledAt: settledAt ?? this.settledAt,
      reversedAt: reversedAt ?? this.reversedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'status': status.name,
    'amount': amount,
    'currency': currency,
    'payerId': payerId,
    'payeeId': payeeId,
    'propertyId': propertyId,
    'propertyTitle': propertyTitle,
    'paymentMethod': paymentMethod,
    'split': split,
    'selcomTransactionId': selcomTransactionId,
    'idempotencyKey': idempotencyKey,
    'failureReason': failureReason,
    'createdAt': createdAt.toIso8601String(),
    'settledAt': settledAt?.toIso8601String(),
    'reversedAt': reversedAt?.toIso8601String(),
  };

  factory TransactionModel.fromJson(Map<String, dynamic> json, String id) {
    return TransactionModel(
      id: id,
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.agencyFee,
      ),
      status: TransactionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TransactionStatus.pending,
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] ?? 'TZS',
      payerId: json['payerId'],
      payeeId: json['payeeId'],
      propertyId: json['propertyId'],
      propertyTitle: json['propertyTitle'],
      paymentMethod: json['paymentMethod'] ?? 'selcom',
      split: json['split'] != null
          ? Map<String, double>.from(
              (json['split'] as Map<String, dynamic>).map(
                (k, v) => MapEntry(k, (v as num).toDouble()),
              ),
            )
          : null,
      selcomTransactionId: json['selcomTransactionId'],
      idempotencyKey: json['idempotencyKey'],
      failureReason: json['failureReason'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      settledAt: json['settledAt'] != null
          ? DateTime.tryParse(json['settledAt'])
          : null,
      reversedAt: json['reversedAt'] != null
          ? DateTime.tryParse(json['reversedAt'])
          : null,
    );
  }
}

/// A withdrawal request from an agent/landlord.
class WithdrawalModel {
  final String id;
  final String userId;
  final double amount;
  final String phone;
  final PaymentProvider provider;
  final WithdrawalStatus status;
  final String? selcomPayoutId;
  final String? failureReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  const WithdrawalModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.phone,
    this.provider = PaymentProvider.mpesa,
    required this.status,
    this.selcomPayoutId,
    this.failureReason,
    required this.createdAt,
    this.processedAt,
  });

  WithdrawalModel copyWith({
    WithdrawalStatus? status,
    String? selcomPayoutId,
    String? failureReason,
    DateTime? processedAt,
  }) {
    return WithdrawalModel(
      id: id,
      userId: userId,
      amount: amount,
      phone: phone,
      provider: provider,
      status: status ?? this.status,
      selcomPayoutId: selcomPayoutId ?? this.selcomPayoutId,
      failureReason: failureReason ?? this.failureReason,
      createdAt: createdAt,
      processedAt: processedAt ?? this.processedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'amount': amount,
    'phone': phone,
    'provider': provider.name,
    'status': status.name,
    'selcomPayoutId': selcomPayoutId,
    'failureReason': failureReason,
    'createdAt': createdAt.toIso8601String(),
    'processedAt': processedAt?.toIso8601String(),
  };

  factory WithdrawalModel.fromJson(Map<String, dynamic> json, String id) {
    return WithdrawalModel(
      id: id,
      userId: json['userId'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      phone: json['phone'] ?? '',
      provider: PaymentProvider.values.firstWhere(
        (e) => e.name == json['provider'],
        orElse: () => PaymentProvider.mpesa,
      ),
      status: WithdrawalStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => WithdrawalStatus.pending,
      ),
      selcomPayoutId: json['selcomPayoutId'],
      failureReason: json['failureReason'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      processedAt: json['processedAt'] != null
          ? DateTime.tryParse(json['processedAt'])
          : null,
    );
  }
}

/// System-wide financial settings (admin controlled).
class SystemSettingsModel {
  final double agencyFee;
  final double agentShare;
  final double platformShare;
  final int settlementDelayHours;
  final double minWithdrawal;
  final DateTime updatedAt;

  const SystemSettingsModel({
    this.agencyFee = 20000,
    this.agentShare = 0.60,
    this.platformShare = 0.40,
    this.settlementDelayHours = 48,
    this.minWithdrawal = 5000,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'agencyFee': agencyFee,
    'agentShare': agentShare,
    'platformShare': platformShare,
    'settlementDelayHours': settlementDelayHours,
    'minWithdrawal': minWithdrawal,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      agencyFee: (json['agencyFee'] as num?)?.toDouble() ?? 20000,
      agentShare: (json['agentShare'] as num?)?.toDouble() ?? 0.60,
      platformShare: (json['platformShare'] as num?)?.toDouble() ?? 0.40,
      settlementDelayHours: json['settlementDelayHours'] ?? 48,
      minWithdrawal: (json['minWithdrawal'] as num?)?.toDouble() ?? 5000,
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
