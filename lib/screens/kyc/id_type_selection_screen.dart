import 'package:flutter/material.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/screens/kyc/document_capture_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// ID TYPE SELECTION SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Allows user to select from the 5 acceptable ID documents.
/// NIDA ID is pre-selected as the recommended primary option.
///
class IdTypeSelectionScreen extends StatelessWidget {
  final String userId;

  const IdTypeSelectionScreen({super.key, required this.userId});

  static const List<_IdOption> _options = [
    _IdOption(IdDocumentType.nidaId, 'National ID (NIDA)', Icons.badge, Colors.teal, isRecommended: true),
    _IdOption(IdDocumentType.passport, 'Passport', Icons.book, Colors.indigo),
    _IdOption(IdDocumentType.driversLicense, 'Driver\'s License', Icons.drive_eta, Colors.blue),
    _IdOption(IdDocumentType.zanId, 'Zanzibar ID (ZanID)', Icons.credit_card, Colors.green),
    _IdOption(IdDocumentType.votersId, 'Voter\'s ID', Icons.how_to_vote, Colors.orange),
  ];

  void _select(BuildContext context, IdDocumentType type) async {
    await KycService().selectDocumentType(type);
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DocumentCaptureScreen(
            userId: userId,
            documentType: type,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select ID Document')),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _options.length,
          itemBuilder: (context, index) {
            final opt = _options[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: opt.color.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(opt.icon, color: opt.color),
                ),
                title: Text(opt.label),
                subtitle: opt.isRecommended
                    ? const Text('Recommended', style: TextStyle(color: Colors.teal, fontSize: 12))
                    : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _select(context, opt.type),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _IdOption {
  final IdDocumentType type;
  final String label;
  final IconData icon;
  final Color color;
  final bool isRecommended;

  const _IdOption(this.type, this.label, this.icon, this.color, {this.isRecommended = false});
}
