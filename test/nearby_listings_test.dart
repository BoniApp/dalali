import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/nearby_listings_service.dart';

void main() {
  group('NearbyListingsService.formatDistanceMeters', () {
    test('formats sub-kilometer distances in meters', () {
      expect(NearbyListingsService.formatDistanceMeters(450), '450 m');
      expect(NearbyListingsService.formatDistanceMeters(999.4), '999 m');
      expect(NearbyListingsService.formatDistanceMeters(0), '0 m');
    });

    test('formats kilometer distances with one decimal', () {
      expect(NearbyListingsService.formatDistanceMeters(1200), '1.2 km');
      expect(NearbyListingsService.formatDistanceMeters(2800), '2.8 km');
      expect(NearbyListingsService.formatDistanceMeters(1000), '1.0 km');
    });

    test('returns empty string for unknown distance', () {
      expect(NearbyListingsService.formatDistanceMeters(null), '');
    });
  });

  group('NearbyListingsService.compactTzs', () {
    test('formats thousands with k suffix', () {
      expect(NearbyListingsService.compactTzs(250000), 'Tsh 250k');
      expect(NearbyListingsService.compactTzs(450000), 'Tsh 450k');
      expect(NearbyListingsService.compactTzs(250500), 'Tsh 250.5k');
    });

    test('formats millions with M suffix', () {
      expect(NearbyListingsService.compactTzs(1000000), 'Tsh 1M');
      expect(NearbyListingsService.compactTzs(1500000), 'Tsh 1.5M');
    });

    test('formats small amounts as-is', () {
      expect(NearbyListingsService.compactTzs(800), 'Tsh 800');
    });
  });

  group('NearbyListingsService.nextRadiusMeters (smart radius)', () {
    test('walks up the radius steps', () {
      expect(NearbyListingsService.nextRadiusMeters(500), 1000);
      expect(NearbyListingsService.nextRadiusMeters(1000), 2000);
      expect(NearbyListingsService.nextRadiusMeters(2000), 5000);
      expect(NearbyListingsService.nextRadiusMeters(5000), 10000);
    });

    test('falls back to city radius after the last step', () {
      expect(
        NearbyListingsService.nextRadiusMeters(10000),
        NearbyListingsService.cityRadiusMeters,
      );
    });

    test('stops at city radius', () {
      expect(
        NearbyListingsService.nextRadiusMeters(
            NearbyListingsService.cityRadiusMeters),
        isNull,
      );
    });
  });

  group('NearbyFilter', () {
    test('default filter is empty', () {
      expect(const NearbyFilter().isEmpty, isTrue);
    });

    test('any set field makes it non-empty and changes the cache key', () {
      const base = NearbyFilter();
      const priced = NearbyFilter(minPrice: 100000);
      const premium = NearbyFilter(premiumOnly: true);
      expect(priced.isEmpty, isFalse);
      expect(premium.isEmpty, isFalse);
      expect(base.cacheKey, isNot(priced.cacheKey));
      expect(base.cacheKey, isNot(premium.cacheKey));
    });
  });

  group('PropertyModel.fromJson distance parsing', () {
    Map<String, dynamic> minimalRow() => {
          'id': 'p1',
          'title': 'Test apartment',
          'description': '',
          'location': 'Mikocheni, Dar es Salaam',
          'latitude': -6.763,
          'longitude': 39.25,
          'rent_price': 450000,
          'bedrooms': 2,
          'bathrooms': 1,
          'property_type': 'apartment',
          'images': <String>[],
          'landlord_id': 'l1',
          'landlord_name': 'Landlord',
          'landlord_phone': '0700000000',
          'created_at': '2026-01-01T00:00:00Z',
        };

    test('maps distance_meters from RPC rows', () {
      final row = minimalRow()..['distance_meters'] = 450.7;
      final property = PropertyModel.fromJson(row);
      expect(property.distanceMeters, closeTo(450.7, 0.001));
    });

    test('distanceMeters is null for regular property rows', () {
      final property = PropertyModel.fromJson(minimalRow());
      expect(property.distanceMeters, isNull);
    });
  });
}
