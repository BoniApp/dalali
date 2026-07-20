import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/services/kyc/liveness_service.dart';
import 'package:dalali/screens/kyc/verification_pending_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// LIVENESS CHECK SCREEN — Proof of Life
/// ═══════════════════════════════════════════════════════════════
///
/// Two-step active proof of life, captured LIVE with the front
/// camera (gallery picks are not offered — stored photos are the
/// spoof vector this step exists to defeat):
///
///   1. Plain selfie.
///   2. Random challenge (smile / turn head / blink) + second selfie.
///
/// Both captures must complete within [LivenessService.maxElapsed].
/// The evidence is evaluated by LivenessService and recorded on the
/// KYC session; the verification pipeline gates on that result.
///
class LivenessCheckScreen extends StatefulWidget {
  final String userId;
  final String documentImagePath;

  const LivenessCheckScreen({
    super.key,
    required this.userId,
    required this.documentImagePath,
  });

  @override
  State<LivenessCheckScreen> createState() => _LivenessCheckScreenState();
}

class _LivenessCheckScreenState extends State<LivenessCheckScreen> {
  final _picker = ImagePicker();
  late final DateTime _startedAt;
  late final LivenessChallenge _challenge;

  String? _selfiePath;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    _challenge = LivenessChallenge.values[Random().nextInt(LivenessChallenge.values.length)];
  }

  /// Capture a selfie with the FRONT camera. Returns null if the
  /// user cancelled or no camera is available.
  Future<String?> _captureLive() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 1024,
        imageQuality: 85,
      );
      return picked?.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _capturePlainSelfie() async {
    setState(() => _capturing = true);
    final path = await _captureLive();
    if (!mounted) return;
    setState(() {
      _capturing = false;
      if (path != null) _selfiePath = path;
    });
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo captured. Please use the camera to take a live selfie.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Future<void> _captureChallengeSelfie() async {
    setState(() => _capturing = true);
    final path = await _captureLive();
    if (!mounted) return;
    setState(() => _capturing = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No photo captured. Please perform the challenge and retake.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final kyc = KycService();
    final session = kyc.currentSession;
    if (session == null) return;

    final result = LivenessService().evaluateProofOfLife(
      proof: LivenessProof(
        selfiePath: _selfiePath!,
        challengeSelfiePath: path,
        challenge: _challenge,
        elapsed: DateTime.now().difference(_startedAt),
      ),
      sessionId: session.sessionId,
    );
    kyc.recordLivenessResult(result);

    if (!mounted) return;

    if (!result.isSuccessful) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Verification Failed'),
          content: const Text(
            'We could not confirm your proof of life. Please ensure good lighting and complete the challenge within the time limit.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _selfiePath = null);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationPendingScreen(userId: widget.userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stepTwo = _selfiePath != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Proof of Life')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  stepTwo ? _challengeIcon(_challenge) : Icons.face,
                  size: 80,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                stepTwo ? 'Now: ${_challengeLabel(_challenge)}' : 'Take a Selfie',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                stepTwo
                    ? '${_challengeHint(_challenge)} Then take a second selfie with the front camera.'
                    : 'Position your face inside the circle. Make sure your face is well lit and clearly visible.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Step ${stepTwo ? 2 : 1} of 2',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _capturing
                    ? null
                    : (stepTwo ? _captureChallengeSelfie : _capturePlainSelfie),
                icon: const Icon(Icons.camera_front),
                label: Text(_capturing
                    ? 'Opening camera...'
                    : (stepTwo ? 'Capture Challenge Selfie' : 'Capture Selfie')),
              ),
              if (_capturing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  IconData _challengeIcon(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.smile:
        return Icons.sentiment_satisfied_alt;
      case LivenessChallenge.turnLeft:
        return Icons.arrow_back;
      case LivenessChallenge.turnRight:
        return Icons.arrow_forward;
      case LivenessChallenge.blink:
        return Icons.visibility;
    }
  }

  String _challengeLabel(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.smile:
        return 'Smile';
      case LivenessChallenge.turnLeft:
        return 'Turn your head LEFT';
      case LivenessChallenge.turnRight:
        return 'Turn your head RIGHT';
      case LivenessChallenge.blink:
        return 'Blink your eyes';
    }
  }

  String _challengeHint(LivenessChallenge c) {
    switch (c) {
      case LivenessChallenge.smile:
        return 'Show a big, natural smile.';
      case LivenessChallenge.turnLeft:
        return 'Slowly turn your head to your left.';
      case LivenessChallenge.turnRight:
        return 'Slowly turn your head to your right.';
      case LivenessChallenge.blink:
        return 'Blink a few times, then hold still.';
    }
  }
}
