import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/location_service.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/services/property_registry_service.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:dalali/screens/claims/claim_property_screen.dart';
import 'package:dalali/widgets/property_form.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _data = PropertyFormData();
  final _storage = StorageService();
  bool _isUploading = false;

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
        title: const Text('Add Property'),
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
                      : const Text('Submit for Approval', style: TextStyle(fontSize: 16)),
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

    final user = context.read<AppState>().currentUser!;
    final propertyId = 'p${DateTime.now().millisecondsSinceEpoch}';

    // ─── Upload photos to Supabase Storage ──────────────────────
    List<String> imageUrls = [];
    String? uploadError;
    if (_data.pickedImages.isNotEmpty) {
      for (var i = 0; i < _data.pickedImages.length; i++) {
        try {
          final url = await _storage.uploadPropertyImage(
            File(_data.pickedImages[i].path),
            propertyId,
            i,
          );
          imageUrls.add(url);
        } catch (e) {
          uploadError ??= 'Photo ${i + 1} failed: $e';
          debugPrint('Image upload failed for index $i: $e');
        }
      }
    }

    // Fallback if no images were uploaded
    if (imageUrls.isEmpty) {
      imageUrls = [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
      ];
    }

    final rent = double.parse(_data.priceController.text);

    // ═══ Duplicate Detection & Registry ═══════════════════════
    final registryService = PropertyRegistryService();
    final existingRegistry = await registryService.checkDuplicate(
      latitude: _data.pin.latitude,
      longitude: _data.pin.longitude,
      landlordPhone: user.phone,
      propertyType: _data.propertyType,
      rooms: _data.bedrooms,
    );

    if (existingRegistry != null && mounted) {
      setState(() => _isUploading = false);
      final shouldClaim = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.duplicateDetected),
          content: Text(AppLocalizations.of(context)!.propertyAlreadyExists),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppLocalizations.of(context)!.cancelListing),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              child: Text(AppLocalizations.of(context)!.requestOwnershipClaim),
            ),
          ],
        ),
      );

      if (shouldClaim == true && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClaimPropertyScreen(
              propertyId: existingRegistry.registryId,
              claimantId: user.id,
              claimantRole: user.role.name,
            ),
          ),
        );
      }
      return;
    }

    // Create registry entry
    final registry = await registryService.createRegistry(
      latitude: _data.pin.latitude,
      longitude: _data.pin.longitude,
      landlordPhone: user.phone,
      landlordName: user.fullName,
      propertyType: _data.propertyType,
      rooms: _data.bedrooms,
      address: _data.locationController.text,
    );

    final property = PropertyModel(
      id: propertyId,
      title: _data.titleController.text,
      description: _data.descriptionController.text,
      location: _data.locationController.text,
      street: _data.streetController.text,
      district: _data.selectedDistrict,
      ward: _data.selectedWard == LocationService.otherOption ? _data.otherWardController.text.trim() : _data.selectedWard,
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
      status: _data.status,
      listingType: _data.listingType,
      landlordId: user.id,
      landlordName: user.fullName,
      landlordPhone: user.phone,
      isLandlordVerified: user.verificationStatus == VerificationStatus.verified,
      createdAt: DateTime.now(),
      isApproved: false,
      rentAmount: rent,
      paymentOptions: List<PaymentTerm>.from(_data.paymentOptions),
      minimumAcceptedTerm: _data.minimumAcceptedTerm,
      depositRequired: _data.depositRequired,
      depositAmount: _data.depositRequired ? (double.tryParse(_data.depositController.text) ?? 0) : 0,
      listingCreatorId: user.id,
      listingCreatorRole: user.role.name,
      registryId: registry.registryId,
      listingStatus: ListingStatus.active,
    );

    setState(() => _isUploading = false);

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final appState = context.read<AppState>();

    try {
      await appState.addProperty(property);

      final uploadedCount = imageUrls.where(
        (u) => !u.contains('wikipedia.org'),
      ).length;

      messenger.showSnackBar(
        SnackBar(
          content: Text(uploadedCount > 0
              ? 'Property with $uploadedCount photo${uploadedCount > 1 ? 's' : ''} submitted for approval!'
              : 'Property submitted for approval (photos could not be uploaded).'),
          backgroundColor: uploadedCount > 0 ? null : Colors.orange,
        ),
      );

      // Warn user if uploads failed
      if (uploadError != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Photo upload issue: $uploadError. You can add photos later by editing the property.'),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 6),
          ),
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Error saving property: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
