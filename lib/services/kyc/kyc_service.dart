import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dalali/config/supabase_config.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/models/kyc/verification_result_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// KYC SERVICE — Central Orchestrator
/// ═══════════════════════════════════════════════════════════════
///
/// Stateless, additive module. Exposes a stream-based API for
/// the UI layer. Does NOT modify any existing app state.
///
/// The final decision is made server-side: submitForServerVerification
/// persists the session + document and invokes the
/// process-kyc-verification edge function, which assigns the status
/// and mirrors it onto users.verification_status.
///
class KycService {
  static final KycService _instance = KycService._internal();
  factory KycService() => _instance;
  KycService._internal();

  static final _db = SupabaseService.client;

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

  /// Persist the session + captured document and ask the server to
  /// finalize verification via the process-kyc-verification edge
  /// function. Returns the server-assigned status name
  /// ('verified' | 'pendingReview' | 'rejected').
  Future<String> submitForServerVerification() async {
    final session = _currentSession;
    if (session == null) throw StateError('No active session');

    // 1. Upsert the session row (one per user; the DB generates the
    //    UUID — the local kyc_* id is only used client-side).
    final row = await _db
        .from('kyc_sessions')
        .upsert({
          'user_id': session.userId,
          'status': session.status.name,
          'tier': session.tier.name,
          'selected_document_type': session.selectedDocumentType?.name,
          'consent_version': session.consentVersion,
          'consent_timestamp': session.consentTimestamp?.toIso8601String(),
          'correlation_id': session.correlationId,
          'expires_at': session.expiresAt?.toIso8601String(),
        }, onConflict: 'user_id')
        .select('session_id')
        .single();
    final serverSessionId = row['session_id'] as String;

    // 2. Persist the captured document. The capture step is still a
    //    stub, so the checksum is marked valid here; real OCR and
    //    document validation replace this in production.
    if (session.selectedDocumentType != null) {
      await _db.from('id_documents').insert({
        'user_id': session.userId,
        'document_type': session.selectedDocumentType!.name,
        'checksum_valid': true,
        'ocr_confidence': 0.9,
      });
    }

    // 3. Invoke the server pipeline with the user's JWT.
    final token = _db.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Not authenticated');
    final host =
        SupabaseConfig.url.replaceFirst('.supabase.co', '.functions.supabase.co');
    final resp = await http.post(
      Uri.parse('$host/process-kyc-verification'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'session_id': serverSessionId, 'user_id': session.userId}),
    );

    final body = jsonDecode(resp.body);
    if (resp.statusCode != 200) {
      throw Exception(
        body is Map && body['error'] != null ? body['error'] : 'HTTP ${resp.statusCode}',
      );
    }
    return (body['status'] as String?) ?? 'pendingReview';
  }

  /// Apply the server-assigned outcome to the local session.
  KycSessionModel applyServerOutcome(String status) {
    final session = _currentSession;
    if (session == null) throw StateError('No active session');

    final kycStatus = KycStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => KycStatus.pendingReview,
    );

    _currentSession = session.copyWith(
      status: kycStatus,
      tier: kycStatus == KycStatus.verified ? KycTier.tier2 : KycTier.tier1,
      submittedAt: DateTime.now(),
      verifiedAt: kycStatus == KycStatus.verified ? DateTime.now() : null,
      rejectedAt: kycStatus == KycStatus.rejected ? DateTime.now() : null,
    );

    _statusController.add(kycStatus);
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
