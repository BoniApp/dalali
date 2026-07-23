import 'dart:developer' show log;
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Orchestrates the "I'm Moving" flow:
/// 1. User starts move → creates MoveListing + auto-lists current home
/// 2. User browses new properties while old home is listed
/// 3. User finds new home → marks move complete
/// 4. System awards points
class MoveEngineService {
  final _db = SupabaseService.client;

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
      id: '', // server assigns
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

    final moveData = await _db.from('move_listings').insert({
      'user_id': user.id,
      'user_name': user.fullName,
      'current_property_title': currentPropertyTitle,
      'current_location': currentLocation,
      'move_date': moveDate.toIso8601String(),
      'status': 'planning',
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'preferred_location': preferredLocation,
      'created_at': DateTime.now().toIso8601String(),
    }).select('id').single();
    final moveId = moveData['id'] as String;

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
      final propData = await _db.from('properties').insert(
        _propertyToJson(homeToList),
      ).select('id').single();
      propertyId = propData['id'] as String;
    }

    // 3. Update user move mode
    await _db.from('users').update({
      'move_mode': 'planning',
      'active_move_listing_id': moveId,
    }).eq('id', user.id);

    log('🚚 Move started: $moveId for user ${user.id}');

    return move.copyWith(
      id: moveId,
      currentPropertyId: propertyId,
    );
  }

  /// Marks a move as active (user has begun the transition).
  Future<void> activateMove(String moveId, String userId) async {
    await _db.from('move_listings').update({'status': 'active'}).eq('id', moveId);
    await _db.from('users').update({
      'move_mode': 'active',
    }).eq('id', userId);
    log('▶️ Move activated: $moveId');
  }

  /// Completes a move. User found a new home.
  Future<void> completeMove({
    required String moveId,
    required String userId,
    required String newPropertyId,
  }) async {
    await _db.from('move_listings').update({
      'status': 'completed',
      'new_property_id': newPropertyId,
    }).eq('id', moveId);
    await _db.from('users').update({
      'move_mode': 'none',
      'active_move_listing_id': null,
    }).eq('id', userId);
    log('✅ Move completed: $moveId → $newPropertyId');
  }

  /// Cancels an in-progress move.
  Future<void> cancelMove(String moveId, String userId) async {
    await _db.from('move_listings').update({'status': 'cancelled'}).eq('id', moveId);
    await _db.from('users').update({
      'move_mode': 'none',
      'active_move_listing_id': null,
    }).eq('id', userId);
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
      'created_at': p.createdAt.toIso8601String(),
      'view_count': p.viewCount,
      'inquiry_count': p.inquiryCount,
      'is_approved': p.isApproved,
      'rating': p.rating,
      'review_count': p.reviewCount,
      'is_boosted': p.isBoosted,
      'boost_expires_at': p.boostExpiresAt?.toIso8601String(),
      'tags': p.tags,
      'utilities': p.utilities.toJson(),
    };
  }
}
