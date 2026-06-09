import 'package:flutter/material.dart';
import 'package:dalali/models/kyc/verification_result_model.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/services/kyc/nida_integration_service.dart';
import 'package:dalali/services/kyc/aml_screening_service.dart';
import 'package:dalali/screens/kyc/kyc_status_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// VERIFICATION PENDING SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Orchestrates the backend verification pipeline:
/// NIDA API → AML Screening → Risk Scoring → Status Assignment.
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

  @override
  void initState() {
    super.initState();
    _runVerificationPipeline();
  }

  Future<void> _runVerificationPipeline() async {
    final kyc = KycService();
    final session = kyc.currentSession;
    if (session == null) return;

    // Step 1: NIDA API verification (stub)
    setState(() => _statusMessage = 'Verifying with NIDA...');
    await Future.delayed(const Duration(seconds: 2));
    final nidaResult = await NidaIntegrationService().verifyIdentity(
      nin: '12345678901234567890',
      dateOfBirth: DateTime(1990, 5, 15),
      correlationId: session.correlationId ?? '',
      verificationReason: 'fintech_onboarding',
    );

    // Step 2: AML screening (stub)
    setState(() => _statusMessage = 'Running security checks...');
    await Future.delayed(const Duration(seconds: 1));
    final amlResult = await AmlScreeningService().screenName(
      fullName: 'John Doe',
      dateOfBirth: '1990-05-15',
      sessionId: session.sessionId,
    );

    // Step 3: Finalize
    final finalSession = await kyc.finalize(
      nidaMatch: nidaResult.isSuccessful,
      livenessPass: true,
      amlClear: amlResult.isSuccessful,
      riskLevel: amlResult.assessedRisk ?? RiskLevel.low,
    );

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
                if (!_done)
                  const SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  const Icon(Icons.check_circle, size: 64, color: Colors.green),
                const SizedBox(height: 24),
                Text(
                  _done ? 'Verification Complete' : 'Verifying...',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
