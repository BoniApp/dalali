import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/kyc/verification_result_model.dart';
import 'package:dalali/services/kyc/liveness_service.dart';

void main() {
  final service = LivenessService();

  LivenessProof proof({
    String selfie = '/data/selfie1.jpg',
    String challengeSelfie = '/data/selfie2.jpg',
    LivenessChallenge challenge = LivenessChallenge.smile,
    Duration elapsed = const Duration(seconds: 20),
  }) =>
      LivenessProof(
        selfiePath: selfie,
        challengeSelfiePath: challengeSelfie,
        challenge: challenge,
        elapsed: elapsed,
      );

  group('LivenessService.evaluateProofOfLife', () {
    test('passes with two distinct live captures inside the time window', () {
      final result = service.evaluateProofOfLife(proof: proof(), sessionId: 's1');
      expect(result.isSuccessful, isTrue);
      expect(result.outcome, VerificationOutcome.match);
      expect(result.flags, contains('PROOF_OF_LIFE_CAPTURED'));
      expect(result.flags, contains('CHALLENGE_SMILE'));
    });

    test('fails when a capture is missing', () {
      final result = service.evaluateProofOfLife(
        proof: proof(challengeSelfie: ''),
        sessionId: 's1',
      );
      expect(result.isSuccessful, isFalse);
      expect(result.flags, containsAll(['LIVENESS_FAILED', 'MISSING_CAPTURE']));
    });

    test('fails when both captures are the same image', () {
      final result = service.evaluateProofOfLife(
        proof: proof(challengeSelfie: '/data/selfie1.jpg'),
        sessionId: 's1',
      );
      expect(result.isSuccessful, isFalse);
      expect(result.flags, contains('DUPLICATE_CAPTURE'));
    });

    test('fails when the sequence exceeds the time window', () {
      final result = service.evaluateProofOfLife(
        proof: proof(elapsed: LivenessService.maxElapsed + const Duration(seconds: 1)),
        sessionId: 's1',
      );
      expect(result.isSuccessful, isFalse);
      expect(result.flags, contains('CHALLENGE_EXPIRED'));
    });

    test('passes exactly at the time limit', () {
      final result = service.evaluateProofOfLife(
        proof: proof(elapsed: LivenessService.maxElapsed),
        sessionId: 's1',
      );
      expect(result.isSuccessful, isTrue);
    });
  });
}
