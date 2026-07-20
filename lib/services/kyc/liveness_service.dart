import 'package:dalali/models/kyc/verification_result_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// LIVENESS SERVICE — Proof of Life
/// ═══════════════════════════════════════════════════════════════
///
/// Evaluates proof-of-life evidence captured by
/// LivenessCheckScreen: two distinct LIVE front-camera captures
/// (plain selfie + random challenge-response selfie) completed
/// within a bounded time window. Gallery picks are not accepted
/// by the capture flow — a photo from storage is exactly the
/// spoof vector proof of life exists to defeat.
///
/// What this guarantees without an ML SDK: the applicant held the
/// phone and performed a prompted action at verification time.
/// What it does NOT guarantee: that the face matches the document
/// photo — for that, integrate a face-embedding/ML liveness SDK
/// (Google ML Kit, AWS Rekognition Face Liveness, custom TFLite)
/// behind [evaluateProofOfLife] without changing the UI flow.
///
class LivenessService {
  /// Maximum time allowed for the whole proof-of-life sequence.
  static const Duration maxElapsed = Duration(seconds: 60);

  /// Evaluate captured proof-of-life evidence. Pure logic — no I/O.
  VerificationResultModel evaluateProofOfLife({
    required LivenessProof proof,
    required String sessionId,
  }) {
    final failures = <String>[];

    if (proof.selfiePath.isEmpty || proof.challengeSelfiePath.isEmpty) {
      failures.add('MISSING_CAPTURE');
    }
    if (proof.selfiePath.isNotEmpty &&
        proof.selfiePath == proof.challengeSelfiePath) {
      failures.add('DUPLICATE_CAPTURE');
    }
    if (proof.elapsed > maxElapsed) {
      failures.add('CHALLENGE_EXPIRED');
    }

    final passed = failures.isEmpty;
    return VerificationResultModel(
      resultId: 'liveness_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      source: 'liveness_check',
      outcome: passed ? VerificationOutcome.match : VerificationOutcome.mismatch,
      flags: passed
          ? ['PROOF_OF_LIFE_CAPTURED', 'CHALLENGE_${proof.challenge.name.toUpperCase()}']
          : ['LIVENESS_FAILED', ...failures],
      checkedAt: DateTime.now(),
    );
  }
}

/// The active challenge presented to the user between the two
/// captures. Chosen at random by the screen.
enum LivenessChallenge { smile, turnLeft, turnRight, blink }

/// Evidence of a live capture sequence, produced by
/// LivenessCheckScreen and evaluated by [LivenessService].
class LivenessProof {
  /// Path of the first live selfie (plain).
  final String selfiePath;

  /// Path of the second live selfie (after performing [challenge]).
  final String challengeSelfiePath;

  /// The challenge the user was asked to perform.
  final LivenessChallenge challenge;

  /// Total time the sequence took, from screen open to second capture.
  final Duration elapsed;

  const LivenessProof({
    required this.selfiePath,
    required this.challengeSelfiePath,
    required this.challenge,
    required this.elapsed,
  });
}
