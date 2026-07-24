enum PaymentStatus { pending, paid, failed, cancelled, expired }

/// ═══════════════════════════════════════════════════════════════
/// PAYMENT MODEL (DPO Pay)
/// ═══════════════════════════════════════════════════════════════
///
/// A row of the `payments` table (migration 022): one agency-fee
/// payment through DPO Pay, from token creation to settlement.
/// Rows are written by edge functions only; clients read.
class PaymentModel {
  final String id;
  final String propertyId;
  final String tenantId;
  final String? agentId;
  final String? landlordId;
  final double amount;
  final String currency;
  final String? dpoToken;
  final String? dpoTransactionId;
  final String? paymentMethod;
  final PaymentStatus status;
  final String receiptNumber;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentModel({
    required this.id,
    required this.propertyId,
    required this.tenantId,
    this.agentId,
    this.landlordId,
    required this.amount,
    this.currency = 'TZS',
    this.dpoToken,
    this.dpoTransactionId,
    this.paymentMethod,
    this.status = PaymentStatus.pending,
    required this.receiptNumber,
    this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPaid => status == PaymentStatus.paid;
  bool get isPending => status == PaymentStatus.pending;

  factory PaymentModel.fromJson(Map<String, dynamic> json) => PaymentModel(
        id: json['id'] ?? '',
        propertyId: json['property_id'] ?? '',
        tenantId: json['tenant_id'] ?? '',
        agentId: json['agent_id'],
        landlordId: json['landlord_id'],
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        currency: json['currency'] ?? 'TZS',
        dpoToken: json['dpo_token'],
        dpoTransactionId: json['dpo_transaction_id'],
        paymentMethod: json['payment_method'],
        status: PaymentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => PaymentStatus.pending,
        ),
        receiptNumber: json['receipt_number'] ?? '',
        paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
        createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      );
}
