/// ═══════════════════════════════════════════════════════════════
/// ID DOCUMENT MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Represents a captured identity document with extracted fields.
///
class IdDocumentModel {
  final String documentId;
  final String userId;
  final String documentType; // nidaId, passport, etc.
  final String? frontImageUrl;
  final String? backImageUrl;
  final String? extractedFullName;
  final String? extractedDocumentNumber;
  final DateTime? extractedDateOfBirth;
  final DateTime? extractedExpiryDate;
  final String? extractedNationality;
  final double ocrConfidence;
  final bool mrzValid;
  final bool checksumValid;
  final DateTime capturedAt;

  const IdDocumentModel({
    required this.documentId,
    required this.userId,
    required this.documentType,
    this.frontImageUrl,
    this.backImageUrl,
    this.extractedFullName,
    this.extractedDocumentNumber,
    this.extractedDateOfBirth,
    this.extractedExpiryDate,
    this.extractedNationality,
    this.ocrConfidence = 0.0,
    this.mrzValid = false,
    this.checksumValid = false,
    required this.capturedAt,
  });

  bool get isComplete =>
      extractedFullName != null &&
      extractedDocumentNumber != null &&
      extractedDateOfBirth != null &&
      ocrConfidence >= 0.85;

  int? get age {
    if (extractedDateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - extractedDateOfBirth!.year;
    if (now.month < extractedDateOfBirth!.month ||
        (now.month == extractedDateOfBirth!.month && now.day < extractedDateOfBirth!.day)) {
      age--;
    }
    return age;
  }

  bool get isAdult => (age ?? 0) >= 18;

  Map<String, dynamic> toJson() => {
        'document_id': documentId,
        'user_id': userId,
        'document_type': documentType,
        'front_image_url': frontImageUrl,
        'back_image_url': backImageUrl,
        'extracted_full_name': extractedFullName,
        'extracted_document_number': extractedDocumentNumber,
        'extracted_date_of_birth': extractedDateOfBirth?.toIso8601String(),
        'extracted_expiry_date': extractedExpiryDate?.toIso8601String(),
        'extracted_nationality': extractedNationality,
        'ocr_confidence': ocrConfidence,
        'mrz_valid': mrzValid,
        'checksum_valid': checksumValid,
        'captured_at': capturedAt.toIso8601String(),
      };

  factory IdDocumentModel.fromJson(Map<String, dynamic> json) {
    return IdDocumentModel(
      documentId: json['document_id'] ?? '',
      userId: json['user_id'] ?? '',
      documentType: json['document_type'] ?? '',
      frontImageUrl: json['front_image_url'],
      backImageUrl: json['back_image_url'],
      extractedFullName: json['extracted_full_name'],
      extractedDocumentNumber: json['extracted_document_number'],
      extractedDateOfBirth: json['extracted_date_of_birth'] != null
          ? DateTime.tryParse(json['extracted_date_of_birth'])
          : null,
      extractedExpiryDate: json['extracted_expiry_date'] != null
          ? DateTime.tryParse(json['extracted_expiry_date'])
          : null,
      extractedNationality: json['extracted_nationality'],
      ocrConfidence: (json['ocr_confidence'] as num?)?.toDouble() ?? 0.0,
      mrzValid: json['mrz_valid'] ?? false,
      checksumValid: json['checksum_valid'] ?? false,
      capturedAt: DateTime.tryParse(json['captured_at'] ?? '') ?? DateTime.now(),
    );
  }

  IdDocumentModel copyWith({
    String? frontImageUrl,
    String? backImageUrl,
    String? extractedFullName,
    String? extractedDocumentNumber,
    DateTime? extractedDateOfBirth,
    DateTime? extractedExpiryDate,
    String? extractedNationality,
    double? ocrConfidence,
    bool? mrzValid,
    bool? checksumValid,
  }) {
    return IdDocumentModel(
      documentId: documentId,
      userId: userId,
      documentType: documentType,
      frontImageUrl: frontImageUrl ?? this.frontImageUrl,
      backImageUrl: backImageUrl ?? this.backImageUrl,
      extractedFullName: extractedFullName ?? this.extractedFullName,
      extractedDocumentNumber: extractedDocumentNumber ?? this.extractedDocumentNumber,
      extractedDateOfBirth: extractedDateOfBirth ?? this.extractedDateOfBirth,
      extractedExpiryDate: extractedExpiryDate ?? this.extractedExpiryDate,
      extractedNationality: extractedNationality ?? this.extractedNationality,
      ocrConfidence: ocrConfidence ?? this.ocrConfidence,
      mrzValid: mrzValid ?? this.mrzValid,
      checksumValid: checksumValid ?? this.checksumValid,
      capturedAt: capturedAt,
    );
  }
}
