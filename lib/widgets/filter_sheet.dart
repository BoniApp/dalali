import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/utils/helpers.dart';

class FilterSheet extends StatefulWidget {
  final Map<String, dynamic> initialFilters;
  final Function(Map<String, dynamic>) onApply;

  const FilterSheet({super.key, required this.initialFilters, required this.onApply});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late double minPrice;
  late double maxPrice;
  late int? selectedBedrooms;
  late bool? furnished;
  late bool? water;
  late bool? parking;
  late PropertyType? selectedType;
  late List<PaymentTerm> selectedPaymentTerms;

  @override
  void initState() {
    super.initState();
    minPrice = widget.initialFilters['minPrice'] ?? 0;
    maxPrice = widget.initialFilters['maxPrice'] ?? 10000000;
    selectedBedrooms = widget.initialFilters['bedrooms'];
    furnished = widget.initialFilters['furnished'];
    water = widget.initialFilters['water'];
    parking = widget.initialFilters['parking'];
    selectedType = widget.initialFilters['type'];
    selectedPaymentTerms = List<PaymentTerm>.from(widget.initialFilters['paymentTerms'] ?? []);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filter Properties', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(),
          const Text('Property Type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'All',
                selected: selectedType == null,
                onSelected: (val) => setState(() => selectedType = null),
              ),
              ...PropertyType.values.map((type) => _FilterChip(
                label: type.name[0].toUpperCase() + type.name.substring(1),
                selected: selectedType == type,
                onSelected: (val) => setState(() => selectedType = type),
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Price Range (TZS)', style: TextStyle(fontWeight: FontWeight.w600)),
          RangeSlider(
            values: RangeValues(minPrice, maxPrice),
            min: 0,
            max: 10000000,
            divisions: 20,
            labels: RangeLabels(
              'TZS ${minPrice.toInt()}',
              'TZS ${maxPrice.toInt()}',
            ),
            onChanged: (values) {
              setState(() {
                minPrice = values.start;
                maxPrice = values.end;
              });
            },
          ),
          const SizedBox(height: 16),
          const Text('Bedrooms', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: selectedBedrooms == null,
                onSelected: (val) => setState(() => selectedBedrooms = null),
              ),
              ...List.generate(5, (i) => _FilterChip(
                label: i == 4 ? '4+' : '$i',
                selected: selectedBedrooms == (i == 4 ? 4 : i),
                onSelected: (val) => setState(() => selectedBedrooms = i == 4 ? 4 : i),
              )),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Amenities', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _ToggleChip(
                label: 'Furnished',
                value: furnished,
                onChanged: (v) => setState(() => furnished = v),
              ),
              _ToggleChip(
                label: 'Water',
                value: water,
                onChanged: (v) => setState(() => water = v),
              ),
              _ToggleChip(
                label: 'Parking',
                value: parking,
                onChanged: (v) => setState(() => parking = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Payment Terms', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(
                label: 'Any',
                selected: selectedPaymentTerms.isEmpty,
                onSelected: (val) => setState(() => selectedPaymentTerms.clear()),
              ),
              ...PaymentTerm.values.map((term) => _FilterChip(
                label: Helpers.paymentTermLabel(term),
                selected: selectedPaymentTerms.contains(term),
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      selectedPaymentTerms.add(term);
                    } else {
                      selectedPaymentTerms.remove(term);
                    }
                  });
                },
              )),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply({
                  'minPrice': minPrice,
                  'maxPrice': maxPrice,
                  'bedrooms': selectedBedrooms,
                  'furnished': furnished,
                  'water': water,
                  'parking': parking,
                  'type': selectedType,
                  'paymentTerms': selectedPaymentTerms.isNotEmpty ? List<PaymentTerm>.from(selectedPaymentTerms) : null,
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _FilterChip({required this.label, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: Colors.teal.shade100,
      labelStyle: TextStyle(
        color: selected ? Colors.teal.shade800 : Colors.black,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _ToggleChip({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value == true,
      onSelected: (selected) {
        if (value == null) {
          onChanged(true);
        } else if (value == true) {
          onChanged(false);
        } else {
          onChanged(null);
        }
      },
      selectedColor: Colors.teal.shade100,
      checkmarkColor: Colors.teal,
      labelStyle: TextStyle(
        color: value == true ? Colors.teal.shade800 : Colors.black,
      ),
    );
  }
}
