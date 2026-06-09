/// ═══════════════════════════════════════════════════════════════
/// KYC SESSION MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Tracks the complete KYC onboarding session for a user.
/// Immutable audit trail for every step.
///
enum KycStatus { unverified, inProgress, pendingReview, verified, rejected, expired }
enum IdDocumentType { nidaId, passport, driversLicense, zanId, votersId }
enum KycTier { tier0, tier1, tier2, tier2Plus }

class KycSessionModel {
  final String sessionId;
  final String userId;
  final KycStatus status;
  final KycTier tier;
  final IdDocumentType? selectedDocumentType;
  final String? consentVersion;
  final DateTime? consentTimestamp;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;
  final DateTime? rejectedAt;
  final String? rejectionReason;
  final String? correlationId;
  final String? deviceFingerprint;
  final DateTime createdAt;
  final DateTime? expiresAt;

  const KycSessionModel({
    required this.sessionId,
    required this.userId,
    this.status = KycStatus.unverified,
    this.tier = KycTier.tier0,
    this.selectedDocumentType,
    this.consentVersion,
    this.consentTimestamp,
    this.submittedAt,
    this.verifiedAt,
    this.rejectedAt,
    this.rejectionReason,
    this.correlationId,
    this.deviceFingerprint,
    required this.createdAt,
    this.expiresAt,
  });

  bool get isVerified => status == KycStatus.verified;
  bool get canListProperties => tier.index >= KycTier.tier2.index;
  bool get canEarnAgencyFees => tier.index >= KycTier.tier2.index;

  Map<String, dynamic> toJson() => {
        'session_id': sessionId,
        'user_id': userId,
        'status': status.name,
        'tier': tier.name,
        'selected_document_type': selectedDocumentType?.name,
        'consent_version': consentVersion,
        'consent_timestamp': consentTimestamp?.toIso8601String(),
        'submitted_at': submittedAt?.toIso8601String(),
        'verified_at': verifiedAt?.toIso8601String(),
        'rejected_at': rejectedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
        'correlation_id': correlationId,
        'device_fingerprint': deviceFingerprint,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      };

  factory KycSessionModel.fromJson(Map<String, dynamic> json) {
    return KycSessionModel(
      sessionId: json['session_id'] ?? '',
      userId: json['user_id'] ?? '',
      status: KycStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => KycStatus.unverified,
      ),
      tier: KycTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => KycTier.tier0,
      ),
      selectedDocumentType: json['selected_document_type'] != null
          ? IdDocumentType.values.firstWhere(
              (e) => e.name == json['selected_document_type'],
              orElse: () => IdDocumentType.nidaId,
            )
          : null,
      consentVersion: json['consent_version'],
      consentTimestamp: json['consent_timestamp'] != null
          ? DateTime.tryParse(json['consent_timestamp'])
          : null,
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'])
          : null,
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'])
          : null,
      rejectionReason: json['rejection_reason'],
      correlationId: json['correlation_id'],
      deviceFingerprint: json['device_fingerprint'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
    );
  }

  KycSessionModel copyWith({
    KycStatus? status,
    KycTier? tier,
    IdDocumentType? selectedDocumentType,
    String? consentVersion,
    DateTime? consentTimestamp,
    DateTime? submittedAt,
    DateTime? verifiedAt,
    DateTime? rejectedAt,
    String? rejectionReason,
    String? correlationId,
    String? deviceFingerprint,
    DateTime? expiresAt,
  }) {
    return KycSessionModel(
      sessionId: sessionId,
      userId: userId,
      status: status ?? this.status,
      tier: tier ?? this.tier,
      selectedDocumentType: selectedDocumentType ?? this.selectedDocumentType,
      consentVersion: consentVersion ?? this.consentVersion,
      consentTimestamp: consentTimestamp ?? this.consentTimestamp,
      submittedAt: submittedAt ?? this.submittedAt,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      correlationId: correlationId ?? this.correlationId,
      deviceFingerprint: deviceFingerprint ?? this.deviceFingerprint,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
