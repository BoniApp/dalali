import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/matching_engine.dart';

PropertyModel _property({
  required String id,
  double rentPrice = 200000,
  String location = 'Masaki, Dar es Salaam',
  DateTime? createdAt,
  double rating = 0,
  bool isLandlordVerified = false,
  ListingType listingType = ListingType.basic,
}) {
  return PropertyModel(
    id: id,
    title: 'Property $id',
    description: 'A nice place',
    location: location,
    latitude: -6.7924,
    longitude: 39.2083,
    rentPrice: rentPrice,
    bedrooms: 2,
    bathrooms: 1,
    propertyType: PropertyType.apartment,
    isFurnished: false,
    hasWater: true,
    hasParking: false,
    hasSecurity: false,
    images: const ['https://example.com/a.jpg'],
    landlordId: 'landlord1',
    landlordName: 'Landlord',
    landlordPhone: '+255700000000',
    createdAt: createdAt ?? DateTime.now().subtract(const Duration(days: 5)),
    rating: rating,
    isLandlordVerified: isLandlordVerified,
    listingType: listingType,
  );
}

MoveListingModel _move({
  double? budgetMin,
  double? budgetMax,
  String? preferredLocation,
}) {
  return MoveListingModel(
    id: 'move1',
    userId: 'user1',
    userName: 'Test User',
    currentPropertyTitle: 'Old place',
    currentLocation: 'Kinondoni',
    moveDate: DateTime.now().add(const Duration(days: 14)),
    budgetMin: budgetMin,
    budgetMax: budgetMax,
    preferredLocation: preferredLocation,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('MatchingEngine.matchForMove', () {
    test('ranks a property within budget above one far outside it', () {
      final inBudget = _property(id: 'in-budget', rentPrice: 250000);
      final overBudget = _property(id: 'over-budget', rentPrice: 900000);
      final move = _move(budgetMin: 200000, budgetMax: 300000);

      final results = MatchingEngine().matchForMove(
        move: move,
        user: null,
        allProperties: [overBudget, inBudget],
        favoritePropertyIds: const [],
      );

      expect(results.first.id, 'in-budget');
    });

    test('boosts a property matching the preferred location', () {
      final matchingLocation = _property(id: 'masaki', location: 'Masaki, Dar es Salaam');
      final otherLocation = _property(id: 'mbezi', location: 'Mbezi Beach');
      final move = _move(preferredLocation: 'Masaki');

      final results = MatchingEngine().matchForMove(
        move: move,
        user: null,
        allProperties: [otherLocation, matchingLocation],
        favoritePropertyIds: const [],
      );

      expect(results.first.id, 'masaki');
    });

    test('respects maxResults truncation', () {
      final properties = List.generate(5, (i) => _property(id: 'p$i'));
      final move = _move();

      final results = MatchingEngine().matchForMove(
        move: move,
        user: null,
        allProperties: properties,
        favoritePropertyIds: const [],
        maxResults: 2,
      );

      expect(results.length, 2);
    });

    test('handles an empty property list', () {
      final results = MatchingEngine().matchForMove(
        move: _move(),
        user: null,
        allProperties: const [],
        favoritePropertyIds: const [],
      );

      expect(results, isEmpty);
    });
  });

  group('MatchingEngine.findMovesNearLocation', () {
    test('excludes completed and cancelled moves', () {
      final active = MoveListingModel(
        id: 'active',
        userId: 'u1',
        userName: 'A',
        currentPropertyTitle: 'x',
        currentLocation: 'Masaki',
        moveDate: DateTime.now(),
        status: MoveStatus.active,
        createdAt: DateTime.now(),
      );
      final completed = MoveListingModel(
        id: 'completed',
        userId: 'u2',
        userName: 'B',
        currentPropertyTitle: 'x',
        currentLocation: 'Masaki',
        moveDate: DateTime.now(),
        status: MoveStatus.completed,
        createdAt: DateTime.now(),
      );

      final results = MatchingEngine().findMovesNearLocation(
        locationQuery: 'Masaki',
        allMoves: [active, completed],
      );

      expect(results.map((m) => m.id), contains('active'));
      expect(results.map((m) => m.id), isNot(contains('completed')));
    });

    test('ranks a location match above a non-match', () {
      final matching = MoveListingModel(
        id: 'matching',
        userId: 'u1',
        userName: 'A',
        currentPropertyTitle: 'x',
        currentLocation: 'Masaki',
        moveDate: DateTime.now(),
        createdAt: DateTime.now(),
      );
      final nonMatching = MoveListingModel(
        id: 'non-matching',
        userId: 'u2',
        userName: 'B',
        currentPropertyTitle: 'x',
        currentLocation: 'Mbezi',
        moveDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      final results = MatchingEngine().findMovesNearLocation(
        locationQuery: 'Masaki',
        allMoves: [nonMatching, matching],
      );

      expect(results.first.id, 'matching');
    });
  });
}
