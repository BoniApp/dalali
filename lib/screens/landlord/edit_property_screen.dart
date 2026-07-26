import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/services/location_service.dart';
import 'package:provider/provider.dart';
import 'package:dalali/widgets/property_form.dart';

class EditPropertyScreen extends StatefulWidget {
  final PropertyModel property;

  const EditPropertyScreen({super.key, required this.property});

  @override
  State<EditPropertyScreen> createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  late final PropertyFormData _data;
  final _storage = StorageService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _data = PropertyFormData.fromProperty(widget.property);
  }

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final isPremium = user?.subscriptionTier == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Property'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PropertyFormFields(data: _data, isPremium: isPremium),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isUploading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save Changes', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    final propertyId = widget.property.id;

    // Upload any new photos to Supabase Storage
    List<String> imageUrls = List<String>.from(_data.existingImages);
    String? uploadError;
    if (_data.pickedImages.isNotEmpty) {
      final startIndex = _data.existingImages.length;
      for (var i = 0; i < _data.pickedImages.length; i++) {
        try {
          final url = await _storage.uploadPropertyImage(
            File(_data.pickedImages[i].path),
            propertyId,
            startIndex + i,
          );
          imageUrls.add(url);
        } catch (e) {
          uploadError ??= 'Photo ${i + 1} failed: $e';
          debugPrint('Image upload failed for index ${startIndex + i}: $e');
        }
      }
    }

    // Fallback if all images were removed and upload failed
    if (imageUrls.isEmpty) {
      imageUrls = [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
      ];
    }

    final rent = double.parse(_data.priceController.text);
    final updatedProperty = widget.property.copyWith(
      title: _data.titleController.text,
      description: _data.descriptionController.text,
      location: _data.locationController.text,
      latitude: _data.pin.latitude,
      longitude: _data.pin.longitude,
      rentPrice: rent,
      bedrooms: _data.bedrooms,
      bathrooms: _data.bathrooms,
      propertyType: _data.propertyType,
      isFurnished: _data.isFurnished,
      hasWater: _data.hasWater,
      hasParking: _data.hasParking,
      hasSecurity: _data.hasSecurity,
      hasElectricity: _data.hasElectricity,
      hasInternet: _data.hasInternet,
      hasGym: _data.hasGym,
      hasSwimmingPool: _data.hasSwimmingPool,
      hasBalcony: _data.hasBalcony,
      hasGarden: _data.hasGarden,
      hasBackupGenerator: _data.hasBackupGenerator,
      hasCctv: _data.hasCctv,
      hasElevator: _data.hasElevator,
      petFriendly: _data.petFriendly,
      hasAirConditioning: _data.hasAirConditioning,
      hasFittedKitchen: _data.hasFittedKitchen,
      images: imageUrls,
      street: _data.streetController.text,
      district: _data.selectedDistrict,
      ward: _data.selectedWard == LocationService.otherOption ? _data.otherWardController.text.trim() : _data.selectedWard,
      status: _data.status,
      listingType: _data.listingType,
      updatedAt: DateTime.now(),
      rentAmount: rent,
      paymentOptions: List<PaymentTerm>.from(_data.paymentOptions),
      minimumAcceptedTerm: _data.minimumAcceptedTerm,
      depositRequired: _data.depositRequired,
      depositAmount: _data.depositRequired ? (double.tryParse(_data.depositController.text) ?? 0) : 0,
    );

    setState(() => _isUploading = false);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();

    try {
      await appState.updateProperty(updatedProperty);

      final uploadedCount = imageUrls.where(
        (u) => !u.contains('wikipedia.org'),
      ).length;

      messenger.showSnackBar(
        SnackBar(
          content: Text(uploadedCount > 0
              ? 'Property updated with $uploadedCount photo${uploadedCount > 1 ? 's' : ''}!'
              : 'Property updated successfully!'),
        ),
      );

      if (uploadError != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Photo upload issue: $uploadError'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
          ),
        );
      }

      if (mounted) Navigator.pop(context, updatedProperty);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving property: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
