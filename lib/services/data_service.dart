import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/favorite_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// DATA SERVICE — Supabase PostgreSQL wrapper
///
/// Replaces FirestoreService. Provides CRUD operations for all
/// core data collections using Supabase PostgREST + Realtime.
/// ═══════════════════════════════════════════════════════════════
class DataService {
  static final _db = SupabaseService.client;

  // ═══════════════════════════════════════════════════════════════
  //  USERS
  // ═══════════════════════════════════════════════════════════════

  Future<UserModel?> getUserById(String uid) async {
    final data = await _db.from('users').select().eq('id', uid).maybeSingle();
    if (data == null) return null;
    return _userFromJson(data);
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROPERTIES
  // ═══════════════════════════════════════════════════════════════

  Stream<List<PropertyModel>> getProperties({int limit = 20}) {
    return _db
        .from('properties')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .where((r) => r['status'] == 'available' && r['is_approved'] == true)
            .map(_propertyFromJson)
            .toList());
  }

  Future<List<PropertyModel>> getPropertiesPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _db
        .from('properties')
        .select()
        .eq('status', 'available')
        .eq('is_approved', true)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return rows.map(_propertyFromJson).toList();
  }

  Future<void> addProperty(PropertyModel property) async {
    final json = _propertyToJson(property);
    try {
      await _db.from('properties').insert(json);
    } catch (e) {
      debugPrint('addProperty error: $e');
      rethrow;
    }
  }

  Future<void> updateProperty(PropertyModel property) async {
    await _db
        .from('properties')
        .update(_propertyToJson(property))
        .eq('id', property.id);
  }

  Future<void> deleteProperty(String id) async {
    await _db.from('properties').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  //  FAVORITES
  // ═══════════════════════════════════════════════════════════════

  Stream<List<String>> getFavoritePropertyIds(String userId) {
    return _db
        .from('favorites')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((r) => r['property_id'] as String).toList());
  }

  Future<void> addFavorite(String userId, String propertyId) async {
    await _db.from('favorites').insert({
      'user_id': userId,
      'property_id': propertyId,
    });
  }

  Future<void> removeFavorite(String userId, String propertyId) async {
    await _db
        .from('favorites')
        .delete()
        .eq('user_id', userId)
        .eq('property_id', propertyId);
  }

  // ═══════════════════════════════════════════════════════════════
  //  APPOINTMENTS
  // ═══════════════════════════════════════════════════════════════

  Stream<List<AppointmentModel>> getAppointments(String userId, {bool isLandlord = false}) {
    final builder = _db
        .from('appointments')
        .stream(primaryKey: ['id']);

    if (isLandlord) {
      return builder
          .eq('landlord_id', userId)
          .map((rows) => rows.map(_appointmentFromJson).toList());
    }
    return builder
        .eq('seeker_id', userId)
        .map((rows) => rows.map(_appointmentFromJson).toList());
  }

  Future<void> addAppointment(AppointmentModel appointment) async {
    final json = _appointmentToJson(appointment);
    json.remove('id');
    await _db.from('appointments').insert(json);
  }

  Future<void> updateAppointmentStatus(String id, AppointmentStatus status) async {
    await _db
        .from('appointments')
        .update({'status': status.name})
        .eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  //  INQUIRIES
  // ═══════════════════════════════════════════════════════════════

  Stream<List<InquiryModel>> getInquiriesForLandlord(String landlordId) {
    return _db
        .from('inquiries')
        .stream(primaryKey: ['id'])
        .map((rows) => rows.map(_inquiryFromJson).toList());
  }

  Future<void> addInquiry(InquiryModel inquiry) async {
    final json = _inquiryToJson(inquiry);
    json.remove('id');
    await _db.from('inquiries').insert(json);
  }

  Future<void> markInquiryRead(String id) async {
    await _db.from('inquiries').update({'is_read': true}).eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  //  STUBS — Phase 3 & 4 (Reviews, Reports, Tenancy, etc.)
  // ═══════════════════════════════════════════════════════════════

  Future<void> addReview(dynamic review) async {}
  Future<void> addNeighbourhoodReport(dynamic report) async {}
  Future<void> addTenancyApplication(dynamic application) async {}
  Future<void> updateApplicationStatus(String id, dynamic status) async {}
  Future<void> addTenancy(dynamic tenancy) async {}
  Future<void> updateTenancyStatus(String id, dynamic status) async {}
  Future<void> addMaintenanceRequest(dynamic request) async {}
  Future<void> updateMaintenanceStatus(String id, dynamic status, {String? resolutionNotes}) async {}
  Future<void> markRentPaid(String scheduleId) async {}
  Stream<List<dynamic>> getReviews({int limit = 20}) => const Stream.empty();
  Stream<List<dynamic>> getMoveListingsByUser(String userId) => const Stream.empty();
  Stream<List<dynamic>> getRewardsForUser(String userId) => const Stream.empty();
  Stream<List<dynamic>> getNeighbourhoodReports({int limit = 200}) => const Stream.empty();
  Stream<List<dynamic>> getApplicationsForLandlord(String id) => const Stream.empty();
  Stream<List<dynamic>> getApplicationsForTenant(String id) => const Stream.empty();
  Stream<List<dynamic>> getTenanciesForLandlord(String id) => const Stream.empty();
  Stream<List<dynamic>> getTenanciesForTenant(String id) => const Stream.empty();
  Stream<List<dynamic>> getMaintenanceForLandlord(String id) => const Stream.empty();
  Stream<List<dynamic>> getMaintenanceForTenant(String id) => const Stream.empty();
  Stream<List<dynamic>> getRentSchedulesForTenant(String id) => const Stream.empty();

  // ═══════════════════════════════════════════════════════════════
  //  SERIALIZATION HELPERS
  // ═══════════════════════════════════════════════════════════════

  // ─── User ────────────────────────────────────────────────────

  UserModel _userFromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.seeker,
      ),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verification_status'],
        orElse: () => VerificationStatus.unverified,
      ),
      isPhoneVerified: json['is_phone_verified'] ?? false,
      profileImage: json['profile_image'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      nationalId: json['national_id'],
      agentLicense: json['agent_license'],
      subscriptionTier: json['subscription_tier'] ?? 0,
      isVerifiedLandlord: json['is_verified_landlord'] ?? false,
      lastActive: json['last_active'] != null
          ? DateTime.tryParse(json['last_active'])
          : null,
      savedSearches: List<String>.from(json['saved_searches'] ?? []),
      preferredLocations: List<String>.from(json['preferred_locations'] ?? []),
      moveMode: MoveMode.values.firstWhere(
        (e) => e.name == json['move_mode'],
        orElse: () => MoveMode.none,
      ),
      activeMoveListingId: json['active_move_listing_id'],
      totalRewardPoints: json['total_reward_points'] ?? 0,
    );
  }

  // ─── Property ────────────────────────────────────────────────

  PropertyModel _propertyFromJson(Map<String, dynamic> json) {
    return PropertyModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      rentPrice: (json['rent_price'] as num?)?.toDouble() ?? 0.0,
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      propertyType: PropertyType.values.firstWhere(
        (e) => e.name == json['property_type'],
        orElse: () => PropertyType.apartment,
      ),
      isFurnished: json['is_furnished'] ?? false,
      hasWater: json['has_water'] ?? false,
      hasParking: json['has_parking'] ?? false,
      hasSecurity: json['has_security'] ?? false,
      sharedCompound: json['shared_compound'] ?? false,
      hasBorehole: json['has_borehole'] ?? false,
      images: List<String>.from(json['images'] ?? []),
      videoUrl: json['video_url'],
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.available,
      ),
      listingType: ListingType.values.firstWhere(
        (e) => e.name == json['listing_type'],
        orElse: () => ListingType.basic,
      ),
      sourceType: ListingSource.values.firstWhere(
        (e) => e.name == json['source_type'],
        orElse: () => ListingSource.landlordListing,
      ),
      landlordId: json['landlord_id'] ?? '',
      landlordName: json['landlord_name'] ?? '',
      landlordPhone: json['landlord_phone'] ?? '',
      isLandlordVerified: json['is_landlord_verified'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      viewCount: json['view_count'] ?? 0,
      inquiryCount: json['inquiry_count'] ?? 0,
      isApproved: json['is_approved'] ?? true,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] ?? 0,
      isBoosted: json['is_boosted'] ?? false,
      boostExpiresAt: json['boost_expires_at'] != null
          ? DateTime.tryParse(json['boost_expires_at'])
          : null,
      tags: List<String>.from(json['tags'] ?? []),
      utilities: _utilitiesFromJson(json['utilities']),
      safetyScore: (json['safety_score'] as num?)?.toDouble() ?? 80.0,
      incidentCount: json['incident_count'] ?? 0,
      rentAmount: (json['rent_amount'] as num?)?.toDouble() ?? 0.0,
      paymentOptions: (json['payment_options'] as List<dynamic>?)
              ?.map((e) => PaymentTerm.values.firstWhere(
                    (t) => t.name == e,
                    orElse: () => PaymentTerm.monthly,
                  ))
              .toList() ??
          const [PaymentTerm.monthly],
      minimumAcceptedTerm: json['minimum_accepted_term'] != null
          ? PaymentTerm.values.firstWhere(
              (e) => e.name == json['minimum_accepted_term'],
              orElse: () => PaymentTerm.monthly,
            )
          : null,
      depositRequired: json['deposit_required'] ?? false,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> _propertyToJson(PropertyModel p) {
    final json = <String, dynamic>{
      'title': p.title,
      'description': p.description,
      'location': p.location,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'rent_price': p.rentPrice,
      'bedrooms': p.bedrooms,
      'bathrooms': p.bathrooms,
      'property_type': p.propertyType.name,
      'is_furnished': p.isFurnished,
      'has_water': p.hasWater,
      'has_parking': p.hasParking,
      'has_security': p.hasSecurity,
      'shared_compound': p.sharedCompound,
      'has_borehole': p.hasBorehole,
      'images': p.images,
      'status': p.status.name,
      'listing_type': p.listingType.name,
      'source_type': p.sourceType.name,
      'landlord_id': p.landlordId,
      'landlord_name': p.landlordName,
      'landlord_phone': p.landlordPhone,
      'is_landlord_verified': p.isLandlordVerified,
      'created_at': p.createdAt.toIso8601String(),
      'view_count': p.viewCount,
      'inquiry_count': p.inquiryCount,
      'is_approved': p.isApproved,
      'rating': p.rating,
      'review_count': p.reviewCount,
      'is_boosted': p.isBoosted,
      'tags': p.tags,
      'utilities': p.utilities.toJson(),
      'safety_score': p.safetyScore,
      'incident_count': p.incidentCount,
      'rent_amount': p.rentAmount,
      'payment_options': p.paymentOptions.map((e) => e.name).toList(),
      'deposit_required': p.depositRequired,
      'deposit_amount': p.depositAmount,
    };

    // Only add nullable fields if they have values
    if (p.videoUrl != null) json['video_url'] = p.videoUrl;
    if (p.updatedAt != null) json['updated_at'] = p.updatedAt!.toIso8601String();
    if (p.boostExpiresAt != null) json['boost_expires_at'] = p.boostExpiresAt!.toIso8601String();
    if (p.minimumAcceptedTerm != null) json['minimum_accepted_term'] = p.minimumAcceptedTerm!.name;

    return json;
  }

  PropertyUtilities _utilitiesFromJson(dynamic json) {
    if (json == null || json is! Map) return const PropertyUtilities();
    final m = json as Map<String, dynamic>;
    return PropertyUtilities(
      water: UtilityResponsibility.values.firstWhere(
        (e) => e.name == m['water'],
        orElse: () => UtilityResponsibility.shared,
      ),
      electricity: UtilityResponsibility.values.firstWhere(
        (e) => e.name == m['electricity'],
        orElse: () => UtilityResponsibility.shared,
      ),
      internet: InternetType.values.firstWhere(
        (e) => e.name == m['internet'],
        orElse: () => InternetType.notAvailable,
      ),
      wasteCollection: UtilityResponsibility.values.firstWhere(
        (e) => e.name == m['wasteCollection'],
        orElse: () => UtilityResponsibility.shared,
      ),
      security: SecurityType.values.firstWhere(
        (e) => e.name == m['security'],
        orElse: () => SecurityType.notIncluded,
      ),
    );
  }

  // ─── Appointment ─────────────────────────────────────────────

  AppointmentModel _appointmentFromJson(Map<String, dynamic> json) {
    return AppointmentModel(
      id: json['id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      seekerId: json['seeker_id'] ?? '',
      seekerName: json['seeker_name'] ?? '',
      seekerPhone: json['seeker_phone'] ?? '',
      landlordId: json['landlord_id'] ?? '',
      scheduledDate: DateTime.tryParse(json['scheduled_date'] ?? '') ?? DateTime.now(),
      notes: json['notes'] ?? '',
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _appointmentToJson(AppointmentModel a) {
    return {
      'id': a.id,
      'property_id': a.propertyId,
      'property_title': a.propertyTitle,
      'seeker_id': a.seekerId,
      'seeker_name': a.seekerName,
      'seeker_phone': a.seekerPhone,
      'landlord_id': a.landlordId,
      'scheduled_date': a.scheduledDate.toIso8601String(),
      'notes': a.notes,
      'status': a.status.name,
      'created_at': a.createdAt.toIso8601String(),
    };
  }

  // ─── Inquiry ─────────────────────────────────────────────────

  InquiryModel _inquiryFromJson(Map<String, dynamic> json) {
    return InquiryModel(
      id: json['id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      seekerId: json['seeker_id'] ?? '',
      seekerName: json['seeker_name'] ?? '',
      seekerPhone: json['seeker_phone'] ?? '',
      message: json['message'] ?? '',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      isRead: json['is_read'] ?? false,
    );
  }

  Map<String, dynamic> _inquiryToJson(InquiryModel i) {
    return {
      'id': i.id,
      'property_id': i.propertyId,
      'property_title': i.propertyTitle,
      'seeker_id': i.seekerId,
      'seeker_name': i.seekerName,
      'seeker_phone': i.seekerPhone,
      'message': i.message,
      'created_at': i.createdAt.toIso8601String(),
      'is_read': i.isRead,
    };
  }
}
