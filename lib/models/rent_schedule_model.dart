enum PaymentStatus { pending, paid, overdue }

class RentScheduleModel {
  final String id;
  final String tenancyId;
  final String tenantId;
  final String propertyTitle;
  final DateTime dueDate;
  final double amount;
  final PaymentStatus status;
  final DateTime? paidAt;

  const RentScheduleModel({
    required this.id,
    required this.tenancyId,
    required this.tenantId,
    required this.propertyTitle,
    required this.dueDate,
    required this.amount,
    this.status = PaymentStatus.pending,
    this.paidAt,
  });

  Map<String, dynamic> toJson() => {
    'tenancyId': tenancyId,
    'tenantId': tenantId,
    'propertyTitle': propertyTitle,
    'dueDate': dueDate.toIso8601String(),
    'amount': amount,
    'status': status.name,
    'paidAt': paidAt?.toIso8601String(),
  };

  factory RentScheduleModel.fromJson(Map<String, dynamic> json, String id) =>
      RentScheduleModel(
        id: id,
        tenancyId: json['tenancyId'] ?? '',
        tenantId: json['tenantId'] ?? '',
        propertyTitle: json['propertyTitle'] ?? '',
        dueDate: DateTime.parse(json['dueDate']),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        status: PaymentStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => PaymentStatus.pending,
        ),
        paidAt: json['paidAt'] != null ? DateTime.parse(json['paidAt']) : null,
      );

  bool get isOverdue => status != PaymentStatus.paid && DateTime.now().isAfter(dueDate);
  int get daysUntilDue => dueDate.difference(DateTime.now()).inDays;
}
