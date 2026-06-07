enum MaintenanceCategory { plumbing, electrical, security, general, appliance, structural }
enum MaintenanceStatus { open, inProgress, resolved }

class MaintenanceRequestModel {
  final String id;
  final String tenantId;
  final String tenantName;
  final String landlordId;
  final String propertyId;
  final String propertyTitle;
  final MaintenanceCategory category;
  final String description;
  final MaintenanceStatus status;
  final List<String> photos;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? resolutionNotes;

  const MaintenanceRequestModel({
    required this.id,
    required this.tenantId,
    required this.tenantName,
    required this.landlordId,
    required this.propertyId,
    required this.propertyTitle,
    required this.category,
    required this.description,
    this.status = MaintenanceStatus.open,
    this.photos = const [],
    required this.createdAt,
    this.resolvedAt,
    this.resolutionNotes,
  });

  Map<String, dynamic> toJson() => {
    'tenantId': tenantId,
    'tenantName': tenantName,
    'landlordId': landlordId,
    'propertyId': propertyId,
    'propertyTitle': propertyTitle,
    'category': category.name,
    'description': description,
    'status': status.name,
    'photos': photos,
    'createdAt': createdAt.toIso8601String(),
    'resolvedAt': resolvedAt?.toIso8601String(),
    'resolutionNotes': resolutionNotes,
  };

  factory MaintenanceRequestModel.fromJson(Map<String, dynamic> json, String id) =>
      MaintenanceRequestModel(
        id: id,
        tenantId: json['tenantId'] ?? '',
        tenantName: json['tenantName'] ?? '',
        landlordId: json['landlordId'] ?? '',
        propertyId: json['propertyId'] ?? '',
        propertyTitle: json['propertyTitle'] ?? '',
        category: MaintenanceCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => MaintenanceCategory.general,
        ),
        description: json['description'] ?? '',
        status: MaintenanceStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => MaintenanceStatus.open,
        ),
        photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
        createdAt: DateTime.parse(json['createdAt']),
        resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
        resolutionNotes: json['resolutionNotes'],
      );

  MaintenanceRequestModel copyWith({
    MaintenanceStatus? status,
    DateTime? resolvedAt,
    String? resolutionNotes,
  }) => MaintenanceRequestModel(
    id: id,
    tenantId: tenantId,
    tenantName: tenantName,
    landlordId: landlordId,
    propertyId: propertyId,
    propertyTitle: propertyTitle,
    category: category,
    description: description,
    status: status ?? this.status,
    photos: photos,
    createdAt: createdAt,
    resolvedAt: resolvedAt ?? this.resolvedAt,
    resolutionNotes: resolutionNotes ?? this.resolutionNotes,
  );
}
