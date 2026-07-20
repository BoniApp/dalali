import 'package:flutter/material.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/screens/kyc/consent_screen.dart';
import 'package:dalali/screens/kyc/kyc_status_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// KYC GATE SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Entry gate. Checks if user needs KYC and routes accordingly.
/// Zero modifications to existing navigation or state.
///
class KycGateScreen extends StatelessWidget {
  final String userId;

  const KycGateScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<KycSessionModel?>(
        future: _resolveSession(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final session = snapshot.data;

          // Already verified and valid
          if (session != null &&
              session.isVerified &&
              KycService().isSessionValid(session)) {
            return KycStatusScreen(session: session);
          }

          // In progress — resume
          if (session != null && session.status == KycStatus.inProgress) {
            return ConsentScreen(userId: userId);
          }

          // Pending review
          if (session != null && session.status == KycStatus.pendingReview) {
            return KycStatusScreen(session: session);
          }

          // Rejected or expired — restart
          return ConsentScreen(userId: userId);
        },
      ),
    );
  }

  Future<KycSessionModel?> _resolveSession() async {
    // Prefer the persisted session (survives restarts); fall back
    // to the in-memory one mid-flow.
    try {
      final row = await DataService().getKycSessionByUser(userId);
      if (row != null) {
        return KycSessionModel.fromJson(Map<String, dynamic>.from(row as Map));
      }
    } catch (_) {}
    return KycService().currentSession;
  }
}
