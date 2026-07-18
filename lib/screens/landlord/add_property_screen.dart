import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/location_service.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/property_registry_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:dalali/screens/claims/claim_property_screen.dart';

class AddPropertyScreen extends StatefulWidget {
  const AddPropertyScreen({super.key});

  @override
  State<AddPropertyScreen> createState() => _AddPropertyScreenState();
}

class _AddPropertyScreenState extends State<AddPropertyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _streetController = TextEditingController();
  final _otherWardController = TextEditingController();
  final _priceController = TextEditingController();

  LatLng _pin = const LatLng(-6.7924, 39.2083);
  String _selectedDistrict = LocationService.districtWards.keys.first;
  String _selectedWard = LocationService.districtWards.values.first.first;
  bool _isDetectingAddress = false;

  int _bedrooms = 2;
  int _bathrooms = 1;
  PropertyType _propertyType = PropertyType.apartment;
  bool _isFurnished = false;
  bool _hasWater = true;
  bool _hasParking = false;
  bool _hasSecurity = false;
  bool _hasElectricity = true;
  bool _hasInternet = false;
  bool _hasGym = false;
  bool _hasSwimmingPool = false;
  bool _hasBalcony = false;
  bool _hasGarden = false;
  bool _hasBackupGenerator = false;
  bool _hasCctv = false;
  bool _hasElevator = false;
  bool _petFriendly = false;
  bool _hasAirConditioning = false;
  bool _hasFittedKitchen = false;
  ListingType _listingType = ListingType.basic;
  PropertyStatus _status = PropertyStatus.available;

  // ─── Rental Payment Terms ─────────────────────────────────
  final List<PaymentTerm> _paymentOptions = [PaymentTerm.monthly];
  PaymentTerm? _minimumAcceptedTerm = PaymentTerm.monthly;
  bool _depositRequired = false;
  final _depositController = TextEditingController();

  final List<XFile> _pickedImages = [];
  bool _isUploading = false;
  final _picker = ImagePicker();
  final _storage = StorageService();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _streetController.dispose();
    _otherWardController.dispose();
    _priceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  Future<void> _updatePinFromLocation() async {
    final loc = _locationController.text;
    if (loc.isEmpty) return;

    setState(() {
      _pin = LocationService.resolveCoordinates(loc);
      _isDetectingAddress = true;
    });

    final address = await LocationService.reverseGeocodeAddress(_pin.latitude, _pin.longitude);
    final districtWard = LocationService.resolveDistrictWard(loc);

    setState(() {
      final candidateDistrict = address['district']?.isNotEmpty == true && LocationService.districtWards.containsKey(address['district'])
          ? address['district']!
          : districtWard['district'] ?? _selectedDistrict;
      final candidateWard = address['ward']?.isNotEmpty == true ? address['ward']! : districtWard['ward'] ?? _selectedWard;
      _selectedDistrict = candidateDistrict;
      if (LocationService.districtWards[candidateDistrict]?.contains(candidateWard) == true) {
        _selectedWard = candidateWard;
        _otherWardController.clear();
      } else if (candidateWard.isNotEmpty) {
        _selectedWard = LocationService.otherOption;
        _otherWardController.text = candidateWard;
      } else {
        _selectedWard = LocationService.districtWards[candidateDistrict]!.first;
        _otherWardController.clear();
      }
      _streetController.text = address['street'] ?? _streetController.text;
      _isDetectingAddress = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked.isNotEmpty) {
        setState(() => _pickedImages.addAll(picked));
      }
    } else {
      final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        setState(() => _pickedImages.add(picked));
      }
    }
  }

  void _removeImage(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(initial: _pin),
      ),
    );
    if (result != null) {
      setState(() => _pin = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final isPremium = user?.subscriptionTier == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Property'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Property Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location * (e.g. Masaki, Dar es Salaam)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                onChanged: (_) => _updatePinFromLocation(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _streetController,
                decoration: const InputDecoration(
                  labelText: 'Street Name',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.streetview),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDistrict,
                      decoration: const InputDecoration(
                        labelText: 'District',
                        border: OutlineInputBorder(),
                      ),
                      items: LocationService.districtWards.keys.map((district) {
                        return DropdownMenuItem(value: district, child: Text(district));
                      }).toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedDistrict = value;
                          _selectedWard = LocationService.districtWards[value]!.first;
                          _otherWardController.clear();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedWard,
                      decoration: const InputDecoration(
                        labelText: 'Ward',
                        border: OutlineInputBorder(),
                      ),
                      items: LocationService.districtWards[_selectedDistrict]!
                          .map((ward) => DropdownMenuItem(value: ward, child: Text(ward)))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedWard = value;
                          if (value != LocationService.otherOption) {
                            _otherWardController.clear();
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              if (_selectedWard == LocationService.otherOption)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextFormField(
                    controller: _otherWardController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Ward Name',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (_selectedWard == LocationService.otherOption && (value == null || value.trim().isEmpty)) {
                        return 'Enter ward name';
                      }
                      return null;
                    },
                  ),
                ),
              if (_isDetectingAddress)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 12),
                      Text('Detecting street and ward...'),
                    ],
                  ),
                ),
              const SizedBox(height: 8),

              // ─── Map Preview ────────────────────────────────────────
              Card(
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    SizedBox(
                      height: 160,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: _pin,
                          initialZoom: 14,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dalali.app',
                            tileProvider: CancellableNetworkTileProvider(),
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _pin,
                                width: 40,
                                height: 40,
                                child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: _openMapPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Row(
                          children: [
                            Icon(Icons.map, color: AppTheme.primaryDark, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pin: ${_pin.latitude.toStringAsFixed(4)}, ${_pin.longitude.toStringAsFixed(4)}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              ),
                            ),
                            Text(
                              'Adjust on Map',
                              style: TextStyle(fontSize: 13, color: AppTheme.primaryDark, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: AppTheme.primaryDark, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ─── Photos ─────────────────────────────────────────────
              const Text('Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_pickedImages.isEmpty)
                Card(
                  child: InkWell(
                    onTap: () => _showImageSourceSheet(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey[400]),
                          const SizedBox(height: 8),
                          Text('Add Photos', style: TextStyle(color: Colors.grey[600])),
                          Text('Tap to choose from camera or gallery', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pickedImages.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _pickedImages.length) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: InkWell(
                                onTap: () => _showImageSourceSheet(),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 110,
                                  height: 110,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.grey[400]!),
                                  ),
                                  child: Icon(Icons.add_a_photo, color: Colors.grey[500]),
                                ),
                              ),
                            );
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    File(_pickedImages[index].path),
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.close, size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_pickedImages.length} photo${_pickedImages.length > 1 ? 's' : ''} selected',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              const SizedBox(height: 16),

              const Text('Property Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<PropertyType>(
                initialValue: _propertyType,
                decoration: const InputDecoration(labelText: 'Property Type', border: OutlineInputBorder()),
                items: PropertyType.values.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.name[0].toUpperCase() + t.name.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _propertyType = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(labelText: 'Monthly Rent (TZS) *', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bedrooms'),
                        Row(
                          children: [
                            IconButton(onPressed: () => setState(() => _bedrooms = (_bedrooms - 1).clamp(0, 10)), icon: const Icon(Icons.remove)),
                            Text('$_bedrooms', style: const TextStyle(fontSize: 18)),
                            IconButton(onPressed: () => setState(() => _bedrooms = (_bedrooms + 1).clamp(0, 10)), icon: const Icon(Icons.add)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bathrooms'),
                        Row(
                          children: [
                            IconButton(onPressed: () => setState(() => _bathrooms = (_bathrooms - 1).clamp(0, 10)), icon: const Icon(Icons.remove)),
                            Text('$_bathrooms', style: const TextStyle(fontSize: 18)),
                            IconButton(onPressed: () => setState(() => _bathrooms = (_bathrooms + 1).clamp(0, 10)), icon: const Icon(Icons.add)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Amenities', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Furnished'),
                value: _isFurnished,
                onChanged: (v) => setState(() => _isFurnished = v),
              ),
              SwitchListTile(
                title: const Text('Water Available'),
                value: _hasWater,
                onChanged: (v) => setState(() => _hasWater = v),
              ),
              SwitchListTile(
                title: const Text('Electricity'),
                value: _hasElectricity,
                onChanged: (v) => setState(() => _hasElectricity = v),
              ),
              SwitchListTile(
                title: const Text('Internet / WiFi'),
                value: _hasInternet,
                onChanged: (v) => setState(() => _hasInternet = v),
              ),
              SwitchListTile(
                title: const Text('Parking'),
                value: _hasParking,
                onChanged: (v) => setState(() => _hasParking = v),
              ),
              SwitchListTile(
                title: const Text('Security'),
                value: _hasSecurity,
                onChanged: (v) => setState(() => _hasSecurity = v),
              ),
              SwitchListTile(
                title: const Text('CCTV'),
                value: _hasCctv,
                onChanged: (v) => setState(() => _hasCctv = v),
              ),
              SwitchListTile(
                title: const Text('Backup Generator'),
                value: _hasBackupGenerator,
                onChanged: (v) => setState(() => _hasBackupGenerator = v),
              ),
              SwitchListTile(
                title: const Text('Air Conditioning'),
                value: _hasAirConditioning,
                onChanged: (v) => setState(() => _hasAirConditioning = v),
              ),
              SwitchListTile(
                title: const Text('Fitted Kitchen'),
                value: _hasFittedKitchen,
                onChanged: (v) => setState(() => _hasFittedKitchen = v),
              ),
              SwitchListTile(
                title: const Text('Swimming Pool'),
                value: _hasSwimmingPool,
                onChanged: (v) => setState(() => _hasSwimmingPool = v),
              ),
              SwitchListTile(
                title: const Text('Gym'),
                value: _hasGym,
                onChanged: (v) => setState(() => _hasGym = v),
              ),
              SwitchListTile(
                title: const Text('Elevator / Lift'),
                value: _hasElevator,
                onChanged: (v) => setState(() => _hasElevator = v),
              ),
              SwitchListTile(
                title: const Text('Balcony'),
                value: _hasBalcony,
                onChanged: (v) => setState(() => _hasBalcony = v),
              ),
              SwitchListTile(
                title: const Text('Garden / Yard'),
                value: _hasGarden,
                onChanged: (v) => setState(() => _hasGarden = v),
              ),
              SwitchListTile(
                title: const Text('Pet Friendly'),
                value: _petFriendly,
                onChanged: (v) => setState(() => _petFriendly = v),
              ),
              const SizedBox(height: 16),
              const Text('Listing Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingType>(
                initialValue: _listingType,
                decoration: const InputDecoration(labelText: 'Listing Type', border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: ListingType.basic, child: Text('Basic (Free)')),
                  if (isPremium)
                    const DropdownMenuItem(value: ListingType.featured, child: Text('Featured (Premium)')),
                ],
                onChanged: (v) => setState(() => _listingType = v!),
              ),
              if (!isPremium)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Upgrade to Premium to feature your listings.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PropertyStatus>(
                initialValue: _status,
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: PropertyStatus.values.map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 24),

              // ─── Rental Payment Terms ───────────────────────────────
              const Text('Rental Payment Terms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('Accepted Payment Options', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: PaymentTerm.values.map((term) {
                  final selected = _paymentOptions.contains(term);
                  return FilterChip(
                    label: Text(Helpers.paymentTermLabel(term)),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) {
                          _paymentOptions.add(term);
                        } else {
                          _paymentOptions.remove(term);
                        }
                        // Reset minimum accepted if it was removed
                        if (_minimumAcceptedTerm != null && !_paymentOptions.contains(_minimumAcceptedTerm)) {
                          _minimumAcceptedTerm = _paymentOptions.isNotEmpty ? _paymentOptions.first : null;
                        }
                      });
                    },
                    selectedColor: AppTheme.primary.withAlpha(26),
                    checkmarkColor: AppTheme.primary,
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.primaryDark : Colors.black,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentTerm>(
                initialValue: _minimumAcceptedTerm,
                decoration: const InputDecoration(labelText: 'Minimum Accepted Term', border: OutlineInputBorder()),
                items: _paymentOptions.map((term) => DropdownMenuItem(
                  value: term,
                  child: Text(Helpers.paymentTermLabel(term)),
                )).toList(),
                onChanged: (v) => setState(() => _minimumAcceptedTerm = v),
                validator: (v) => v == null ? 'Select a minimum accepted term' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Deposit Required'),
                value: _depositRequired,
                onChanged: (v) => setState(() => _depositRequired = v),
              ),
              if (_depositRequired) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _depositController,
                  decoration: const InputDecoration(labelText: 'Deposit Amount (TZS) *', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (!_depositRequired) return null;
                    if (v == null || v.isEmpty) return 'Required';
                    final val = double.tryParse(v);
                    if (val == null || val <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 12),
              Card(
                color: AppTheme.primary.withAlpha(13),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryDark, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A fixed agency fee of ${Helpers.formatPrice(AppSettings.agencyFee)} applies to all listings.',
                          style: TextStyle(fontSize: 12, color: AppTheme.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
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

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
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
    if (_pickedImages.isNotEmpty) {
      for (var i = 0; i < _pickedImages.length; i++) {
        try {
          final url = await _storage.uploadPropertyImage(
            File(_pickedImages[i].path),
            propertyId,
            i,
          );
          imageUrls.add(url);
        } catch (e) {
          uploadError ??= 'Photo ${i + 1} failed: $e';
          print('Image upload failed for index $i: $e');
        }
      }
    }

    // Fallback if no images were uploaded
    if (imageUrls.isEmpty) {
      imageUrls = [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
      ];
    }

    final rent = double.parse(_priceController.text);

    // ═══ Duplicate Detection & Registry ═══════════════════════
    final registryService = PropertyRegistryService();
    final existingRegistry = await registryService.checkDuplicate(
      latitude: _pin.latitude,
      longitude: _pin.longitude,
      landlordPhone: user.phone,
      propertyType: _propertyType,
      rooms: _bedrooms,
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
      latitude: _pin.latitude,
      longitude: _pin.longitude,
      landlordPhone: user.phone,
      landlordName: user.fullName,
      propertyType: _propertyType,
      rooms: _bedrooms,
      address: _locationController.text,
    );

    final property = PropertyModel(
      id: propertyId,
      title: _titleController.text,
      description: _descriptionController.text,
      location: _locationController.text,
      street: _streetController.text,
      district: _selectedDistrict,
      ward: _selectedWard == LocationService.otherOption ? _otherWardController.text.trim() : _selectedWard,
      latitude: _pin.latitude,
      longitude: _pin.longitude,
      rentPrice: rent,
      bedrooms: _bedrooms,
      bathrooms: _bathrooms,
      propertyType: _propertyType,
      isFurnished: _isFurnished,
      hasWater: _hasWater,
      hasParking: _hasParking,
      hasSecurity: _hasSecurity,
      hasElectricity: _hasElectricity,
      hasInternet: _hasInternet,
      hasGym: _hasGym,
      hasSwimmingPool: _hasSwimmingPool,
      hasBalcony: _hasBalcony,
      hasGarden: _hasGarden,
      hasBackupGenerator: _hasBackupGenerator,
      hasCctv: _hasCctv,
      hasElevator: _hasElevator,
      petFriendly: _petFriendly,
      hasAirConditioning: _hasAirConditioning,
      hasFittedKitchen: _hasFittedKitchen,
      images: imageUrls,
      status: _status,
      listingType: _listingType,
      landlordId: user.id,
      landlordName: user.fullName,
      landlordPhone: user.phone,
      isLandlordVerified: user.verificationStatus == VerificationStatus.verified,
      createdAt: DateTime.now(),
      isApproved: false,
      rentAmount: rent,
      paymentOptions: List<PaymentTerm>.from(_paymentOptions),
      minimumAcceptedTerm: _minimumAcceptedTerm,
      depositRequired: _depositRequired,
      depositAmount: _depositRequired ? (double.tryParse(_depositController.text) ?? 0) : 0,
      listingCreatorId: user.id,
      listingCreatorRole: user.role.name,
      registryId: registry.registryId,
      listingStatus: ListingStatus.active,
    );

    setState(() => _isUploading = false);

    if (mounted) {
      try {
        await context.read<AppState>().addProperty(property);

        final uploadedCount = imageUrls.where(
          (u) => !u.contains('wikipedia.org'),
        ).length;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadedCount > 0
                ? 'Property with $uploadedCount photo${uploadedCount > 1 ? 's' : ''} submitted for approval!'
                : 'Property submitted for approval (photos could not be uploaded).'),
            backgroundColor: uploadedCount > 0 ? null : Colors.orange,
          ),
        );

        // Warn user if uploads failed
        if (uploadError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo upload issue: $uploadError. You can add photos later by editing the property.'),
              backgroundColor: Colors.orange.shade800,
              duration: const Duration(seconds: 6),
            ),
          );
        }

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving property: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Inline Map Picker — full-screen draggable pin
// ═══════════════════════════════════════════════════════════════════════════

class _MapPickerScreen extends StatefulWidget {
  final LatLng initial;
  const _MapPickerScreen({required this.initial});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust Pin Location'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: widget.initial,
          initialZoom: 15,
          onTap: (_, point) => setState(() => _selected = point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dalali.app',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: _selected,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pop(context, _selected),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Confirm', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
