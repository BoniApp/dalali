import 'package:flutter/material.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/services/kyc/liveness_service.dart';
import 'package:dalali/screens/kyc/verification_pending_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// LIVENESS CHECK SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Guides user through a selfie capture for liveness detection
/// and face matching against the captured ID document.
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
  bool _checking = false;

  Future<void> _runLiveness() async {
    setState(() => _checking = true);

    final liveness = LivenessService();
    final kyc = KycService();
    final session = kyc.currentSession;

    if (session == null) {
      setState(() => _checking = false);
      return;
    }

    // Passive liveness + face match
    final result = await liveness.runFullLivenessCheck(
      documentPhotoUrl: widget.documentImagePath,
      selfieImagePath: '/mock/selfie.jpg',
      sessionId: session.sessionId,
    );

    setState(() => _checking = false);

    if (!result.isSuccessful) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Verification Failed'),
            content: const Text('We could not confirm your liveness. Please ensure good lighting and try again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Proceed to final verification screen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationPendingScreen(userId: widget.userId),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Liveness Check')),
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
                  color: Colors.teal.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.face, size: 80, color: Colors.teal),
              ),
              const SizedBox(height: 24),
              const Text(
                'Take a Selfie',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'Position your face inside the circle. Make sure your face is well lit and clearly visible.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _checking ? null : _runLiveness,
                icon: const Icon(Icons.camera_front),
                label: Text(_checking ? 'Verifying...' : 'Capture Selfie'),
              ),
              if (_checking) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
