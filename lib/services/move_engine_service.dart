import 'dart:developer' show log;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/firestore_service.dart';

/// Orchestrates the "I'm Moving" flow:
/// 1. User starts move → creates MoveListing + auto-lists current home
/// 2. User browses new properties while old home is listed
/// 3. User finds new home → marks move complete
/// 4. System awards points
class MoveEngineService {
  final FirestoreService _firestore = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Starts a new move for the user.
  /// Creates a move_listing doc and auto-creates a property listing
  /// for their current home (if they provide details).
  Future<MoveListingModel> startMove({
    required UserModel user,
    required String currentPropertyTitle,
    required String currentLocation,
    required DateTime moveDate,
    double? budgetMin,
    double? budgetMax,
    String? preferredLocation,
    PropertyModel? currentHomeDetails,
  }) async {
    // 1. Create move listing
    final move = MoveListingModel(
      id: '', // Firestore will assign
      userId: user.id,
      userName: user.fullName,
      currentPropertyTitle: currentPropertyTitle,
      currentLocation: currentLocation,
      moveDate: moveDate,
      status: MoveStatus.planning,
      budgetMin: budgetMin,
      budgetMax: budgetMax,
      preferredLocation: preferredLocation,
      createdAt: DateTime.now(),
    );

    final moveRef = await _firestore.addMoveListing(move);
    final moveId = moveRef.id;

    // 2. Optionally auto-list their current home as a property
    String? propertyId;
    if (currentHomeDetails != null) {
      final homeToList = currentHomeDetails.copyWith(
        id: '',
        landlordId: user.id,
        landlordName: user.fullName,
        landlordPhone: user.phone,
        sourceType: ListingSource.userMoveListing,
        status: PropertyStatus.available,
        createdAt: DateTime.now(),
        isApproved: false, // requires moderation
      );
      final propRef = await _db.collection('properties').add(
        _propertyToJson(homeToList),
      );
      propertyId = propRef.id;
    }

    // 3. Update user move mode
    await _db.collection('users').doc(user.id).update({
      'moveMode': 'planning',
      'activeMoveListingId': moveId,
    });

    log('🚚 Move started: $moveId for user ${user.id}');

    return move.copyWith(
      id: moveId,
      currentPropertyId: propertyId,
    );
  }

  /// Marks a move as active (user has begun the transition).
  Future<void> activateMove(String moveId, String userId) async {
    await _firestore.updateMoveStatus(moveId, MoveStatus.active);
    await _db.collection('users').doc(userId).update({
      'moveMode': 'active',
    });
    log('▶️ Move activated: $moveId');
  }

  /// Completes a move. User found a new home.
  Future<void> completeMove({
    required String moveId,
    required String userId,
    required String newPropertyId,
  }) async {
    await _firestore.updateMoveStatus(moveId, MoveStatus.completed, newPropertyId: newPropertyId);
    await _db.collection('users').doc(userId).update({
      'moveMode': 'none',
      'activeMoveListingId': null,
    });
    log('✅ Move completed: $moveId → $newPropertyId');
  }

  /// Cancels an in-progress move.
  Future<void> cancelMove(String moveId, String userId) async {
    await _firestore.updateMoveStatus(moveId, MoveStatus.cancelled);
    await _db.collection('users').doc(userId).update({
      'moveMode': 'none',
      'activeMoveListingId': null,
    });
    log('❌ Move cancelled: $moveId');
  }

  // ─── Helper to serialize PropertyModel inline ───────────────

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
      'sharedCompound': p.sharedCompound,
      'hasBorehole': p.hasBorehole,
      'images': p.images,
      'videoUrl': p.videoUrl,
      'status': p.status.name,
      'listingType': p.listingType.name,
      'sourceType': p.sourceType.name,
      'landlordId': p.landlordId,
      'landlordName': p.landlordName,
      'landlordPhone': p.landlordPhone,
      'isLandlordVerified': p.isLandlordVerified,
      'createdAt': Timestamp.fromDate(p.createdAt),
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
}
