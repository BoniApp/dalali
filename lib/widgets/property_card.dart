import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dalali/widgets/safety_badge.dart';
import 'package:dalali/utils/helpers.dart';

class PropertyCard extends StatelessWidget {
  final PropertyModel property;
  final VoidCallback? onTap;

  const PropertyCard({super.key, required this.property, this.onTap});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'sw_TZ',
      symbol: 'TZS ',
      decimalDigits: 0,
    );
    final isFav = context.watch<AppState>().isFavorite(property.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: Image.network(
                    property.images.first,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 50),
                        ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    alignment: WrapAlignment.end,
                    children: [
                      if (property.listingType == ListingType.featured)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'FEATURED',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      SafetyBadge(safetyScore: property.safetyScore, compact: true),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: IconButton(
                          iconSize: 14,
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color: isFav ? Colors.red : Colors.grey,
                          ),
                          onPressed: () {
                            context.read<AppState>().toggleFavorite(property.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (property.isLandlordVerified)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'VERIFIED',
                            style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.title,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          property.location,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${currencyFormat.format(property.rentAmount > 0 ? property.rentAmount : property.rentPrice)}/month',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          _IconText(Icons.bed, '${property.bedrooms}'),
                          const SizedBox(width: 6),
                          _IconText(Icons.bathtub, '${property.bathrooms}'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: _chips(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  /// Payment-term + amenity chips, capped so the card stays inside
  /// fixed-height parents (e.g. the featured carousel).
  static const int _maxChips = 6;

  List<Widget> _chips() {
    final chips = <Widget>[
      ...property.paymentOptions.take(3).map((term) =>
            _Chip(Helpers.paymentTermLabel(term), AppTheme.primary.withAlpha(13), AppTheme.primaryDark),
          ),
      if (property.paymentOptions.length > 3)
        _Chip('+${property.paymentOptions.length - 3} more', Colors.grey.shade100, Colors.grey.shade700),
      if (property.isFurnished)
        _Chip('Furnished', Colors.orange.shade100, Colors.orange.shade800),
      if (property.hasWater)
        _Chip('Water', Colors.blue.shade100, Colors.blue.shade800),
      if (property.hasElectricity)
        _Chip('Power', Colors.amber.shade100, Colors.amber.shade800),
      if (property.hasInternet)
        _Chip('WiFi', Colors.indigo.shade100, Colors.indigo.shade800),
      if (property.hasParking)
        _Chip('Parking', Colors.green.shade100, Colors.green.shade800),
      if (property.hasSecurity)
        _Chip('Security', Colors.purple.shade100, Colors.purple.shade800),
      if (property.hasCctv)
        _Chip('CCTV', Colors.red.shade100, Colors.red.shade800),
      if (property.hasBackupGenerator)
        _Chip('Gen', Colors.yellow.shade100, Colors.yellow.shade800),
      if (property.hasAirConditioning)
        _Chip('AC', Colors.cyan.shade100, Colors.cyan.shade800),
      if (property.hasFittedKitchen)
        _Chip('Kitchen', Colors.brown.shade100, Colors.brown.shade800),
      if (property.hasSwimmingPool)
        _Chip('Pool', Colors.lightBlue.shade100, Colors.lightBlue.shade800),
      if (property.hasGym)
        _Chip('Gym', Colors.deepOrange.shade100, Colors.deepOrange.shade800),
      if (property.hasElevator)
        _Chip('Lift', Colors.grey.shade200, Colors.grey.shade800),
      if (property.hasBalcony)
        _Chip('Balcony', Colors.pink.shade100, Colors.pink.shade800),
      if (property.hasGarden)
        _Chip('Garden', Colors.lightGreen.shade100, Colors.lightGreen.shade800),
      if (property.petFriendly)
        _Chip('Pets', AppTheme.primary.withAlpha(26), AppTheme.primaryDark),
    ];
    if (chips.length <= _maxChips) return chips;
    return [
      ...chips.take(_maxChips),
      _Chip('+${chips.length - _maxChips} more', Colors.grey.shade100, Colors.grey.shade700),
    ];
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconText(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey),
        const SizedBox(width: 2),
        Text(text, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  const _Chip(this.label, this.bgColor, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: textColor)),
    );
  }
}
