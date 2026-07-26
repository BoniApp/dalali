import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/recommendation_engine.dart';

PropertyModel _property({
  required String id,
  double rating = 0,
  int reviewCount = 0,
  bool isBoosted = false,
  ListingType listingType = ListingType.basic,
  String location = 'Masaki, Dar es Salaam',
  String title = 'A property',
  String description = 'Nice place',
  double rentPrice = 200000,
  int bedrooms = 2,
  bool isFurnished = false,
  bool hasParking = false,
  bool hasSecurity = false,
  int viewCount = 0,
  int inquiryCount = 0,
}) {
  return PropertyModel(
    id: id,
    title: title,
    description: description,
    location: location,
    latitude: -6.7924,
    longitude: 39.2083,
    rentPrice: rentPrice,
    bedrooms: bedrooms,
    bathrooms: 1,
    propertyType: PropertyType.apartment,
    isFurnished: isFurnished,
    hasWater: true,
    hasParking: hasParking,
    hasSecurity: hasSecurity,
    images: const ['https://example.com/a.jpg'],
    landlordId: 'landlord1',
    landlordName: 'Landlord',
    landlordPhone: '+255700000000',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    rating: rating,
    reviewCount: reviewCount,
    isBoosted: isBoosted,
    listingType: listingType,
    viewCount: viewCount,
    inquiryCount: inquiryCount,
  );
}

UserModel _user({List<String> preferredLocations = const [], List<String> savedSearches = const []}) {
  return UserModel(
    id: 'u1',
    fullName: 'Test User',
    email: 'test@example.com',
    phone: '+255700000000',
    role: UserRole.seeker,
    createdAt: DateTime.now(),
    preferredLocations: preferredLocations,
    savedSearches: savedSearches,
  );
}

void main() {
  group('RecommendationEngine.recommendForUser', () {
    test('ranks a higher-rated property above a lower-rated one', () {
      final good = _property(id: 'good', rating: 4.8);
      final poor = _property(id: 'poor', rating: 1.0);

      final results = RecommendationEngine().recommendForUser(
        user: null,
        allProperties: [poor, good],
        favoritePropertyIds: const [],
      );

      expect(results.first.id, 'good');
    });

    test('boosts a property matching the user\'s preferred location', () {
      final matching = _property(id: 'masaki', location: 'Masaki, Dar es Salaam');
      final other = _property(id: 'mbezi', location: 'Mbezi Beach');
      final user = _user(preferredLocations: const ['Masaki']);

      final results = RecommendationEngine().recommendForUser(
        user: user,
        allProperties: [other, matching],
        favoritePropertyIds: const [],
      );

      expect(results.first.id, 'masaki');
    });

    test('boosts a property matching a saved search keyword', () {
      final matching = _property(id: 'match', title: 'Cozy studio in Masaki');
      final other = _property(id: 'other', title: 'Spacious house');
      final user = _user(savedSearches: const ['studio']);

      final results = RecommendationEngine().recommendForUser(
        user: user,
        allProperties: [other, matching],
        favoritePropertyIds: const [],
      );

      expect(results.first.id, 'match');
    });

    test('respects maxResults truncation', () {
      final properties = List.generate(5, (i) => _property(id: 'p$i'));

      final results = RecommendationEngine().recommendForUser(
        user: null,
        allProperties: properties,
        favoritePropertyIds: const [],
        maxResults: 3,
      );

      expect(results.length, 3);
    });
  });

  group('RecommendationEngine.similarTo', () {
    test('excludes the source property itself', () {
      final source = _property(id: 'source');
      final other = _property(id: 'other');

      final results = RecommendationEngine().similarTo(
        source: source,
        allProperties: [source, other],
      );

      expect(results.map((p) => p.id), isNot(contains('source')));
    });

    test('ranks a same-type, similar-price property above a mismatched one', () {
      final source = _property(id: 'source', rentPrice: 200000, bedrooms: 2);
      final similar = _property(id: 'similar', rentPrice: 210000, bedrooms: 2);
      final dissimilar = _property(id: 'dissimilar', rentPrice: 900000, bedrooms: 5);

      final results = RecommendationEngine().similarTo(
        source: source,
        allProperties: [dissimilar, similar],
      );

      expect(results.first.id, 'similar');
    });
  });
}
