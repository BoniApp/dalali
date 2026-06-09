import 'package:flutter/material.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/screens/kyc/kyc_gate_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// KYC STATUS SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Displays the final KYC result to the user.
/// Shows stored verification data for transparency (PDPA right of access).
///
class KycStatusScreen extends StatelessWidget {
  final KycSessionModel session;

  const KycStatusScreen({super.key, required this.session});

  Color get _statusColor {
    switch (session.status) {
      case KycStatus.verified:
        return Colors.green;
      case KycStatus.pendingReview:
        return Colors.orange;
      case KycStatus.rejected:
        return Colors.red;
      case KycStatus.expired:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData get _statusIcon {
    switch (session.status) {
      case KycStatus.verified:
        return Icons.verified_user;
      case KycStatus.pendingReview:
        return Icons.hourglass_top;
      case KycStatus.rejected:
        return Icons.cancel;
      case KycStatus.expired:
        return Icons.timelapse;
      default:
        return Icons.info;
    }
  }

  String get _statusMessage {
    switch (session.status) {
      case KycStatus.verified:
        return 'Your identity has been verified. You can now list properties and earn agency fees.';
      case KycStatus.pendingReview:
        return 'Your verification is under manual review. We will notify you within 24 hours.';
      case KycStatus.rejected:
        return 'We could not verify your identity. ${session.rejectionReason ?? 'Please contact support for assistance.'}';
      case KycStatus.expired:
        return 'Your verification has expired. Please re-verify to continue.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification Status')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _statusColor.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: Icon(_statusIcon, size: 56, color: _statusColor),
              ),
              const SizedBox(height: 24),
              Text(
                session.status.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _statusColor,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 32),
              _InfoCard(
                title: 'Verification Tier',
                value: session.tier.name.toUpperCase(),
              ),
              _InfoCard(
                title: 'Verified At',
                value: session.verifiedAt?.toLocal().toString() ?? 'N/A',
              ),
              _InfoCard(
                title: 'Expires At',
                value: session.expiresAt?.toLocal().toString() ?? 'N/A',
              ),
              _InfoCard(
                title: 'Correlation ID',
                value: session.correlationId ?? 'N/A',
              ),
              const SizedBox(height: 32),
              if (session.status == KycStatus.verified)
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Continue to App'),
                )
              else if (session.status == KycStatus.rejected || session.status == KycStatus.expired)
                FilledButton(
                  onPressed: () {
                    // Restart KYC flow
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => KycGateScreen(userId: session.userId),
                      ),
                    );
                  },
                  child: const Text('Retry Verification'),
                )
              else
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to App'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;

  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
