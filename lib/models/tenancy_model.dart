enum TenancyStatus { upcoming, active, completed, terminated }

class TenancyModel {
  final String id;
  final String tenantId;
  final String tenantName;
  final String landlordId;
  final String landlordName;
  final String propertyId;
  final String propertyTitle;
  final String propertyLocation;
  final DateTime moveInDate;
  final DateTime expectedMoveOutDate;
  final double rentAmount;
  final double depositAmount;
  final TenancyStatus status;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? completedAt;

  const TenancyModel({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.landlordId,
    required this.landlordName,
    required this.propertyId,
    required this.propertyTitle,
    required this.propertyLocation,
    required this.moveInDate,
    required this.expectedMoveOutDate,
    required this.rentAmount,
    required this.depositAmount,
    this.status = TenancyStatus.upcoming,
    required this.createdAt,
    this.activatedAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'tenantName': tenantName,
    'landlordId': landlordId,
    'landlordName': landlordName,
    'propertyId': propertyId,
    'propertyTitle': propertyTitle,
    'propertyLocation': propertyLocation,
    'moveInDate': moveInDate.toIso8601String(),
    'expectedMoveOutDate': expectedMoveOutDate.toIso8601String(),
    'rentAmount': rentAmount,
    'depositAmount': depositAmount,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'activatedAt': activatedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory TenancyModel.fromJson(Map<String, dynamic> json, String id) =>
      TenancyModel(
        id: id,
        tenantId: json['tenantId'] ?? '',
        tenantName: json['tenantName'] ?? '',
        landlordId: json['landlordId'] ?? '',
        landlordName: json['landlordName'] ?? '',
        propertyId: json['propertyId'] ?? '',
        propertyTitle: json['propertyTitle'] ?? '',
        propertyLocation: json['propertyLocation'] ?? '',
        moveInDate: DateTime.parse(json['moveInDate']),
        expectedMoveOutDate: DateTime.parse(json['expectedMoveOutDate']),
        rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? 0,
        depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0,
        status: TenancyStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => TenancyStatus.upcoming,
        ),
        createdAt: DateTime.parse(json['createdAt']),
        activatedAt: json['activatedAt'] != null ? DateTime.parse(json['activatedAt']) : null,
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      );

  TenancyModel copyWith({
    TenancyStatus? status,
    DateTime? activatedAt,
    DateTime? completedAt,
  }) => TenancyModel(
    id: id,
    tenantId: tenantId,
    tenantName: tenantName,
    landlordId: landlordId,
    landlordName: landlordName,
    propertyId: propertyId,
    propertyTitle: propertyTitle,
    propertyLocation: propertyLocation,
    moveInDate: moveInDate,
    expectedMoveOutDate: expectedMoveOutDate,
    rentAmount: rentAmount,
    depositAmount: depositAmount,
    status: status ?? this.status,
    createdAt: createdAt,
    activatedAt: activatedAt ?? this.activatedAt,
    completedAt: completedAt ?? this.completedAt,
  );

  bool get isUpcoming => status == TenancyStatus.upcoming;
  bool get isActive => status == TenancyStatus.active;
  bool get isCompleted => status == TenancyStatus.completed;
  bool get isTerminated => status == TenancyStatus.terminated;
}
