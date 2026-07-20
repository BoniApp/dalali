import 'dart:async';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/models/kyc/id_document_model.dart';
import 'package:dalali/models/kyc/verification_result_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// KYC SERVICE — Central Orchestrator
/// ═══════════════════════════════════════════════════════════════
///
/// Stateless, additive module. Exposes a stream-based API for
/// the UI layer. Does NOT modify any existing app state.
///
class KycService {
  static final KycService _instance = KycService._internal();
  factory KycService() => _instance;
  KycService._internal();

  final _statusController = StreamController<KycStatus>.broadcast();
  Stream<KycStatus> get onStatusChanged => _statusController.stream;

  KycSessionModel? _currentSession;
  KycSessionModel? get currentSession => _currentSession;

  VerificationResultModel? _livenessResult;

  /// Outcome of the proof-of-life check for the current session.
  /// Null until LivenessCheckScreen records a result.
  VerificationResultModel? get livenessResult => _livenessResult;

  /// Record the proof-of-life outcome for the current session.
  void recordLivenessResult(VerificationResultModel result) {
    _livenessResult = result;
  }

  /// Initialize or resume a KYC session for a user.
  Future<KycSessionModel> startSession(String userId) async {
    final session = KycSessionModel(
      sessionId: 'kyc_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      status: KycStatus.inProgress,
      correlationId: _generateCorrelationId(),
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    _currentSession = session;
    _statusController.add(session.status);
    return session;
  }

  /// Record explicit consent per PDPA 2022.
  Future<void> recordConsent(String consentVersion) async {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(
      consentVersion: consentVersion,
      consentTimestamp: DateTime.now(),
    );
  }

  /// Advance session after document type selection.
  Future<void> selectDocumentType(IdDocumentType type) async {
    if (_currentSession == null) return;
    _currentSession = _currentSession!.copyWith(
      selectedDocumentType: type,
    );
  }

  /// Submit a captured document for validation.
  Future<IdDocumentModel> submitDocument(IdDocumentModel document) async {
    // In production: persist to Supabase, trigger OCR pipeline
    // For now, return the document as-is (stub)
    return document;
  }

  /// Finalize verification and assign tier.
  Future<KycSessionModel> finalize({
    required bool nidaMatch,
    required bool livenessPass,
    required bool amlClear,
    required RiskLevel riskLevel,
  }) async {
    if (_currentSession == null) throw StateError('No active session');

    KycStatus newStatus;
    KycTier newTier;

    if (!nidaMatch || !livenessPass) {
      newStatus = KycStatus.rejected;
      newTier = KycTier.tier1;
    } else if (!amlClear || riskLevel.index >= RiskLevel.high.index) {
      newStatus = KycStatus.pendingReview;
      newTier = KycTier.tier1;
    } else {
      newStatus = KycStatus.verified;
      newTier = KycTier.tier2;
    }

    _currentSession = _currentSession!.copyWith(
      status: newStatus,
      tier: newTier,
      submittedAt: DateTime.now(),
      verifiedAt: newStatus == KycStatus.verified ? DateTime.now() : null,
      rejectedAt: newStatus == KycStatus.rejected ? DateTime.now() : null,
    );

    _statusController.add(newStatus);
    return _currentSession!;
  }

  /// Submit the session for manual review.
  ///
  /// Used for document types with no instant verification API in
  /// Tanzania (voter's ID, driver's licence, passport, ZanID) — a
  /// reviewer verifies the captured document manually. Liveness has
  /// already passed by this point in the flow.
  Future<KycSessionModel> submitForManualReview() async {
    if (_currentSession == null) throw StateError('No active session');
    _currentSession = _currentSession!.copyWith(
      status: KycStatus.pendingReview,
      submittedAt: DateTime.now(),
    );
    _statusController.add(KycStatus.pendingReview);
    return _currentSession!;
  }

  /// Check if an existing session is still valid (not expired).
  bool isSessionValid(KycSessionModel session) {
    if (session.expiresAt == null) return true;
    return DateTime.now().isBefore(session.expiresAt!);
  }

  String _generateCorrelationId() {
    return 'corr_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().millisecond).toString().padLeft(4, '0')}';
  }

  void dispose() {
    _statusController.close();
  }
}
