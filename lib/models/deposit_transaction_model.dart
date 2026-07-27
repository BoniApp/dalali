enum DepositStatus { pending, settled, disputed }

class DepositTransactionModel {
  final String id;
  final String tenancyId;
  final String tenantId;
  final String landlordId;
  final double amount;
  final double deductions;
  final double refundAmount;
  final DepositStatus status;
  final String? notes;
  final DateTime createdAt;
  final DateTime? settledAt;

  const DepositTransactionModel({
    required this.id,
    required this.tenancyId,
    required this.tenantId,
    required this.landlordId,
    required this.amount,
    this.deductions = 0,
    this.refundAmount = 0,
    this.status = DepositStatus.pending,
    this.notes,
    required this.createdAt,
    this.settledAt,
  });

  Map<String, dynamic> toJson() => {
    'tenancyId': tenancyId,
    'tenantId': tenantId,
    'landlordId': landlordId,
    'amount': amount,
    'deductions': deductions,
    'refundAmount': refundAmount,
    'status': status.name,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'settledAt': settledAt?.toIso8601String(),
  };

  factory DepositTransactionModel.fromJson(Map<String, dynamic> json, String id) =>
      DepositTransactionModel(
        id: id,
        tenancyId: json['tenancyId'] ?? '',
        tenantId: json['tenantId'] ?? '',
        landlordId: json['landlordId'] ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        deductions: (json['deductions'] as num?)?.toDouble() ?? 0,
        refundAmount: (json['refundAmount'] as num?)?.toDouble() ?? 0,
        status: DepositStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => DepositStatus.pending,
        ),
        notes: json['notes'],
        createdAt: DateTime.parse(json['createdAt']),
        settledAt: json['settledAt'] != null ? DateTime.parse(json['settledAt']) : null,
      );

  bool get isSettled => status == DepositStatus.settled;
}
