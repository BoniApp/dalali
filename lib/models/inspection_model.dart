enum InspectionStatus { scheduled, completed }

class InspectionModel {
  final String id;
  final String propertyId;
  final String tenancyId;
  final String landlordId;
  final String? inspectorId;
  final InspectionStatus status;
  final DateTime? scheduledDate;
  final String? conditionBefore;
  final String? conditionAfter;
  final double damageCost;
  final List<String> photos;
  final String? notes;
  final DateTime createdAt;
  final DateTime? completedAt;

  const InspectionModel({
    required this.id,
    required this.propertyId,
    required this.tenancyId,
    required this.landlordId,
    this.inspectorId,
    this.status = InspectionStatus.scheduled,
    this.scheduledDate,
    this.conditionBefore,
    this.conditionAfter,
    this.damageCost = 0,
    this.photos = const [],
    this.notes,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
    'propertyId': propertyId,
    'tenancyId': tenancyId,
    'landlordId': landlordId,
    'inspectorId': inspectorId,
    'status': status.name,
    'scheduledDate': scheduledDate?.toIso8601String(),
    'conditionBefore': conditionBefore,
    'conditionAfter': conditionAfter,
    'damageCost': damageCost,
    'photos': photos,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };

  factory InspectionModel.fromJson(Map<String, dynamic> json, String id) =>
      InspectionModel(
        id: id,
        propertyId: json['propertyId'] ?? '',
        tenancyId: json['tenancyId'] ?? '',
        landlordId: json['landlordId'] ?? '',
        inspectorId: json['inspectorId'],
        status: InspectionStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => InspectionStatus.scheduled,
        ),
        scheduledDate: json['scheduledDate'] != null ? DateTime.parse(json['scheduledDate']) : null,
        conditionBefore: json['conditionBefore'],
        conditionAfter: json['conditionAfter'],
        damageCost: (json['damageCost'] as num?)?.toDouble() ?? 0,
        photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
        notes: json['notes'],
        createdAt: DateTime.parse(json['createdAt']),
        completedAt: json['completedAt'] != null ? DateTime.parse(json['completedAt']) : null,
      );

  bool get isCompleted => status == InspectionStatus.completed;
  bool get hasDamage => damageCost > 0;
}
