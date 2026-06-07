import 'dart:developer' show log;
import 'dart:math' show Random;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'package:dalali/firebase_options.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/favorite_model.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/review_model.dart';
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/services/mock_data_service.dart';

enum SeedMode { demoSmall, demoLarge, productionReset }

/// Seeder that creates all Firestore collections and fills them with data.
///
/// ## Usage from a dev/debug screen:
/// ```dart
/// final seeder = FirestoreSeeder();
/// await seeder.seedAll(mode: SeedMode.demoLarge);
/// ```
///
/// ## Usage as a one-off script:
/// ```bash
/// flutter run -t lib/utils/seed_firestore.dart -d windows
/// ```
class FirestoreSeeder {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');
  CollectionReference get _properties => _db.collection('properties');
  CollectionReference get _appointments => _db.collection('appointments');
  CollectionReference get _inquiries => _db.collection('inquiries');
  CollectionReference get _favorites => _db.collection('favorites');
  CollectionReference get _moveListings => _db.collection('move_listings');
  CollectionReference get _reviews => _db.collection('reviews');
  CollectionReference get _rewards => _db.collection('rewards');
  CollectionReference get _neighbourhoodReports => _db.collection('neighbourhood_reports');

  // ─── Main API ───────────────────────────────────────────────

  Future<void> seedAll({SeedMode mode = SeedMode.demoSmall}) async {
    log('🌱 Starting seed mode: $mode');

    if (mode == SeedMode.productionReset) {
      await clearAll();
    }

    await seedUsers();
    await seedProperties(mode: mode);
    await seedAppointments(mode: mode);
    await seedInquiries(mode: mode);
    await seedFavorites(mode: mode);
    await seedMoveListings();
    await seedReviews();
    await seedRewards();
    await seedNeighbourhoodReports();

    log('✅ Firestore seeding complete ($mode)');
  }

  Future<void> clearAll() async {
    log('🗑️ Clearing all collections...');
    await _deleteCollection(_users);
    await _deleteCollection(_properties);
    await _deleteCollection(_appointments);
    await _deleteCollection(_inquiries);
    await _deleteCollection(_favorites);
    await _deleteCollection(_moveListings);
    await _deleteCollection(_reviews);
    await _deleteCollection(_rewards);
    await _deleteCollection(_neighbourhoodReports);
    log('🗑️ All collections cleared');
  }

  // ─── Users ──────────────────────────────────────────────────

  Future<void> seedUsers() async {
    await _batchWrite(
      _users,
      MockDataService.users.map((u) => (u.id, _userToJson(u))),
    );
    log('👤 Seeded ${MockDataService.users.length} users');
  }

  Map<String, dynamic> _userToJson(UserModel u) {
    return {
      'fullName': u.fullName,
      'email': u.email,
      'phone': u.phone,
      'role': u.role.name,
      'verificationStatus': u.verificationStatus.name,
      'isPhoneVerified': u.isPhoneVerified,
      'profileImage': u.profileImage,
      'createdAt': Timestamp.fromDate(u.createdAt),
      'nationalId': u.nationalId,
      'agentLicense': u.agentLicense,
      'subscriptionTier': u.subscriptionTier,
      'isVerifiedLandlord': u.isVerifiedLandlord,
      'lastActive': u.lastActive != null ? Timestamp.fromDate(u.lastActive!) : null,
      'savedSearches': u.savedSearches,
      'preferredLocations': u.preferredLocations,
      'moveMode': u.moveMode.name,
      'activeMoveListingId': u.activeMoveListingId,
      'totalRewardPoints': u.totalRewardPoints,
    };
  }

  // ─── Properties ─────────────────────────────────────────────

  Future<void> seedProperties({SeedMode mode = SeedMode.demoSmall}) async {
    final properties = MockDataService.properties.toList();

    if (mode == SeedMode.demoLarge) {
      // Generate 50 extra randomized properties
      final random = Random(42);
      final locations = [
        ('Masaki, Dar es Salaam', -6.7480, 39.2710),
        ('Mikocheni, Dar es Salaam', -6.7630, 39.2500),
        ('Oyster Bay, Dar es Salaam', -6.7400, 39.2800),
        ('Ubungo, Dar es Salaam', -6.7924, 39.2083),
        ('City Centre, Dodoma', -6.1731, 35.7419),
        ('Nyamagana, Mwanza', -2.5167, 32.9000),
        ('Upanga, Dar es Salaam', -6.8100, 39.2700),
        ('Kariakoo, Dar es Salaam', -6.8200, 39.2700),
        ('Kijitonyama, Dar es Salaam', -6.7700, 39.2400),
        ('Arusha City, Arusha', -3.3869, 36.6830),
      ];
      final tanzaniaImages = [
        'https://upload.wikimedia.org/wikipedia/commons/4/40/Buildings_in_Mikocheni%2C_Kinondoni_MC.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/4/44/Building_in_Kawe_ward%2C_Kinondoni_MC.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/f/f4/Building_in_Chang%27ombe_ward%2C_Temeke_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/9/9a/Building_in_Kiwalani%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/5/59/Building_in_Makuburi%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/8/8e/Building_in_Gongolamboto%2C_Ilala_MC.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/b/bb/Building_in_Buguruni%2C_Ilala_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/e/e4/Building_in_Tandika%2C_Temeke_MC%2C_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/f/f4/Colonial-Era_Facade_-_Dar_es_Salaam_-_Tanzania_-_01.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/a/ad/Colonial-Era_Facade_-_Dar_es_Salaam_-_Tanzania_-_02.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/4/4c/Bagamoyo_house_Dar_es_Salaam.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/3/3b/A_house_in_tanga.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/3/32/A_house_in_Tanga_2.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/e/ed/A_house_in_Datoga_tribe_Arusha_region_Tanzania.jpg',
        'https://upload.wikimedia.org/wikipedia/commons/1/17/British_council_Dar_es_salaam.jpg',
      ];
      final landlords = MockDataService.users.where((u) => u.role == UserRole.landlord || u.role == UserRole.agent).toList();
      final types = PropertyType.values;

      for (var i = 0; i < 50; i++) {
        final loc = locations[random.nextInt(locations.length)];
        final landlord = landlords[random.nextInt(landlords.length)];
        final type = types[random.nextInt(types.length)];
        final bedrooms = type == PropertyType.bedsitter ? 1 : random.nextInt(4) + 1;
        final bathrooms = type == PropertyType.bedsitter ? 1 : random.nextInt(3) + 1;
        final price = (random.nextInt(85) + 5) * 50000.0; // 250K - 4.5M
        final created = DateTime(2024, 1 + random.nextInt(6), 1 + random.nextInt(28));

        properties.add(PropertyModel(
          id: 'p_gen_$i',
          title: '${_typeLabel(type)} in ${loc.$1.split(',').first}',
          description: 'Auto-generated demo property for testing pagination and filtering.',
          location: loc.$1,
          latitude: loc.$2 + (random.nextDouble() - 0.5) * 0.02,
          longitude: loc.$3 + (random.nextDouble() - 0.5) * 0.02,
          rentPrice: price,
          bedrooms: bedrooms,
          bathrooms: bathrooms,
          propertyType: type,
          isFurnished: random.nextBool(),
          hasWater: random.nextBool(),
          hasParking: random.nextBool(),
          hasSecurity: random.nextBool(),
          images: [tanzaniaImages[random.nextInt(tanzaniaImages.length)]],
          sourceType: ListingSource.landlordListing,
          landlordId: landlord.id,
          landlordName: landlord.fullName,
          landlordPhone: landlord.phone,
          createdAt: created,
          updatedAt: created.add(const Duration(days: 1)),
          viewCount: random.nextInt(500),
          inquiryCount: random.nextInt(30),
          rating: random.nextDouble() * 2 + 3, // 3.0 - 5.0
          reviewCount: random.nextInt(25),
          isBoosted: random.nextInt(10) == 0,
          tags: ['demo', 'auto-generated'],
        ));
      }
    }

    await _batchWrite(
      _properties,
      properties.map((p) => (p.id, _propertyToJson(p))),
    );
    log('🏠 Seeded ${properties.length} properties');
  }

  String _typeLabel(PropertyType t) => switch (t) {
    PropertyType.apartment => 'Apartment',
    PropertyType.house => 'House',
    PropertyType.villa => 'Villa',
    PropertyType.bedsitter => 'Bedsitter',
    PropertyType.office => 'Office',
    PropertyType.shop => 'Shop',
  };

  Map<String, dynamic> _propertyToJson(PropertyModel p) {
    return {
      'title': p.title,
      'description': p.description,
      'location': p.location,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'rentPrice': p.rentPrice,
      'bedrooms': p.bedrooms,
      'bathrooms': p.bathrooms,
      'propertyType': p.propertyType.name,
      'isFurnished': p.isFurnished,
      'hasWater': p.hasWater,
      'hasParking': p.hasParking,
      'hasSecurity': p.hasSecurity,
      'images': p.images,
      'videoUrl': p.videoUrl,
      'status': p.status.name,
      'listingType': p.listingType.name,
      'landlordId': p.landlordId,
      'landlordName': p.landlordName,
      'landlordPhone': p.landlordPhone,
      'isLandlordVerified': p.isLandlordVerified,
      'createdAt': Timestamp.fromDate(p.createdAt),
      'updatedAt': p.updatedAt != null ? Timestamp.fromDate(p.updatedAt!) : FieldValue.serverTimestamp(),
      'viewCount': p.viewCount,
      'inquiryCount': p.inquiryCount,
      'isApproved': p.isApproved,
      'rating': p.rating,
      'reviewCount': p.reviewCount,
      'isBoosted': p.isBoosted,
      'boostExpiresAt': p.boostExpiresAt != null ? Timestamp.fromDate(p.boostExpiresAt!) : null,
      'tags': p.tags,
      'utilities': p.utilities.toJson(),
    };
  }

  // ─── Appointments ───────────────────────────────────────────

  Future<void> seedAppointments({SeedMode mode = SeedMode.demoSmall}) async {
    final appointments = MockDataService.appointments.toList();

    if (mode == SeedMode.demoLarge) {
      final random = Random(43);
      final seekers = MockDataService.users.where((u) => u.role == UserRole.seeker).toList();
      final props = MockDataService.properties;

      for (var i = 0; i < 30; i++) {
        final p = props[random.nextInt(props.length)];
        final s = seekers[random.nextInt(seekers.length)];
        appointments.add(AppointmentModel(
          id: 'a_gen_$i',
          propertyId: p.id,
          propertyTitle: p.title,
          seekerId: s.id,
          seekerName: s.fullName,
          seekerPhone: s.phone,
          landlordId: p.landlordId,
          scheduledDate: DateTime(2024, 7, 1 + random.nextInt(30), 9 + random.nextInt(8)),
          notes: 'Auto-generated appointment.',
          status: AppointmentStatus.values[random.nextInt(4)],
          createdAt: DateTime(2024, 6, 1 + random.nextInt(15)),
        ));
      }
    }

    await _batchWrite(
      _appointments,
      appointments.map((a) => (a.id, _appointmentToJson(a))),
    );
    log('📅 Seeded ${appointments.length} appointments');
  }

  Map<String, dynamic> _appointmentToJson(AppointmentModel a) {
    return {
      'propertyId': a.propertyId,
      'propertyTitle': a.propertyTitle,
      'seekerId': a.seekerId,
      'seekerName': a.seekerName,
      'seekerPhone': a.seekerPhone,
      'landlordId': a.landlordId,
      'scheduledDate': Timestamp.fromDate(a.scheduledDate),
      'notes': a.notes,
      'status': a.status.name,
      'createdAt': Timestamp.fromDate(a.createdAt),
    };
  }

  // ─── Inquiries ──────────────────────────────────────────────

  Future<void> seedInquiries({SeedMode mode = SeedMode.demoSmall}) async {
    final inquiries = MockDataService.inquiries.toList();

    if (mode == SeedMode.demoLarge) {
      final random = Random(44);
      final seekers = MockDataService.users.where((u) => u.role == UserRole.seeker).toList();
      final props = MockDataService.properties;
      final messages = [
        'Is the price negotiable?',
        'Can I visit this weekend?',
        'Do you allow pets?',
        'Is water included in the rent?',
        'How far is it from the main road?',
        'Is parking available for 2 cars?',
        'Can I get a discount for long-term lease?',
        'Is the neighbourhood safe at night?',
      ];

      for (var i = 0; i < 40; i++) {
        final p = props[random.nextInt(props.length)];
        final s = seekers[random.nextInt(seekers.length)];
        inquiries.add(InquiryModel(
          id: 'i_gen_$i',
          propertyId: p.id,
          propertyTitle: p.title,
          seekerId: s.id,
          seekerName: s.fullName,
          seekerPhone: s.phone,
          message: messages[random.nextInt(messages.length)],
          createdAt: DateTime(2024, 6, 1 + random.nextInt(20)),
          isRead: random.nextBool(),
        ));
      }
    }

    await _batchWrite(
      _inquiries,
      inquiries.map((i) => (i.id, _inquiryToJson(i))),
    );
    log('💬 Seeded ${inquiries.length} inquiries');
  }

  Map<String, dynamic> _inquiryToJson(InquiryModel i) {
    return {
      'propertyId': i.propertyId,
      'propertyTitle': i.propertyTitle,
      'seekerId': i.seekerId,
      'seekerName': i.seekerName,
      'seekerPhone': i.seekerPhone,
      'message': i.message,
      'createdAt': Timestamp.fromDate(i.createdAt),
      'isRead': i.isRead,
    };
  }

  // ─── Favorites ──────────────────────────────────────────────

  Future<void> seedFavorites({SeedMode mode = SeedMode.demoSmall}) async {
    final favorites = MockDataService.favorites.toList();

    if (mode == SeedMode.demoLarge) {
      final random = Random(45);
      final seekers = MockDataService.users.where((u) => u.role == UserRole.seeker).toList();
      final props = MockDataService.properties;

      for (var i = 0; i < 20; i++) {
        final p = props[random.nextInt(props.length)];
        final s = seekers[random.nextInt(seekers.length)];
        favorites.add(FavoriteModel(
          id: 'f_gen_$i',
          userId: s.id,
          propertyId: p.id,
          createdAt: DateTime(2024, 5, 1 + random.nextInt(30)),
        ));
      }
    }

    await _batchWrite(
      _favorites,
      favorites.map((f) => (f.id, _favoriteToJson(f))),
    );
    log('⭐ Seeded ${favorites.length} favorites');
  }

  Map<String, dynamic> _favoriteToJson(FavoriteModel f) {
    return {
      'userId': f.userId,
      'propertyId': f.propertyId,
      'createdAt': Timestamp.fromDate(f.createdAt),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: Move Listings
  // ═══════════════════════════════════════════════════════════

  Future<void> seedMoveListings() async {
    await _batchWrite(
      _moveListings,
      MockDataService.moveListings.map((m) => (m.id, _moveListingToJson(m))),
    );
    log('🚚 Seeded ${MockDataService.moveListings.length} move listings');
  }

  Map<String, dynamic> _moveListingToJson(MoveListingModel m) {
    return {
      'userId': m.userId,
      'userName': m.userName,
      'currentPropertyId': m.currentPropertyId,
      'currentPropertyTitle': m.currentPropertyTitle,
      'currentLocation': m.currentLocation,
      'moveDate': Timestamp.fromDate(m.moveDate),
      'status': m.status.name,
      'newPropertyId': m.newPropertyId,
      'budgetMin': m.budgetMin,
      'budgetMax': m.budgetMax,
      'preferredLocation': m.preferredLocation,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'updatedAt': m.updatedAt != null ? Timestamp.fromDate(m.updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: Reviews
  // ═══════════════════════════════════════════════════════════

  Future<void> seedReviews() async {
    await _batchWrite(
      _reviews,
      MockDataService.reviews.map((r) => (r.id, _reviewToJson(r))),
    );
    log('⭐ Seeded ${MockDataService.reviews.length} reviews');
  }

  Map<String, dynamic> _reviewToJson(ReviewModel r) {
    return {
      'propertyId': r.propertyId,
      'propertyTitle': r.propertyTitle,
      'reviewerId': r.reviewerId,
      'reviewerName': r.reviewerName,
      'stayVerified': r.stayVerified,
      'cleanliness': r.cleanliness,
      'valueForMoney': r.valueForMoney,
      'safety': r.safety,
      'communication': r.communication,
      'fairness': r.fairness,
      'maintenance': r.maintenance,
      'comment': r.comment,
      'createdAt': Timestamp.fromDate(r.createdAt),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: Rewards
  // ═══════════════════════════════════════════════════════════

  Future<void> seedRewards() async {
    await _batchWrite(
      _rewards,
      MockDataService.rewards.map((rw) => (rw.id, _rewardToJson(rw))),
    );
    log('🏆 Seeded ${MockDataService.rewards.length} rewards');
  }

  Map<String, dynamic> _rewardToJson(RewardModel rw) {
    return {
      'userId': rw.userId,
      'type': rw.type.name,
      'points': rw.points,
      'description': rw.description,
      'createdAt': Timestamp.fromDate(rw.createdAt),
      'claimed': rw.claimed,
      'claimedAt': rw.claimedAt != null ? Timestamp.fromDate(rw.claimedAt!) : null,
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: Neighbourhood Reports
  // ═══════════════════════════════════════════════════════════

  Future<void> seedNeighbourhoodReports() async {
    await _batchWrite(
      _neighbourhoodReports,
      MockDataService.neighbourhoodReports.map((r) => (r.id, _neighbourhoodReportToJson(r))),
    );
    log('🚨 Seeded ${MockDataService.neighbourhoodReports.length} neighbourhood reports');
  }

  Map<String, dynamic> _neighbourhoodReportToJson(NeighbourhoodReportModel r) {
    return {
      'reporterId': r.reporterId,
      'reporterName': r.reporterName,
      'reporterVerified': r.reporterVerified,
      'reporterTrustScore': r.reporterTrustScore,
      'type': r.type.name,
      'severity': r.severity.name,
      'location': r.location,
      'latitude': r.latitude,
      'longitude': r.longitude,
      'description': r.description,
      'reportedAt': Timestamp.fromDate(r.reportedAt),
      'resolved': r.resolved,
      'resolvedAt': r.resolvedAt != null ? Timestamp.fromDate(r.resolvedAt!) : null,
      'resolvedBy': r.resolvedBy,
    };
  }

  // ─── Batch Write Helper (Firestore 500 doc limit) ───────────

  Future<void> _batchWrite(
    CollectionReference ref,
    Iterable<(String id, Map<String, dynamic> data)> items,
  ) async {
    final docs = items.toList();
    const batchSize = 450; // stay safely under 500

    for (var i = 0; i < docs.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = docs.skip(i).take(batchSize);
      for (final (id, data) in chunk) {
        batch.set(ref.doc(id), data);
      }
      await batch.commit();
    }
  }

  Future<void> _deleteCollection(CollectionReference ref) async {
    var snapshot = await ref.limit(100).get();
    while (snapshot.docs.isNotEmpty) {
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      snapshot = await ref.limit(100).get();
    }
  }
}

// ─── Standalone entrypoint ────────────────────────────────────
// Run with: flutter run -t lib/utils/seed_firestore.dart -d windows
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final seeder = FirestoreSeeder();
  await seeder.seedAll(mode: SeedMode.demoLarge);
}
