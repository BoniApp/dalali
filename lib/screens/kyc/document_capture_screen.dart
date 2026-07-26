import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalali/models/kyc/kyc_session_model.dart';
import 'package:dalali/services/kyc/kyc_service.dart';
import 'package:dalali/services/kyc/ocr_validation_service.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/screens/kyc/liveness_check_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// DOCUMENT CAPTURE SCREEN
/// ═══════════════════════════════════════════════════════════════
///
/// Real rear-camera capture of the ID document, uploaded to the
/// private 'id-documents' storage bucket, plus the user-entered
/// document number checked against OcrValidationService's local
/// checksum for the selected document type. This does not replace a
/// real OCR/NIDA registry check (there is no live registry access
/// yet) — it replaces a hardcoded stub that never took a photo at
/// all and always reported success.
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
  final _numberController = TextEditingController();
  final _picker = ImagePicker();
  final _storage = StorageService();

  bool _capturing = false;
  bool _uploading = false;
  String? _capturedImagePath;
  String? _error;

  @override
  void dispose() {
    _numberController.dispose();
    super.dispose();
  }

  String get _numberHint {
    switch (widget.documentType) {
      case IdDocumentType.nidaId:
        return '20-digit NIN';
      case IdDocumentType.passport:
        return 'e.g. A1234567';
      case IdDocumentType.driversLicense:
        return 'Licence number';
      case IdDocumentType.zanId:
        return 'e.g. ZAN12345678';
      case IdDocumentType.votersId:
        return 'Voter ID number';
    }
  }

  bool _isValidNumber(String value) {
    switch (widget.documentType) {
      case IdDocumentType.nidaId:
        return OcrValidationService.isValidNin(value);
      case IdDocumentType.passport:
        return OcrValidationService.isValidTzPassportNumber(value);
      case IdDocumentType.driversLicense:
        return OcrValidationService.isValidDriversLicenseNumber(value);
      case IdDocumentType.zanId:
        return OcrValidationService.isValidZanId(value);
      case IdDocumentType.votersId:
        return OcrValidationService.isValidVotersId(value);
    }
  }

  Future<void> _captureDocument() async {
    setState(() => _capturing = true);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (picked == null) {
        setState(() => _capturing = false);
        return;
      }
      setState(() {
        _capturing = false;
        _capturedImagePath = picked.path;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _capturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camera error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _proceed() async {
    final number = _numberController.text.trim();
    if (_capturedImagePath == null) return;
    if (number.isEmpty) {
      setState(() => _error = 'Enter the document number');
      return;
    }

    setState(() {
      _error = null;
      _uploading = true;
    });

    final checksumValid = _isValidNumber(number);

    String? uploadedPath;
    try {
      uploadedPath = await _storage.uploadIdDocument(
        File(_capturedImagePath!),
        widget.userId,
        'front',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e. Please try again.'), backgroundColor: Colors.red),
      );
      return;
    }

    KycService().recordDocumentCapture(
      DocumentCaptureResult(
        frontImagePath: uploadedPath,
        documentNumber: number,
        checksumValid: checksumValid,
        ocrConfidence: checksumValid ? 0.9 : 0.4,
      ),
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LivenessCheckScreen(userId: widget.userId)),
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
                    color: _capturedImagePath != null ? Colors.green : Colors.grey,
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
                              const Text('Opening camera...'),
                            ],
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(File(_capturedImagePath!), fit: BoxFit.cover, width: double.infinity),
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_capturedImagePath != null) ...[
                    TextField(
                      controller: _numberController,
                      decoration: InputDecoration(
                        labelText: 'Document Number',
                        hintText: _numberHint,
                        border: const OutlineInputBorder(),
                        errorText: _error,
                      ),
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_capturedImagePath == null)
                    FilledButton.icon(
                      onPressed: _capturing ? null : _captureDocument,
                      icon: const Icon(Icons.camera_alt),
                      label: Text(_capturing ? 'Capturing...' : 'Capture Document'),
                    )
                  else ...[
                    FilledButton(
                      onPressed: _uploading ? null : _proceed,
                      child: Text(_uploading ? 'Uploading...' : 'Continue to Liveness Check'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _uploading
                          ? null
                          : () => setState(() {
                                _capturedImagePath = null;
                                _error = null;
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
