import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/screens/wallet/payment_screen.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/utils/helpers.dart';

/// ═══════════════════════════════════════════════════════════════
/// PAY AGENCY FEE BUTTON
/// ═══════════════════════════════════════════════════════════════
///
/// Shown to a tenant after their tenancy application is approved.
/// Fetches the listing (it left the public feed when it was reserved,
/// so it is no longer in the AppState feed list) and routes to
/// [PaymentScreen] for the fixed agency fee.
class PayAgencyFeeButton extends StatefulWidget {
  final String propertyId;

  const PayAgencyFeeButton({super.key, required this.propertyId});

  @override
  State<PayAgencyFeeButton> createState() => _PayAgencyFeeButtonState();
}

class _PayAgencyFeeButtonState extends State<PayAgencyFeeButton> {
  bool _loading = false;

  Future<void> _openPayment() async {
    setState(() => _loading = true);
    try {
      final property = await DataService().getPropertyById(widget.propertyId);
      if (!mounted) return;
      if (property == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This listing is no longer available.')),
        );
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PaymentScreen(property: property)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _loading ? null : _openPayment,
        icon: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.payments),
        label: Text('Pay Agency Fee ${Helpers.formatPrice(AppSettings.agencyFee)}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.action,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
