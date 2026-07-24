import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/payment_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/dpo_payment_service.dart';
import 'package:dalali/screens/wallet/payment_failed_screen.dart';
import 'package:dalali/screens/wallet/payment_success_screen.dart';
import 'package:provider/provider.dart';

/// ═══════════════════════════════════════════════════════════════
/// PAYMENT PENDING SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Shown when DPO hasn't confirmed yet (e.g. the dalali://payment-
/// pending deep link). Watches the payment row — settlement landing
/// via dpo-callback or verify-dpo-payment advances automatically.
class PaymentPendingScreen extends StatelessWidget {
  final PaymentModel payment;
  final String propertyTitle;

  const PaymentPendingScreen({super.key, required this.payment, required this.propertyTitle});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AppState>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Pending'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<PaymentModel?>(
        stream: DpoPaymentService().watchPayment(payment.id),
        builder: (context, snapshot) {
          final current = snapshot.data ?? payment;
          if (current.isPaid) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PaymentSuccessScreen(
                    payment: current,
                    propertyTitle: propertyTitle,
                    tenantName: user?.fullName ?? '',
                  ),
                ),
              );
            });
          } else if (current.status != PaymentStatus.pending) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => PaymentFailedScreen(payment: current)),
              );
            });
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  const Text('Waiting for confirmation…',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'DPO is confirming your payment. This page updates automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
