import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/selcom_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentScreen extends StatefulWidget {
  final PropertyModel property;

  const PaymentScreen({super.key, required this.property});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  String? _statusMessage;

  Future<void> _initiatePayment() async {
    final user = context.read<AppState>().currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to proceed with payment')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Creating payment order...';
    });

    try {
      final orderId = SelcomService.generateOrderId('DAL');
      final selcom = SelcomService();

      final response = await selcom.createPaymentOrder(
        amount: AppSettings.agencyFee,
        currency: 'TZS',
        orderId: orderId,
        customerEmail: user.email,
        customerPhone: user.phone,
        description: 'Agency fee for ${widget.property.title}',
        redirectUrl: 'https://dalali.app/payment/success',
        cancelUrl: 'https://dalali.app/payment/cancel',
      );

      if (response.success && response.raw != null) {
        setState(() {
          _statusMessage = 'Redirecting to Selcom checkout...';
        });

        // Try to open checkout URL if provided
        final paymentUrl = response.raw!['payment_url'] ?? response.raw!['checkout_url'];
        if (paymentUrl != null && paymentUrl is String) {
          final uri = Uri.parse(paymentUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        }

        // Start polling for payment status
        _startStatusPolling(orderId);
      } else {
        setState(() {
          _statusMessage = response.message ?? 'Payment initiation failed';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _startStatusPolling(String orderId) async {
    final selcom = SelcomService();
    int attempts = 0;
    const maxAttempts = 60; // 5 minutes at 5-second intervals

    while (attempts < maxAttempts && mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;

      try {
        final response = await selcom.verifyPayment(orderId);
        if (!mounted) return;

        final paymentStatus = response.status?.toLowerCase();

        if (paymentStatus == 'completed' || paymentStatus == 'success') {
          setState(() {
            _statusMessage = 'Payment successful!';
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment completed successfully!')),
          );
          return;
        } else if (paymentStatus == 'failed' || paymentStatus == 'cancelled') {
          setState(() {
            _statusMessage = 'Payment failed. Please try again.';
            _isProcessing = false;
          });
          return;
        }

        setState(() {
          _statusMessage = 'Waiting for payment confirmation... (${attempts + 1}/$maxAttempts)';
        });
      } catch (e) {
        // Continue polling on error
      }

      attempts++;
    }

    if (mounted) {
      setState(() {
        _statusMessage = 'Payment status check timed out. Please check your transaction history.';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.property;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm Payment'),
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
                    Icon(Icons.shield, color: AppTheme.primaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your payment is protected. Funds are held in escrow for 48 hours before release to the agent.',
                        style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_statusMessage != null) ...[
              Center(
                child: Column(
                  children: [
                    if (_isProcessing) const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(_statusMessage!, textAlign: TextAlign.center),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isProcessing
                    ? const Text('Processing...', style: TextStyle(fontSize: 16))
                    : Text('Pay ${Helpers.formatPrice(AppSettings.agencyFee)}', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Powered by Selcom',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool isTotal;
  final bool isFree;

  const _SummaryRow({required this.label, required this.amount, this.isTotal = false, this.isFree = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            isFree ? 'FREE' : Helpers.formatPrice(amount),
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isFree ? Colors.green : (isTotal ? AppTheme.primary : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}
