enum ClaimStatus { pending, approved, rejected }

/// ═══════════════════════════════════════════════════════════════
/// PROPERTY CLAIM MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Used when a user believes they are the rightful owner / lister
/// of a property already in the registry and want to claim
/// listing ownership rights.
///
class PropertyClaimModel {
  final String claimId;
  final String propertyId;
  final String claimantId;
  final String claimantRole;
  final String reason;
  final List<String> evidenceUrls;
  final ClaimStatus status;
  final String? reviewedBy;
  final String? reviewNotes;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const PropertyClaimModel({
    required this.claimId,
    required this.propertyId,
    required this.claimantId,
    required this.claimantRole,
    required this.reason,
    this.evidenceUrls = const [],
    this.status = ClaimStatus.pending,
    this.reviewedBy,
    this.reviewNotes,
    required this.createdAt,
    this.reviewedAt,
  });

  Map<String, dynamic> toJson() => {
        'claim_id': claimId,
        'property_id': propertyId,
        'claimant_id': claimantId,
        'claimant_role': claimantRole,
        'reason': reason,
        'evidence_urls': evidenceUrls,
        'status': status.name,
        'reviewed_by': reviewedBy,
        'review_notes': reviewNotes,
        'created_at': createdAt.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
      };

  factory PropertyClaimModel.fromJson(Map<String, dynamic> json) {
    return PropertyClaimModel(
      claimId: json['claim_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      claimantId: json['claimant_id'] ?? '',
      claimantRole: json['claimant_role'] ?? '',
      reason: json['reason'] ?? '',
      evidenceUrls: List<String>.from(json['evidence_urls'] ?? []),
      status: ClaimStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ClaimStatus.pending,
      ),
      reviewedBy: json['reviewed_by'],
      reviewNotes: json['review_notes'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'])
          : null,
    );
  }

  PropertyClaimModel copyWith({
    ClaimStatus? status,
    String? reviewedBy,
    String? reviewNotes,
    DateTime? reviewedAt,
  }) {
    return PropertyClaimModel(
      claimId: claimId,
      propertyId: propertyId,
      claimantId: claimantId,
      claimantRole: claimantRole,
      reason: reason,
      evidenceUrls: evidenceUrls,
      status: status ?? this.status,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewNotes: reviewNotes ?? this.reviewNotes,
      createdAt: createdAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
    );
  }
}
