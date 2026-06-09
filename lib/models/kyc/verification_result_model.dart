/// ═══════════════════════════════════════════════════════════════
/// VERIFICATION RESULT MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Result of a verification attempt against an external authority
/// (NIDA, TRA, sanctions list, etc.).
///
enum VerificationOutcome { match, mismatch, notFound, deceased, error, timeout }
enum RiskLevel { low, medium, high, critical }

class VerificationResultModel {
  final String resultId;
  final String sessionId;
  final String source; // "nida_api", "tra_api", "sanctions_list", "liveness_check"
  final VerificationOutcome outcome;
  final double? matchScore;
  final String? matchedName;
  final String? matchedDateOfBirth;
  final String? apiResponseCode;
  final String? apiResponseBody;
  final RiskLevel? assessedRisk;
  final List<String> flags;
  final DateTime checkedAt;

  const VerificationResultModel({
    required this.resultId,
    required this.sessionId,
    required this.source,
    required this.outcome,
    this.matchScore,
    this.matchedName,
    this.matchedDateOfBirth,
    this.apiResponseCode,
    this.apiResponseBody,
    this.assessedRisk,
    this.flags = const [],
    required this.checkedAt,
  });

  bool get isSuccessful => outcome == VerificationOutcome.match;
  bool get requiresManualReview =>
      outcome == VerificationOutcome.error ||
      outcome == VerificationOutcome.timeout ||
      (assessedRisk != null && assessedRisk!.index >= RiskLevel.high.index);

  Map<String, dynamic> toJson() => {
        'result_id': resultId,
        'session_id': sessionId,
        'source': source,
        'outcome': outcome.name,
        'match_score': matchScore,
        'matched_name': matchedName,
        'matched_date_of_birth': matchedDateOfBirth,
        'api_response_code': apiResponseCode,
        'api_response_body': apiResponseBody,
        'assessed_risk': assessedRisk?.name,
        'flags': flags,
        'checked_at': checkedAt.toIso8601String(),
      };

  factory VerificationResultModel.fromJson(Map<String, dynamic> json) {
    return VerificationResultModel(
      resultId: json['result_id'] ?? '',
      sessionId: json['session_id'] ?? '',
      source: json['source'] ?? '',
      outcome: VerificationOutcome.values.firstWhere(
        (e) => e.name == json['outcome'],
        orElse: () => VerificationOutcome.error,
      ),
      matchScore: (json['match_score'] as num?)?.toDouble(),
      matchedName: json['matched_name'],
      matchedDateOfBirth: json['matched_date_of_birth'],
      apiResponseCode: json['api_response_code'],
      apiResponseBody: json['api_response_body'],
      assessedRisk: json['assessed_risk'] != null
          ? RiskLevel.values.firstWhere(
              (e) => e.name == json['assessed_risk'],
              orElse: () => RiskLevel.medium,
            )
          : null,
      flags: List<String>.from(json['flags'] ?? []),
      checkedAt: DateTime.tryParse(json['checked_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// KYC AUDIT LOG MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Immutable audit entry for every action in the KYC pipeline.
/// Required for BoT 7-year record keeping.
///
class KycAuditLogModel {
  final String logId;
  final String sessionId;
  final String userId;
  final String action;
  final String? ipAddress;
  final String? deviceHash;
  final String? correlationId;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  const KycAuditLogModel({
    required this.logId,
    required this.sessionId,
    required this.userId,
    required this.action,
    this.ipAddress,
    this.deviceHash,
    this.correlationId,
    this.metadata,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'log_id': logId,
        'session_id': sessionId,
        'user_id': userId,
        'action': action,
        'ip_address': ipAddress,
        'device_hash': deviceHash,
        'correlation_id': correlationId,
        'metadata': metadata,
        'timestamp': timestamp.toIso8601String(),
      };
}
