class PaymentTransactionModel {
  final String id;
  final String userId;
  final double amount;
  final String currency;
  final String provider;
  final String reference;
  final String status;
  final DateTime? paymentDate;

  PaymentTransactionModel({
    required this.id,
    required this.userId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.reference,
    required this.status,
    this.paymentDate,
  });

  factory PaymentTransactionModel.fromJson(Map<String, dynamic> json) {
    return PaymentTransactionModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      amount: ((json['amount'] as num?)?.toDouble()) ?? 0.0,
      currency: json['currency'] ?? 'TZS',
      provider: json['provider'] ?? '',
      reference: json['reference'] ?? json['transaction_reference'] ?? '',
      status: json['status'] ?? 'pending',
      paymentDate: json['payment_date'] != null ? DateTime.tryParse(json['payment_date']) : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'amount': amount,
        'currency': currency,
        'provider': provider,
        'reference': reference,
        'status': status,
        'payment_date': paymentDate?.toIso8601String(),
      };
}
