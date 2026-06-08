import 'package:flutter/material.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/property_claim_model.dart';
import 'package:dalali/services/data_service.dart';

class ClaimPropertyScreen extends StatefulWidget {
  final String propertyId;
  final String claimantId;
  final String claimantRole;

  const ClaimPropertyScreen({
    super.key,
    required this.propertyId,
    required this.claimantId,
    required this.claimantRole,
  });

  @override
  State<ClaimPropertyScreen> createState() => _ClaimPropertyScreenState();
}

class _ClaimPropertyScreenState extends State<ClaimPropertyScreen> {
  final _reasonController = TextEditingController();
  final _data = DataService();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitClaim() async {
    if (_reasonController.text.trim().isEmpty) return;
    setState(() => _submitting = true);

    final claim = PropertyClaimModel(
      claimId: 'claim_${DateTime.now().millisecondsSinceEpoch}',
      propertyId: widget.propertyId,
      claimantId: widget.claimantId,
      claimantRole: widget.claimantRole,
      reason: _reasonController.text.trim(),
      createdAt: DateTime.now(),
    );

    await _data.addPropertyClaim(claim);

    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.claimSubmitted)),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.claimProperty),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l10n.propertyAlreadyExists,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l10n.requestOwnershipClaim,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reasonController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Explain why you are the rightful owner or lister...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitting ? null : _submitClaim,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(l10n.submit),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.cancelListing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
