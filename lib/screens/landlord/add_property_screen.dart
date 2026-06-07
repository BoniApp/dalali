import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';

/// Built-in coordinates for common Tanzanian areas.
/// Users only type the location name; we resolve lat/lng automatically.
final Map<String, LatLng> tzLocations = {
  'masaki, dar es salaam': const LatLng(-6.7480, 39.2710),
  'mikocheni, dar es salaam': const LatLng(-6.7630, 39.2500),
  'oyster bay, dar es salaam': const LatLng(-6.7400, 39.2800),
  'upanga, dar es salaam': const LatLng(-6.8100, 39.2700),
  'kariakoo, dar es salaam': const LatLng(-6.8200, 39.2700),
  'kijitonyama, dar es salaam': const LatLng(-6.7700, 39.2400),
  'ubungo, dar es salaam': const LatLng(-6.7924, 39.2083),
  'buguruni, dar es salaam': const LatLng(-6.8330, 39.2200),
  'tandika, dar es salaam': const LatLng(-6.8600, 39.2300),
  'changombe, dar es salaam': const LatLng(-6.8400, 39.2100),
  'makuburi, dar es salaam': const LatLng(-6.8050, 39.2150),
  'kiwalani, dar es salaam': const LatLng(-6.8550, 39.2050),
  'gongolamboto, dar es salaam': const LatLng(-6.8700, 39.1900),
  'kawe, dar es salaam': const LatLng(-6.7200, 39.2600),
  'kinondoni, dar es salaam': const LatLng(-6.7800, 39.2300),
  'ilala, dar es salaam': const LatLng(-6.8250, 39.2700),
  'temeke, dar es salaam': const LatLng(-6.8500, 39.2500),
  'city centre, dodoma': const LatLng(-6.1731, 35.7419),
  'nyamagana, mwanza': const LatLng(-2.5167, 32.9000),
  'ilemela, mwanza': const LatLng(-2.5200, 32.9200),
  'arusha city, arusha': const LatLng(-3.3869, 36.6830),
  'moshi, kilimanjaro': const LatLng(-3.3400, 37.3400),
  'mbeya city, mbeya': const LatLng(-8.9100, 33.4500),
  'morogoro, morogoro': const LatLng(-6.8200, 37.6600),
  'tanga, tanga': const LatLng(-5.0700, 39.1000),
  'zanzibar city, zanzibar': const LatLng(-6.1659, 39.2026),
  'stone town, zanzibar': const LatLng(-6.1622, 39.1921),
};

LatLng resolveCoordinates(String location) {
  final key = location.toLowerCase().trim();
  // Exact match
  if (tzLocations.containsKey(key)) {
    return tzLocations[key]!;
  }
  // Partial match — check if any known area name appears in the input
  for (final entry in tzLocations.entries) {
    if (key.contains(entry.key.split(',').first.trim())) {
      return entry.value;
    }
  }
  // Default to central Dar es Salaam
  return const LatLng(-6.7924, 39.2083);
}

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
  final _priceController = TextEditingController();

  LatLng _pin = const LatLng(-6.7924, 39.2083);

  int _bedrooms = 2;
  int _bathrooms = 1;
  PropertyType _propertyType = PropertyType.apartment;
  bool _isFurnished = false;
  bool _hasWater = true;
  bool _hasParking = false;
  bool _hasSecurity = false;
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
    _priceController.dispose();
    _depositController.dispose();
    super.dispose();
  }

  void _updatePinFromLocation() {
    final loc = _locationController.text;
    if (loc.isNotEmpty) {
      setState(() {
        _pin = resolveCoordinates(loc);
      });
    }
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
                            Icon(Icons.map, color: Colors.teal.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pin: ${_pin.latitude.toStringAsFixed(4)}, ${_pin.longitude.toStringAsFixed(4)}',
                                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              ),
                            ),
                            Text(
                              'Adjust on Map',
                              style: TextStyle(fontSize: 13, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right, color: Colors.teal.shade700, size: 18),
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
                value: _propertyType,
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
                title: const Text('Parking'),
                value: _hasParking,
                onChanged: (v) => setState(() => _hasParking = v),
              ),
              SwitchListTile(
                title: const Text('Security'),
                value: _hasSecurity,
                onChanged: (v) => setState(() => _hasSecurity = v),
              ),
              const SizedBox(height: 16),
              const Text('Listing Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<ListingType>(
                value: _listingType,
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
                value: _status,
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
                    selectedColor: Colors.teal.shade100,
                    checkmarkColor: Colors.teal,
                    labelStyle: TextStyle(
                      color: selected ? Colors.teal.shade800 : Colors.black,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PaymentTerm>(
                value: _minimumAcceptedTerm,
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
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.teal.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A fixed agency fee of ${Helpers.formatPrice(AppSettings.agencyFee)} applies to all listings.',
                          style: TextStyle(fontSize: 12, color: Colors.teal.shade800),
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

    // Upload photos to Firebase Storage
    List<String> imageUrls = [];
    if (_pickedImages.isNotEmpty) {
      for (var i = 0; i < _pickedImages.length; i++) {
        final url = await _storage.uploadPropertyImage(
          File(_pickedImages[i].path),
          propertyId,
          i,
        );
        if (url != null) imageUrls.add(url);
      }
    }

    // Fallback if upload failed or no images picked
    if (imageUrls.isEmpty) {
      imageUrls = [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
      ];
    }

    final rent = double.parse(_priceController.text);
    final property = PropertyModel(
      id: propertyId,
      title: _titleController.text,
      description: _descriptionController.text,
      location: _locationController.text,
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
    );

    setState(() => _isUploading = false);

    if (mounted) {
      context.read<AppState>().addProperty(property);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(imageUrls.length > 1
              ? 'Property with ${imageUrls.length} photos submitted for approval!'
              : 'Property submitted for approval!'),
        ),
      );

      Navigator.pop(context);
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
        backgroundColor: Colors.teal,
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
        backgroundColor: Colors.teal,
        icon: const Icon(Icons.check, color: Colors.white),
        label: const Text('Confirm', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
