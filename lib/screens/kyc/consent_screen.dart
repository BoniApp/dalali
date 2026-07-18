import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/screens/kyc/id_type_selection_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// CONSENT SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// PDPA 2022 compliant explicit consent capture.
/// Records consent version, timestamp, and device context.
///
class ConsentScreen extends StatefulWidget {
  final String userId;

  const ConsentScreen({super.key, required this.userId});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;
  bool _isLoading = false;

  Future<void> _proceed() async {
    if (!_agreed) return;
    setState(() => _isLoading = true);

    final kyc = KycService();
    await kyc.startSession(widget.userId);
    await kyc.recordConsent('v1.0.0-pdpa2022');

    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => IdTypeSelectionScreen(userId: widget.userId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user, size: 48, color: AppTheme.primary),
              const SizedBox(height: 16),
              const Text(
                'Verify Your Identity',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                'To keep Dalali safe and comply with Bank of Tanzania regulations, we need to verify your identity. This usually takes less than 30 seconds.',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              const SizedBox(height: 24),
              _ConsentItem(
                icon: Icons.shield,
                title: 'Secure Processing',
                description: 'Your ID is encrypted and only used for verification.',
              ),
              _ConsentItem(
                icon: Icons.delete_forever,
                title: 'Automatic Deletion',
                description: 'Raw images are deleted 30 days after verification.',
              ),
              _ConsentItem(
                icon: Icons.gavel,
                title: 'Legal Compliance',
                description: 'We comply with the Personal Data Protection Act (2022).',
              ),
              const SizedBox(height: 24),
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                title: const Text(
                  'I agree to the identity verification process and consent to the processing of my personal data as described above.',
                  style: TextStyle(fontSize: 13),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _agreed && !_isLoading ? _proceed : null,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Continue'),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ConsentItem({required this.icon, required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
