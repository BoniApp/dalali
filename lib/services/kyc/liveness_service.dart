import 'package:dalali/models/kyc/verification_result_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// LIVENESS SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Abstraction over native liveness detection SDKs.
/// Supports both passive (blink detection) and active
/// (challenge-response) modes.
///
/// In production, integrate:
///   • Google ML Kit Face Detection
///   • AWS Rekognition Face Liveness
///   • Or a custom TFLite model
///
class LivenessService {
  static const double _livenessThreshold = 0.92;
  static const double _faceMatchThreshold = 0.85;

  /// Run passive liveness detection on a selfie.
  /// Returns confidence score 0.0–1.0
  Future<double> detectPassiveLiveness(String imagePath) async {
    // Stub: in production, analyze eye aspect ratio, depth, texture
    return 0.96;
  }

  /// Run active liveness challenge.
  /// Challenges: turn left, turn right, smile, blink.
  Future<LivenessChallengeResult> runActiveChallenge({
    required List<String> videoFramePaths,
    required List<String> expectedActions,
  }) async {
    // Stub: in production, compare frame sequence against expected actions
    return LivenessChallengeResult(
      allActionsDetected: true,
      confidence: 0.94,
    );
  }

  /// Compare document photo against selfie using face embedding.
  Future<VerificationResultModel> matchFace({
    required String documentPhotoUrl,
    required String selfieImagePath,
    required String sessionId,
  }) async {
    // Stub: in production, compute face embedding cosine similarity
    const similarity = 0.91;
    final matched = similarity >= _faceMatchThreshold;

    return VerificationResultModel(
      resultId: 'face_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      source: 'face_match',
      outcome: matched ? VerificationOutcome.match : VerificationOutcome.mismatch,
      matchScore: similarity,
      checkedAt: DateTime.now(),
    );
  }

  /// Full liveness + face-match pipeline.
  Future<VerificationResultModel> runFullLivenessCheck({
    required String documentPhotoUrl,
    required String selfieImagePath,
    required String sessionId,
  }) async {
    final livenessScore = await detectPassiveLiveness(selfieImagePath);
    if (livenessScore < _livenessThreshold) {
      return VerificationResultModel(
        resultId: 'liveness_${DateTime.now().millisecondsSinceEpoch}',
        sessionId: sessionId,
        source: 'liveness_check',
        outcome: VerificationOutcome.mismatch,
        matchScore: livenessScore,
        flags: ['LIVENESS_FAILED'],
        checkedAt: DateTime.now(),
      );
    }

    return matchFace(
      documentPhotoUrl: documentPhotoUrl,
      selfieImagePath: selfieImagePath,
      sessionId: sessionId,
    );
  }
}

class LivenessChallengeResult {
  final bool allActionsDetected;
  final double confidence;

  const LivenessChallengeResult({
    required this.allActionsDetected,
    required this.confidence,
  });
}
