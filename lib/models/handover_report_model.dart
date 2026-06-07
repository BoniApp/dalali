class HandoverReportModel {
  final String id;
  final String tenancyId;
  final String propertyId;
  final String? waterReading;
  final String? electricityReading;
  final List<String> photos;
  final String? videoUrl;
  final String notes;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  const HandoverReportModel({
    required this.id,
    required this.tenancyId,
    required this.propertyId,
    this.waterReading,
    this.electricityReading,
    this.photos = const [],
    this.videoUrl,
    this.notes = '',
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'tenancyId': tenancyId,
    'propertyId': propertyId,
    'waterReading': waterReading,
    'electricityReading': electricityReading,
    'photos': photos,
    'videoUrl': videoUrl,
    'notes': notes,
    'createdBy': createdBy,
    'createdByName': createdByName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory HandoverReportModel.fromJson(Map<String, dynamic> json, String id) =>
      HandoverReportModel(
        id: id,
        tenancyId: json['tenancyId'] ?? '',
        propertyId: json['propertyId'] ?? '',
        waterReading: json['waterReading'],
        electricityReading: json['electricityReading'],
        photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
        videoUrl: json['videoUrl'],
        notes: json['notes'] ?? '',
        createdBy: json['createdBy'] ?? '',
        createdByName: json['createdByName'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );
}
