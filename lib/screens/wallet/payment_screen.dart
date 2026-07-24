import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/payment_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/dpo_payment_service.dart';
import 'package:dalali/screens/wallet/payment_failed_screen.dart';
import 'package:dalali/screens/wallet/payment_success_screen.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// ═══════════════════════════════════════════════════════════════
/// PAYMENT SCREEN (DPO Pay)
/// ═══════════════════════════════════════════════════════════════
///
/// Agency-fee checkout: summary → mint a DPO token via
/// create-dpo-token → open the hosted payment page in the browser →
/// customer pays → "I've completed payment" verifies and settles via
/// verify-dpo-payment (retry with backoff) → receipt or failure.
class PaymentScreen extends StatefulWidget {
  final PropertyModel property;

  const PaymentScreen({super.key, required this.property});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

enum _Phase { form, awaiting, verifying }

class _PaymentScreenState extends State<PaymentScreen> {
  final _dpo = DpoPaymentService();
  _Phase _phase = _Phase.form;
  String? _paymentUrl;
  String? _token;
  String? _error;

  Future<void> _startPayment() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to proceed with payment')),
      );
      return;
    }
    setState(() {
      _phase = _Phase.verifying;
      _error = null;
    });
    try {
      final result = await _dpo.createToken(widget.property.id);
      _paymentUrl = result.paymentUrl;
      _token = result.token;
      final uri = Uri.parse(result.paymentUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      if (!mounted) return;
      setState(() => _phase = _Phase.awaiting);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.form;
        _error = '$e';
      });
    }
  }

  /// Verify with retry: DPO can take a moment to settle mobile money.
  Future<void> _verifyNow() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _phase = _Phase.verifying;
      _error = null;
    });
    const maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final payment = await _dpo.verify(token);
        if (!mounted) return;
        if (payment.isPaid) {
          _goSuccess(payment);
          return;
        }
        if (payment.status != PaymentStatus.pending) {
          _goFailed(payment);
          return;
        }
        if (attempt < maxAttempts) {
          await Future.delayed(const Duration(seconds: 5));
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.awaiting;
          _error = '$e';
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _phase = _Phase.awaiting;
        _error = 'Not confirmed yet. If you completed the payment, wait a moment and try again.';
      });
    }
  }

  void _goSuccess(PaymentModel payment) {
    final user = context.read<AppState>().currentUser;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentSuccessScreen(
          payment: payment,
          propertyTitle: widget.property.title,
          tenantName: user?.fullName ?? '',
        ),
      ),
    );
  }

  void _goFailed(PaymentModel payment) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentFailedScreen(
          payment: payment,
          onRetry: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => PaymentScreen(property: widget.property)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Agency Fee'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(p.location, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Text(
                      Helpers.formatPrice(p.rentAmount > 0 ? p.rentAmount : p.rentPrice),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primary),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Payment Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _SummaryRow(label: 'Agency Fee', amount: AppSettings.agencyFee),
            _SummaryRow(label: 'Service Charge', amount: 0, isFree: true),
            const Divider(),
            _SummaryRow(label: 'Total to Pay', amount: AppSettings.agencyFee, isTotal: true),
            const SizedBox(height: 8),
            Card(
              color: AppTheme.primary.withAlpha(13),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: AppTheme.primaryDark, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Paying unlocks the landlord\'s contact details for this listing.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ),
            _buildAction(),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Visa · Mastercard · M-Pesa · Airtel Money · Tigo Pesa · Bank',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAction() {
    switch (_phase) {
      case _Phase.verifying:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Contacting DPO…'),
              ],
            ),
          ),
        );
      case _Phase.awaiting:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _verifyNow,
              icon: const Icon(Icons.check_circle),
              label: const Text('I\'ve completed payment', style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.action,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final url = _paymentUrl;
                if (url != null) {
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Re-open payment page'),
            ),
          ],
        );
      case _Phase.form:
        return ElevatedButton.icon(
          onPressed: _startPayment,
          icon: const Icon(Icons.payments),
          label: Text('Pay ${Helpers.formatPrice(AppSettings.agencyFee)} with DPO',
              style: const TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.action,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
          ),
        );
    }
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;
  final bool isFree;

  const _SummaryRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
    this.isFree = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
          Text(
            isFree ? 'FREE' : Helpers.formatPrice(amount),
            style: TextStyle(fontSize: isTotal ? 16 : 14, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal),
          ),
        ],
      ),
    );
  }
}
