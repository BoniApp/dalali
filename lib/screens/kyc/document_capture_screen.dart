import 'package:flutter/material.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/services/kyc/ocr_validation_service.dart';
import 'package:dalali/screens/kyc/liveness_check_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// DOCUMENT CAPTURE SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Camera capture with real-time image quality feedback.
/// Includes blur/glare detection guidance and auto-capture stub.
///
class DocumentCaptureScreen extends StatefulWidget {
  final String userId;
  final IdDocumentType documentType;

  const DocumentCaptureScreen({
    super.key,
    required this.userId,
    required this.documentType,
  });

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen> {
  bool _capturing = false;
  bool _iqcPass = false;
  String? _capturedImagePath;

  Future<void> _simulateCapture() async {
    setState(() => _capturing = true);

    // Simulate camera capture delay + IQC analysis
    await Future.delayed(const Duration(seconds: 2));

    final iqc = await OcrValidationService.checkImageQuality('/mock/path');

    setState(() {
      _capturing = false;
      _iqcPass = iqc.isAcceptable;
      _capturedImagePath = '/mock/captured_id.jpg';
    });

    if (!iqc.isAcceptable && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image too blurry. Please hold steady and retake.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _proceed() {
    if (_capturedImagePath == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LivenessCheckScreen(
          userId: widget.userId,
          documentImagePath: _capturedImagePath!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.documentType.name.toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text('Capture $typeLabel')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _iqcPass ? Colors.green : Colors.grey,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: _capturedImagePath == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.document_scanner, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 12),
                            Text(
                              'Position your ${widget.documentType.name} inside the frame',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            if (_capturing) ...[
                              const SizedBox(height: 24),
                              const CircularProgressIndicator(),
                              const SizedBox(height: 8),
                              const Text('Checking image quality...'),
                            ],
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle, size: 64, color: Colors.green),
                            const SizedBox(height: 12),
                            const Text('Capture successful!'),
                          ],
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_capturedImagePath == null)
                    FilledButton.icon(
                      onPressed: _capturing ? null : _simulateCapture,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_capturing ? 'Capturing...' : 'Capture Document'),
                    )
                  else ...[
                    FilledButton(
                      onPressed: _proceed,
                      child: const Text('Continue to Liveness Check'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => setState(() {
                        _capturedImagePath = null;
                        _iqcPass = false;
                      }),
                      child: const Text('Retake Photo'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
