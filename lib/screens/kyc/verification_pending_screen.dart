import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/screens/kyc/kyc_status_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// VERIFICATION PENDING SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Hands the session to the server pipeline
/// (process-kyc-verification): the edge function verifies NIDA
/// documents or routes other documents (voter's ID, driver's
/// licence, passport, ZanID) to manual review, then mirrors the
/// outcome onto users.verification_status.
///
class VerificationPendingScreen extends StatefulWidget {
  final String userId;

  const VerificationPendingScreen({super.key, required this.userId});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  String _statusMessage = 'Submitting your documents...';
  bool _done = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _runVerificationPipeline();
  }

  Future<void> _runVerificationPipeline() async {
    final kyc = KycService();
    final session = kyc.currentSession;
    if (session == null) return;

    try {
      final status = await kyc.submitForServerVerification();

      setState(() => _statusMessage = 'Finalizing verification...');
      final finalSession = kyc.applyServerOutcome(status);

      // Refresh the signed-in user so the profile badge and the
      // withdrawal gate reflect the new status immediately.
      if (mounted) {
        try {
          await context.read<AppState>().refreshCurrentUser();
        } catch (_) {}
      }

      setState(() {
        _statusMessage = finalSession.status.name;
        _done = true;
      });

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => KycStatusScreen(session: finalSession),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _failed = true;
        _statusMessage = 'Verification could not be completed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_failed)
                  const Icon(Icons.error_outline, size: 64, color: Colors.red)
                else if (!_done)
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  _failed
                      ? 'Something went wrong'
                      : _done
                          ? 'Verification Complete'
                          : 'Verifying...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                if (_failed) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
