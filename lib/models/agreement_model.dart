class AgreementModel {
  final String id;
  final String tenancyId;
  final String documentUrl;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;

  const AgreementModel({
    required this.id,
    required this.tenancyId,
    required this.documentUrl,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'tenancyId': tenancyId,
    'documentUrl': documentUrl,
    'uploadedBy': uploadedBy,
    'uploadedByName': uploadedByName,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AgreementModel.fromJson(Map<String, dynamic> json, String id) =>
      AgreementModel(
        id: id,
        tenancyId: json['tenancyId'] ?? '',
        documentUrl: json['documentUrl'] ?? '',
        uploadedBy: json['uploadedBy'] ?? '',
        uploadedByName: json['uploadedByName'] ?? '',
        createdAt: DateTime.parse(json['createdAt']),
      );
}
