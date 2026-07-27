enum TenancyStatus { upcoming, active, completed, terminated, renewed }

class TenancyModel {
  final String id;
  final String tenantId;
  final String tenantName;
  final String landlordId;
  final String landlordName;
  final String? agentId;
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
  final String? terminationReason;
  final DateTime? noticeGivenAt;
  final String? noticeBy;
  final DateTime? plannedMoveOutDate;
  final DateTime? renewalRequestedAt;
  final String? renewedFromTenancyId;

  const TenancyModel({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.landlordId,
    required this.landlordName,
    this.agentId,
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
    this.terminationReason,
    this.noticeGivenAt,
    this.noticeBy,
    this.plannedMoveOutDate,
    this.renewalRequestedAt,
    this.renewedFromTenancyId,
  });

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'tenantName': tenantName,
    'landlordId': landlordId,
    'landlordName': landlordName,
    'agentId': agentId,
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
    'terminationReason': terminationReason,
    'noticeGivenAt': noticeGivenAt?.toIso8601String(),
    'noticeBy': noticeBy,
    'plannedMoveOutDate': plannedMoveOutDate?.toIso8601String(),
    'renewalRequestedAt': renewalRequestedAt?.toIso8601String(),
    'renewedFromTenancyId': renewedFromTenancyId,
  };

  factory TenancyModel.fromJson(Map<String, dynamic> json, String id) =>
      TenancyModel(
        id: id,
        tenantId: json['tenantId'] ?? '',
        tenantName: json['tenantName'] ?? '',
        landlordId: json['landlordId'] ?? '',
        landlordName: json['landlordName'] ?? '',
        agentId: json['agentId'],
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
        terminationReason: json['terminationReason'],
        noticeGivenAt: json['noticeGivenAt'] != null ? DateTime.parse(json['noticeGivenAt']) : null,
        noticeBy: json['noticeBy'],
        plannedMoveOutDate: json['plannedMoveOutDate'] != null ? DateTime.parse(json['plannedMoveOutDate']) : null,
        renewalRequestedAt: json['renewalRequestedAt'] != null ? DateTime.parse(json['renewalRequestedAt']) : null,
        renewedFromTenancyId: json['renewedFromTenancyId'],
      );

  TenancyModel copyWith({
    TenancyStatus? status,
    DateTime? activatedAt,
    DateTime? completedAt,
    String? terminationReason,
    DateTime? noticeGivenAt,
    String? noticeBy,
    DateTime? plannedMoveOutDate,
    DateTime? renewalRequestedAt,
  }) => TenancyModel(
    id: id,
    tenantId: tenantId,
    tenantName: tenantName,
    landlordId: landlordId,
    landlordName: landlordName,
    agentId: agentId,
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
    terminationReason: terminationReason ?? this.terminationReason,
    noticeGivenAt: noticeGivenAt ?? this.noticeGivenAt,
    noticeBy: noticeBy ?? this.noticeBy,
    plannedMoveOutDate: plannedMoveOutDate ?? this.plannedMoveOutDate,
    renewalRequestedAt: renewalRequestedAt ?? this.renewalRequestedAt,
    renewedFromTenancyId: renewedFromTenancyId,
  );

  bool get isUpcoming => status == TenancyStatus.upcoming;
  bool get isActive => status == TenancyStatus.active;
  bool get isCompleted => status == TenancyStatus.completed;
  bool get isTerminated => status == TenancyStatus.terminated;
  bool get isRenewed => status == TenancyStatus.renewed;
  bool get noticeGiven => noticeGivenAt != null;
  bool get renewalRequested => renewalRequestedAt != null;
  DateTime get effectiveEndDate => plannedMoveOutDate ?? expectedMoveOutDate;
  int get daysUntilEnd => effectiveEndDate.difference(DateTime.now()).inDays;
  bool get isExpiringSoon => isActive && daysUntilEnd <= 60 && daysUntilEnd >= 0;
}
