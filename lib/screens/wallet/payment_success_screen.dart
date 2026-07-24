import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/payment_model.dart';
import 'package:dalali/utils/helpers.dart';

/// ═══════════════════════════════════════════════════════════════
/// PAYMENT SUCCESS SCREEN — Receipt
/// ═══════════════════════════════════════════════════════════════
class PaymentSuccessScreen extends StatelessWidget {
  final PaymentModel payment;
  final String propertyTitle;
  final String tenantName;

  const PaymentSuccessScreen({
    super.key,
    required this.payment,
    required this.propertyTitle,
    required this.tenantName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Successful'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const Icon(Icons.check_circle, color: Colors.green, size: 72),
            const SizedBox(height: 12),
            const Text('Payment received', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'The landlord\'s contact details are now unlocked.',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RECEIPT', style: TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.grey)),
                    const Divider(),
                    _ReceiptRow('Receipt No.', payment.receiptNumber),
                    _ReceiptRow('Property', propertyTitle),
                    _ReceiptRow('Tenant', tenantName),
                    _ReceiptRow('Amount', Helpers.formatPrice(payment.amount)),
                    _ReceiptRow('Method', payment.paymentMethod ?? 'DPO'),
                    _ReceiptRow('Date', payment.paidAt != null ? Helpers.formatDate(payment.paidAt!) : '-'),
                    _ReceiptRow('Transaction ID', payment.dpoTransactionId ?? '-'),
                    _ReceiptRow('Status', 'PAID', valueColor: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _ReceiptRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
