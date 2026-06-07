enum ApplicationStatus { pending, approved, rejected }

class TenancyApplicationModel {
  final String id;
  final String propertyId;
  final String propertyTitle;
  final String tenantId;
  final String tenantName;
  final String tenantPhone;
  final String landlordId;
  final String landlordName;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? notes;

  const TenancyApplicationModel({
    required this.id,
    required this.propertyId,
    required this.propertyTitle,
    required this.tenantId,
    required this.tenantName,
    required this.tenantPhone,
    required this.landlordId,
    required this.landlordName,
    this.status = ApplicationStatus.pending,
    required this.createdAt,
    this.resolvedAt,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'propertyId': propertyId,
    'propertyTitle': propertyTitle,
    'tenantId': tenantId,
    'tenantName': tenantName,
    'tenantPhone': tenantPhone,
    'landlordId': landlordId,
    'landlordName': landlordName,
    'status': status.name,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'notes': notes,
  };

  factory TenancyApplicationModel.fromJson(Map<String, dynamic> json, String id) =>
      TenancyApplicationModel(
        id: id,
        propertyId: json['propertyId'] ?? '',
        propertyTitle: json['propertyTitle'] ?? '',
        tenantId: json['tenantId'] ?? '',
        tenantName: json['tenantName'] ?? '',
        tenantPhone: json['tenantPhone'] ?? '',
        landlordId: json['landlordId'] ?? '',
        landlordName: json['landlordName'] ?? '',
        status: ApplicationStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ApplicationStatus.pending,
        ),
        createdAt: DateTime.parse(json['createdAt']),
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
        notes: json['notes'],
      );

  TenancyApplicationModel copyWith({
    ApplicationStatus? status,
    DateTime? resolvedAt,
    String? notes,
  }) => TenancyApplicationModel(
    id: id,
    propertyId: propertyId,
    propertyTitle: propertyTitle,
    tenantId: tenantId,
    tenantName: tenantName,
    tenantPhone: tenantPhone,
    landlordId: landlordId,
    landlordName: landlordName,
    status: status ?? this.status,
    createdAt: createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    notes: notes ?? this.notes,
  );
}
