import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/location_service.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/utils/helpers.dart';

/// Shared mutable state for the add/edit property forms. Holding one
/// instance and passing it by reference to [PropertyFormFields] lets
/// both screens read the final values directly at submit time without
/// a callback/notifier round-trip.
class PropertyFormData {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  final locationController = TextEditingController();
  final streetController = TextEditingController();
  final otherWardController = TextEditingController();
  final priceController = TextEditingController();
  final depositController = TextEditingController();

  LatLng pin = const LatLng(-6.7924, 39.2083);
  String selectedDistrict = LocationService.districtWards.keys.first;
  String selectedWard = LocationService.districtWards.values.first.first;

  int bedrooms = 2;
  int bathrooms = 1;
  PropertyType propertyType = PropertyType.apartment;
  bool isFurnished = false;
  bool hasWater = true;
  bool hasParking = false;
  bool hasSecurity = false;
  bool hasElectricity = true;
  bool hasInternet = false;
  bool hasGym = false;
  bool hasSwimmingPool = false;
  bool hasBalcony = false;
  bool hasGarden = false;
  bool hasBackupGenerator = false;
  bool hasCctv = false;
  bool hasElevator = false;
  bool petFriendly = false;
  bool hasAirConditioning = false;
  bool hasFittedKitchen = false;
  ListingType listingType = ListingType.basic;
  PropertyStatus status = PropertyStatus.available;

  List<PaymentTerm> paymentOptions = [PaymentTerm.monthly];
  PaymentTerm? minimumAcceptedTerm = PaymentTerm.monthly;
  bool depositRequired = false;

  final List<XFile> pickedImages = [];
  List<String> existingImages = [];

  PropertyFormData();

  /// Seeds every field from an existing property, for the edit screen.
  PropertyFormData.fromProperty(PropertyModel p) {
    titleController.text = p.title;
    descriptionController.text = p.description;
    locationController.text = p.location;
    streetController.text = p.street;
    priceController.text = p.rentPrice.toStringAsFixed(0);

    selectedDistrict = p.district.isNotEmpty ? p.district : LocationService.districtWards.keys.first;
    final savedWard = p.ward.isNotEmpty ? p.ward : LocationService.districtWards[selectedDistrict]!.first;
    if (savedWard.isNotEmpty && LocationService.districtWards[selectedDistrict]!.contains(savedWard)) {
      selectedWard = savedWard;
    } else if (savedWard.isNotEmpty) {
      selectedWard = LocationService.otherOption;
      otherWardController.text = savedWard;
    } else {
      selectedWard = LocationService.districtWards[selectedDistrict]!.first;
    }

    pin = LatLng(p.latitude, p.longitude);
    bedrooms = p.bedrooms;
    bathrooms = p.bathrooms;
    propertyType = p.propertyType;
    isFurnished = p.isFurnished;
    hasWater = p.hasWater;
    hasParking = p.hasParking;
    hasSecurity = p.hasSecurity;
    hasElectricity = p.hasElectricity;
    hasInternet = p.hasInternet;
    hasGym = p.hasGym;
    hasSwimmingPool = p.hasSwimmingPool;
    hasBalcony = p.hasBalcony;
    hasGarden = p.hasGarden;
    hasBackupGenerator = p.hasBackupGenerator;
    hasCctv = p.hasCctv;
    hasElevator = p.hasElevator;
    petFriendly = p.petFriendly;
    hasAirConditioning = p.hasAirConditioning;
    hasFittedKitchen = p.hasFittedKitchen;
    listingType = p.listingType;
    status = p.status;
    paymentOptions = List<PaymentTerm>.from(p.paymentOptions);
    minimumAcceptedTerm = p.minimumAcceptedTerm ?? (p.paymentOptions.isNotEmpty ? p.paymentOptions.first : null);
    depositRequired = p.depositRequired;
    depositController.text = p.depositAmount > 0 ? p.depositAmount.toStringAsFixed(0) : '';
    existingImages = List<String>.from(p.images);
  }

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    locationController.dispose();
    streetController.dispose();
    otherWardController.dispose();
    priceController.dispose();
    depositController.dispose();
  }
}

/// The property information / photos / details / amenities / listing
/// options / rental terms sections shared by AddPropertyScreen and
/// EditPropertyScreen. Callers own [data], wrap this in their own
/// `Form(key: ...)`, and read `data.*` directly on submit.
class PropertyFormFields extends StatefulWidget {
  final PropertyFormData data;
  final bool isPremium;

  const PropertyFormFields({super.key, required this.data, required this.isPremium});

  @override
  State<PropertyFormFields> createState() => _PropertyFormFieldsState();
}

class _PropertyFormFieldsState extends State<PropertyFormFields> {
  bool _isDetectingAddress = false;
  final _picker = ImagePicker();

  PropertyFormData get _d => widget.data;

  Future<void> _updatePinFromLocation() async {
    final loc = _d.locationController.text;
    if (loc.isEmpty) return;

    setState(() {
      _d.pin = LocationService.resolveCoordinates(loc);
      _isDetectingAddress = true;
    });

    final address = await LocationService.reverseGeocodeAddress(_d.pin.latitude, _d.pin.longitude);
    final districtWard = LocationService.resolveDistrictWard(loc);

    setState(() {
      final candidateDistrict = address['district']?.isNotEmpty == true && LocationService.districtWards.containsKey(address['district'])
          ? address['district']!
          : districtWard['district'] ?? _d.selectedDistrict;
      final candidateWard = address['ward']?.isNotEmpty == true ? address['ward']! : districtWard['ward'] ?? _d.selectedWard;
      _d.selectedDistrict = candidateDistrict;
      if (LocationService.districtWards[candidateDistrict]?.contains(candidateWard) == true) {
        _d.selectedWard = candidateWard;
        _d.otherWardController.clear();
      } else if (candidateWard.isNotEmpty) {
        _d.selectedWard = LocationService.otherOption;
        _d.otherWardController.text = candidateWard;
      } else {
        _d.selectedWard = LocationService.districtWards[candidateDistrict]!.first;
        _d.otherWardController.clear();
      }
      _d.streetController.text = address['street'] ?? _d.streetController.text;
      _isDetectingAddress = false;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final picked = await _picker.pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked.isNotEmpty) {
        setState(() => _d.pickedImages.addAll(picked));
      }
    } else {
      final picked = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (picked != null) {
        setState(() => _d.pickedImages.add(picked));
      }
    }
  }

  void _removeNewImage(int index) => setState(() => _d.pickedImages.removeAt(index));
  void _removeExistingImage(int index) => setState(() => _d.existingImages.removeAt(index));

  Future<void> _openMapPicker() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(builder: (_) => PropertyMapPickerScreen(initial: _d.pin)),
    );
    if (result != null) {
      setState(() => _d.pin = result);
    }
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

  @override
  Widget build(BuildContext context) {
    final totalImages = _d.existingImages.length + _d.pickedImages.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _d.titleController,
          decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _d.descriptionController,
          decoration: const InputDecoration(labelText: 'Description *', border: OutlineInputBorder()),
          maxLines: 3,
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _d.locationController,
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
          controller: _d.streetController,
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
                initialValue: _d.selectedDistrict,
                decoration: const InputDecoration(labelText: 'District', border: OutlineInputBorder()),
                items: LocationService.districtWards.keys
                    .map((district) => DropdownMenuItem(value: district, child: Text(district)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _d.selectedDistrict = value;
                    _d.selectedWard = LocationService.districtWards[value]!.first;
                    _d.otherWardController.clear();
                  });
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _d.selectedWard,
                decoration: const InputDecoration(labelText: 'Ward', border: OutlineInputBorder()),
                items: LocationService.districtWards[_d.selectedDistrict]!
                    .map((ward) => DropdownMenuItem(value: ward, child: Text(ward)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _d.selectedWard = value;
                    if (value != LocationService.otherOption) {
                      _d.otherWardController.clear();
                    }
                  });
                },
              ),
            ),
          ],
        ),
        if (_d.selectedWard == LocationService.otherOption)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextFormField(
              controller: _d.otherWardController,
              decoration: const InputDecoration(labelText: 'Enter Ward Name', border: OutlineInputBorder()),
              validator: (value) {
                if (_d.selectedWard == LocationService.otherOption && (value == null || value.trim().isEmpty)) {
                  return 'Enter ward name';
                }
                return null;
              },
            ),
          ),
        if (_isDetectingAddress)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
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
                    initialCenter: _d.pin,
                    initialZoom: 14,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
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
                          point: _d.pin,
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
                          'Pin: ${_d.pin.latitude.toStringAsFixed(4)}, ${_d.pin.longitude.toStringAsFixed(4)}',
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
        if (totalImages == 0)
          Card(
            child: InkWell(
              onTap: _showImageSourceSheet,
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
                  itemCount: totalImages + 1,
                  itemBuilder: (context, index) {
                    if (index == totalImages) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: InkWell(
                          onTap: _showImageSourceSheet,
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

                    final isExisting = index < _d.existingImages.length;
                    final imageUrl = isExisting ? _d.existingImages[index] : null;
                    final newIndex = isExisting ? null : index - _d.existingImages.length;

                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: isExisting
                                ? Image.network(
                                    imageUrl!,
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 110,
                                      height: 110,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image),
                                    ),
                                  )
                                : Image.file(
                                    File(_d.pickedImages[newIndex!].path),
                                    width: 110,
                                    height: 110,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => isExisting ? _removeExistingImage(index) : _removeNewImage(newIndex!),
                              child: Container(
                                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle),
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
                '$totalImages photo${totalImages > 1 ? 's' : ''} selected',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        const SizedBox(height: 16),

        const Text('Property Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<PropertyType>(
          initialValue: _d.propertyType,
          decoration: const InputDecoration(labelText: 'Property Type', border: OutlineInputBorder()),
          items: PropertyType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.name[0].toUpperCase() + t.name.substring(1))))
              .toList(),
          onChanged: (v) => setState(() => _d.propertyType = v!),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _d.priceController,
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
                      IconButton(onPressed: () => setState(() => _d.bedrooms = (_d.bedrooms - 1).clamp(0, 10)), icon: const Icon(Icons.remove)),
                      Text('${_d.bedrooms}', style: const TextStyle(fontSize: 18)),
                      IconButton(onPressed: () => setState(() => _d.bedrooms = (_d.bedrooms + 1).clamp(0, 10)), icon: const Icon(Icons.add)),
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
                      IconButton(onPressed: () => setState(() => _d.bathrooms = (_d.bathrooms - 1).clamp(0, 10)), icon: const Icon(Icons.remove)),
                      Text('${_d.bathrooms}', style: const TextStyle(fontSize: 18)),
                      IconButton(onPressed: () => setState(() => _d.bathrooms = (_d.bathrooms + 1).clamp(0, 10)), icon: const Icon(Icons.add)),
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
        SwitchListTile(title: const Text('Furnished'), value: _d.isFurnished, onChanged: (v) => setState(() => _d.isFurnished = v)),
        SwitchListTile(title: const Text('Water Available'), value: _d.hasWater, onChanged: (v) => setState(() => _d.hasWater = v)),
        SwitchListTile(title: const Text('Electricity'), value: _d.hasElectricity, onChanged: (v) => setState(() => _d.hasElectricity = v)),
        SwitchListTile(title: const Text('Internet / WiFi'), value: _d.hasInternet, onChanged: (v) => setState(() => _d.hasInternet = v)),
        SwitchListTile(title: const Text('Parking'), value: _d.hasParking, onChanged: (v) => setState(() => _d.hasParking = v)),
        SwitchListTile(title: const Text('Security'), value: _d.hasSecurity, onChanged: (v) => setState(() => _d.hasSecurity = v)),
        SwitchListTile(title: const Text('CCTV'), value: _d.hasCctv, onChanged: (v) => setState(() => _d.hasCctv = v)),
        SwitchListTile(title: const Text('Backup Generator'), value: _d.hasBackupGenerator, onChanged: (v) => setState(() => _d.hasBackupGenerator = v)),
        SwitchListTile(title: const Text('Air Conditioning'), value: _d.hasAirConditioning, onChanged: (v) => setState(() => _d.hasAirConditioning = v)),
        SwitchListTile(title: const Text('Fitted Kitchen'), value: _d.hasFittedKitchen, onChanged: (v) => setState(() => _d.hasFittedKitchen = v)),
        SwitchListTile(title: const Text('Swimming Pool'), value: _d.hasSwimmingPool, onChanged: (v) => setState(() => _d.hasSwimmingPool = v)),
        SwitchListTile(title: const Text('Gym'), value: _d.hasGym, onChanged: (v) => setState(() => _d.hasGym = v)),
        SwitchListTile(title: const Text('Elevator / Lift'), value: _d.hasElevator, onChanged: (v) => setState(() => _d.hasElevator = v)),
        SwitchListTile(title: const Text('Balcony'), value: _d.hasBalcony, onChanged: (v) => setState(() => _d.hasBalcony = v)),
        SwitchListTile(title: const Text('Garden / Yard'), value: _d.hasGarden, onChanged: (v) => setState(() => _d.hasGarden = v)),
        SwitchListTile(title: const Text('Pet Friendly'), value: _d.petFriendly, onChanged: (v) => setState(() => _d.petFriendly = v)),
        const SizedBox(height: 16),
        const Text('Listing Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        DropdownButtonFormField<ListingType>(
          initialValue: _d.listingType,
          decoration: const InputDecoration(labelText: 'Listing Type', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: ListingType.basic, child: Text('Basic (Free)')),
            if (widget.isPremium) const DropdownMenuItem(value: ListingType.featured, child: Text('Featured (Premium)')),
          ],
          onChanged: (v) => setState(() => _d.listingType = v!),
        ),
        if (!widget.isPremium)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('Upgrade to Premium to feature your listings.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PropertyStatus>(
          initialValue: _d.status,
          decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
          items: PropertyStatus.values
              .map((s) => DropdownMenuItem(value: s, child: Text(s.name[0].toUpperCase() + s.name.substring(1))))
              .toList(),
          onChanged: (v) => setState(() => _d.status = v!),
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
            final selected = _d.paymentOptions.contains(term);
            return FilterChip(
              label: Text(Helpers.paymentTermLabel(term)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _d.paymentOptions.add(term);
                  } else {
                    _d.paymentOptions.remove(term);
                  }
                  if (_d.minimumAcceptedTerm != null && !_d.paymentOptions.contains(_d.minimumAcceptedTerm)) {
                    _d.minimumAcceptedTerm = _d.paymentOptions.isNotEmpty ? _d.paymentOptions.first : null;
                  }
                });
              },
              selectedColor: Colors.teal.shade100,
              checkmarkColor: Colors.teal,
              labelStyle: TextStyle(color: selected ? Colors.teal.shade800 : Colors.black),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PaymentTerm>(
          initialValue: _d.minimumAcceptedTerm,
          decoration: const InputDecoration(labelText: 'Minimum Accepted Term', border: OutlineInputBorder()),
          items: _d.paymentOptions.map((term) => DropdownMenuItem(value: term, child: Text(Helpers.paymentTermLabel(term)))).toList(),
          onChanged: (v) => setState(() => _d.minimumAcceptedTerm = v),
          validator: (v) => v == null ? 'Select a minimum accepted term' : null,
        ),
        const SizedBox(height: 12),
        SwitchListTile(title: const Text('Deposit Required'), value: _d.depositRequired, onChanged: (v) => setState(() => _d.depositRequired = v)),
        if (_d.depositRequired) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _d.depositController,
            decoration: const InputDecoration(labelText: 'Deposit Amount (TZS) *', border: OutlineInputBorder()),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (!_d.depositRequired) return null;
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
      ],
    );
  }
}

/// Full-screen draggable pin picker, shared by both property screens.
class PropertyMapPickerScreen extends StatefulWidget {
  final LatLng initial;
  const PropertyMapPickerScreen({super.key, required this.initial});

  @override
  State<PropertyMapPickerScreen> createState() => _PropertyMapPickerScreenState();
}

class _PropertyMapPickerScreenState extends State<PropertyMapPickerScreen> {
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
