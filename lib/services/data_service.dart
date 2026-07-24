import 'dart:async';
import 'dart:developer' show log;
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/notification_model.dart';
import 'package:dalali/models/property_registry_model.dart';
import 'package:dalali/models/property_claim_model.dart';
import 'package:dalali/models/deal_model.dart';
import 'package:dalali/models/agency_fee_model.dart';
import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// DATA SERVICE — Supabase PostgreSQL wrapper
///
/// Provides CRUD operations for all
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

  Future<void> updateUserProfileImage(String userId, String imageUrl) async {
    await _db.from('users').update({'profile_image': imageUrl}).eq('id', userId);
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

  Stream<List<PropertyModel>> getMyProperties(String landlordId, {int limit = 100}) {
    return _db
        .from('properties')
        .stream(primaryKey: ['id'])
        .eq('landlord_id', landlordId)
        .limit(limit)
        .map((rows) => rows.map(_propertyFromJson).toList());
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

  Future<PropertyModel?> getPropertyById(String id) async {
    final data = await _db.from('properties').select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return _propertyFromJson(data);
  }

  Future<void> addProperty(PropertyModel property) async {
    final json = _propertyToJson(property);
    try {
      await _db.from('properties').insert(json);
    } catch (e) {
      log('addProperty error: $e');
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

  Future<void> incrementPropertyView(String propertyId, int currentViews) async {
    await _db.from('properties').update({'view_count': currentViews + 1}).eq('id', propertyId);
  }

  // ═══════════════════════════════════════════════════════════════
  //  FAVORITES
  // ═════════════════════════════════════════════════════════════==

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
        .eq('landlord_id', landlordId)
        .map((rows) => rows.map(_inquiryFromJson).toList());
  }

  Stream<List<InquiryModel>> getInquiriesForSeeker(String seekerId) {
    return _db
        .from('inquiries')
        .stream(primaryKey: ['id'])
        .eq('seeker_id', seekerId)
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

  Future<void> incrementPropertyInquiryCount(String propertyId, int currentCount) async {
    await _db.from('properties').update({'inquiry_count': currentCount + 1}).eq('id', propertyId);
  }

  // ═══════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════════

  Stream<List<NotificationModel>> getNotificationsForUser(String userId) {
    return _db
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_notificationFromJson).toList());
  }

  Future<void> markNotificationRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllNotificationsRead(String userId) async {
    await _db.from('notifications').update({'is_read': true}).eq('user_id', userId).eq('is_read', false);
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROPERTY REGISTRY
  // ═══════════════════════════════════════════════════════════════

  Future<PropertyRegistryModel?> getRegistryByHash(String propertyHash) async {
    final data = await _db.from('property_registry').select().eq('property_hash', propertyHash).maybeSingle();
    if (data == null) return null;
    return PropertyRegistryModel.fromJson(data);
  }

  Future<PropertyRegistryModel?> getRegistryById(String registryId) async {
    final data = await _db.from('property_registry').select().eq('registry_id', registryId).maybeSingle();
    if (data == null) return null;
    return PropertyRegistryModel.fromJson(data);
  }

  Future<void> addRegistry(PropertyRegistryModel registry) async {
    await _db.from('property_registry').insert(registry.toJson());
  }

  Stream<List<PropertyRegistryModel>> getPropertyRegistry({int limit = 100}) {
    return _db.from('property_registry').stream(primaryKey: ['registry_id'])
        .limit(limit)
        .map((rows) => rows.map(PropertyRegistryModel.fromJson).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  PROPERTY CLAIMS
  // ═══════════════════════════════════════════════════════════════

  Future<void> addPropertyClaim(PropertyClaimModel claim) async {
    await _db.from('property_claims').insert(claim.toJson());
  }

  Future<void> updatePropertyClaim(PropertyClaimModel claim) async {
    await _db.from('property_claims').update(claim.toJson()).eq('claim_id', claim.claimId);
  }

  Stream<List<PropertyClaimModel>> getPropertyClaims({String? propertyId, ClaimStatus? status}) {
    dynamic builder = _db.from('property_claims').stream(primaryKey: ['claim_id']);
    if (propertyId != null) builder = builder.eq('property_id', propertyId);
    if (status != null) builder = builder.eq('status', status.name);
    return builder.map((rows) => rows.map(PropertyClaimModel.fromJson).toList());
  }

  Stream<List<PropertyClaimModel>> getClaimsForUser(String userId) {
    return _db.from('property_claims').stream(primaryKey: ['claim_id'])
        .eq('claimant_id', userId)
        .map((rows) => rows.map(PropertyClaimModel.fromJson).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  DEALS
  // ═══════════════════════════════════════════════════════════════

  Future<void> addDeal(DealModel deal) async {
    await _db.from('deals').insert(deal.toJson());
  }

  Future<void> updateDeal(DealModel deal) async {
    await _db.from('deals').update(deal.toJson()).eq('deal_id', deal.dealId);
  }

  Stream<List<DealModel>> getDealsForUser(String userId) {
    return _db.from('deals').stream(primaryKey: ['deal_id'])
        .eq('listing_creator_id', userId)
        .map((rows) => rows.map(DealModel.fromJson).toList());
  }

  Stream<List<DealModel>> getDealsForProperty(String propertyId) {
    return _db.from('deals').stream(primaryKey: ['deal_id'])
        .eq('property_id', propertyId)
        .map((rows) => rows.map(DealModel.fromJson).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  AGENCY FEES
  // ═══════════════════════════════════════════════════════════════

  Future<void> addAgencyFee(AgencyFeeModel fee) async {
    await _db.from('agency_fees').insert(fee.toJson());
  }

  Future<void> updateAgencyFee(AgencyFeeModel fee) async {
    await _db.from('agency_fees').update(fee.toJson()).eq('fee_id', fee.feeId);
  }

  Stream<List<AgencyFeeModel>> getAgencyFeesForUser(String userId) {
    return _db.from('agency_fees').stream(primaryKey: ['fee_id'])
        .eq('listing_creator_id', userId)
        .map((rows) => rows.map(AgencyFeeModel.fromJson).toList());
  }

  Stream<List<AgencyFeeModel>> getPendingAgencyFees() {
    return _db.from('agency_fees').stream(primaryKey: ['fee_id'])
        .eq('status', AgencyFeeStatus.pending.name)
        .map((rows) => rows.map(AgencyFeeModel.fromJson).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  EARNINGS
  // ═══════════════════════════════════════════════════════════════

  Future<void> addEarningsEntry(EarningsEntryModel entry) async {
    await _db.from('earnings').insert(entry.toJson());
  }

  Future<void> updateEarningsEntry(EarningsEntryModel entry) async {
    await _db.from('earnings').update(entry.toJson()).eq('entry_id', entry.entryId);
  }

  Stream<List<EarningsEntryModel>> getEarningsForUser(String userId) {
    return _db.from('earnings').stream(primaryKey: ['entry_id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(EarningsEntryModel.fromJson).toList());
  }

  // ═══════════════════════════════════════════════════════════════
  //  KYC MODULE
  // ═══════════════════════════════════════════════════════════════

  Future<void> addKycSession(dynamic session) async {
    await _db.from('kyc_sessions').insert(session.toJson());
  }

  Future<void> updateKycSession(dynamic session) async {
    await _db.from('kyc_sessions').update(session.toJson()).eq('session_id', session.sessionId);
  }

  Future<dynamic> getKycSessionByUser(String userId) async {
    final data = await _db.from('kyc_sessions').select().eq('user_id', userId).maybeSingle();
    if (data == null) return null;
    return data;
  }

  Stream<List<dynamic>> getKycSessionsForAdmin() {
    return _db.from('kyc_sessions').stream(primaryKey: ['session_id'])
        .map((rows) => rows);
  }

  Future<void> addIdDocument(dynamic doc) async {
    await _db.from('id_documents').insert(doc.toJson());
  }

  Future<List<dynamic>> getIdDocumentsForUser(String userId) async {
    final rows = await _db.from('id_documents').select().eq('user_id', userId);
    return rows;
  }

  Future<void> addVerificationResult(dynamic result) async {
    await _db.from('verification_results').insert(result.toJson());
  }

  Future<List<dynamic>> getVerificationResultsForSession(String sessionId) async {
    final rows = await _db.from('verification_results').select().eq('session_id', sessionId);
    return rows;
  }

  Future<void> addKycAuditLog(dynamic log) async {
    await _db.from('kyc_audit_logs').insert(log.toJson());
  }

  // ═══════════════════════════════════════════════════════════════
  //  TENANCY APPLICATIONS & TENANCIES (migration 019)
  //
  //  These methods only write/read rows. All side effects —
  //  landlord/tenant notifications, tenancy creation on approval,
  //  property status reconciliation, transition enforcement — live in
  //  server-side triggers (see 019_tenancy_applications_and_tenancies.sql).
  // ═══════════════════════════════════════════════════════════════

  Stream<List<TenancyApplicationModel>> getApplicationsForLandlord(String landlordId) {
    return _db
        .from('tenancy_applications')
        .stream(primaryKey: ['id'])
        .eq('landlord_id', landlordId)
        .map((rows) => rows.map(_applicationFromJson).toList());
  }

  Stream<List<TenancyApplicationModel>> getApplicationsForTenant(String tenantId) {
    return _db
        .from('tenancy_applications')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .map((rows) => rows.map(_applicationFromJson).toList());
  }

  Future<void> addTenancyApplication(TenancyApplicationModel application) async {
    // id/created_at are DB-generated; the INSERT trigger notifies the landlord.
    await _db.from('tenancy_applications').insert({
      'property_id': application.propertyId,
      'property_title': application.propertyTitle,
      'tenant_id': application.tenantId,
      'tenant_name': application.tenantName,
      'tenant_phone': application.tenantPhone,
      'landlord_id': application.landlordId,
      'landlord_name': application.landlordName,
      'status': application.status.name,
      'notes': application.notes,
    });
  }

  /// Landlord resolves an application. `resolved_at` is stamped by the
  /// tenancy_application_guard trigger; on approval the
  /// handle_application_resolution() trigger creates the tenancy,
  /// reserves the property, and notifies the tenant.
  Future<void> updateApplicationStatus(String id, ApplicationStatus status, {String? notes}) async {
    await _db.from('tenancy_applications').update({
      'status': status.name,
      if (notes != null) 'notes': notes,
    }).eq('id', id);
  }

  Stream<List<TenancyModel>> getTenanciesForLandlord(String landlordId) {
    return _db
        .from('tenancies')
        .stream(primaryKey: ['id'])
        .eq('landlord_id', landlordId)
        .map((rows) => rows.map(_tenancyFromJson).toList());
  }

  Stream<List<TenancyModel>> getTenanciesForTenant(String tenantId) {
    return _db
        .from('tenancies')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .map((rows) => rows.map(_tenancyFromJson).toList());
  }

  /// Landlord advances the lifecycle (upcoming → active → completed).
  /// Timestamps and the property status flip are trigger-maintained.
  Future<void> updateTenancyStatus(String id, TenancyStatus status) async {
    await _db.from('tenancies').update({'status': status.name}).eq('id', id);
  }

  /// Flip a property's market status (e.g. relist: unlisted → available).
  /// Tenancy end parks listings at 'unlisted' (migration 021); relisting
  /// is an explicit landlord action, never a trigger side effect.
  Future<void> updatePropertyStatus(String propertyId, PropertyStatus status) async {
    await _db.from('properties').update({'status': status.name}).eq('id', propertyId);
  }

  // ═══════════════════════════════════════════════════════════════
  //  MOVE CHECKLISTS & RENT SCHEDULES (migration 020)
  //
  //  Rows for both are seeded by the setup_new_tenancy() trigger when
  //  a tenancy is created. Clients only toggle checklist items and
  //  mark rent paid; the rent_schedule_guard trigger enforces
  //  pending → paid (terminal) and stamps paid_at.
  // ═══════════════════════════════════════════════════════════════

  Stream<List<MoveChecklistModel>> getMoveChecklistsForUser(String userId) {
    return _db
        .from('move_checklists')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.map(_checklistFromJson).toList());
  }

  Future<void> updateMoveChecklist(MoveChecklistModel checklist) async {
    await _db.from('move_checklists').update({
      'items': checklist.items.map((i) => i.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', checklist.id);
  }

  Stream<List<RentScheduleModel>> getRentSchedulesForTenant(String tenantId) {
    return _db
        .from('rent_schedules')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .map((rows) => rows.map(_rentScheduleFromJson).toList());
  }

  Stream<List<RentScheduleModel>> getRentSchedulesForLandlord(String landlordId) {
    return _db
        .from('rent_schedules')
        .stream(primaryKey: ['id'])
        .eq('landlord_id', landlordId)
        .map((rows) => rows.map(_rentScheduleFromJson).toList());
  }

  Future<void> markRentPaid(String scheduleId) async {
    await _db.from('rent_schedules').update({'status': 'paid'}).eq('id', scheduleId);
  }

  // ═══════════════════════════════════════════════════════════════
  //  MAINTENANCE REQUESTS (migration 025)
  //
  //  Tenants file requests (RLS: own rows, always 'open'); landlords
  //  move them open → inProgress → resolved via the guard trigger,
  //  which stamps resolved_at and freezes the request details.
  // ═══════════════════════════════════════════════════════════════

  Stream<List<MaintenanceRequestModel>> getMaintenanceForTenant(String tenantId) {
    return _db
        .from('maintenance_requests')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_maintenanceFromJson).toList());
  }

  Stream<List<MaintenanceRequestModel>> getMaintenanceForLandlord(String landlordId) {
    return _db
        .from('maintenance_requests')
        .stream(primaryKey: ['id'])
        .eq('landlord_id', landlordId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(_maintenanceFromJson).toList());
  }

  Future<void> addMaintenanceRequest(MaintenanceRequestModel request) async {
    await _db.from('maintenance_requests').insert({
      'tenant_id': request.tenantId,
      'tenant_name': request.tenantName,
      'landlord_id': request.landlordId,
      'property_id': request.propertyId,
      'property_title': request.propertyTitle,
      'category': request.category.name,
      'description': request.description,
      'status': 'open',
      'photos': request.photos,
    });
  }

  Future<void> updateMaintenanceStatus(String id, MaintenanceStatus status, {String? resolutionNotes}) async {
    await _db.from('maintenance_requests').update({
      'status': status.name,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
    }).eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════
  //  STUBS — Phase 3 & 4 (Reviews, Reports, etc.)
  // ═══════════════════════════════════════════════════════════════

  Future<void> addReview(dynamic review) async {}
  Future<void> addNeighbourhoodReport(dynamic report) async {}
  Stream<List<dynamic>> getReviews({int limit = 20}) => const Stream.empty();
  Stream<List<dynamic>> getMoveListingsByUser(String userId) => const Stream.empty();
  Stream<List<dynamic>> getRewardsForUser(String userId) => const Stream.empty();
  Stream<List<dynamic>> getNeighbourhoodReports({int limit = 200}) => const Stream.empty();

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
      isVerifiedAgent: json['is_verified_agent'] ?? false,
      isVerifiedProperty: json['is_verified_property'] ?? false,
      isVerifiedListingCreator: json['is_verified_listing_creator'] ?? false,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
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

  PropertyModel _propertyFromJson(Map<String, dynamic> json) =>
      PropertyModel.fromJson(json);

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
      'has_electricity': p.hasElectricity,
      'has_internet': p.hasInternet,
      'has_gym': p.hasGym,
      'has_swimming_pool': p.hasSwimmingPool,
      'has_balcony': p.hasBalcony,
      'has_garden': p.hasGarden,
      'has_backup_generator': p.hasBackupGenerator,
      'has_cctv': p.hasCctv,
      'has_elevator': p.hasElevator,
      'pet_friendly': p.petFriendly,
      'has_air_conditioning': p.hasAirConditioning,
      'has_fitted_kitchen': p.hasFittedKitchen,
      'images': p.images,
      'status': p.status.name,
      'listing_type': p.listingType.name,
      'source_type': p.sourceType.name,
      'landlord_id': p.landlordId,
      'landlord_name': p.landlordName,
      'landlord_phone': p.landlordPhone,
      'is_landlord_verified': p.isLandlordVerified,
      'listing_creator_id': p.listingCreatorId,
      'listing_creator_role': p.listingCreatorRole,
      'registry_id': p.registryId,
      'agency_fee_eligible': p.agencyFeeEligible,
      'tenancy_confirmed': p.tenancyConfirmed,
      'street': p.street,
      'district': p.district,
      'ward': p.ward,
      'listing_status': p.listingStatus.name,
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
      landlordId: json['landlord_id'] ?? '',
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
      'landlord_id': i.landlordId,
      'message': i.message,
      'created_at': i.createdAt.toIso8601String(),
      'is_read': i.isRead,
    };
  }

  // ─── Tenancy Application ───────────────────────────────────────

  TenancyApplicationModel _applicationFromJson(Map<String, dynamic> json) {
    return TenancyApplicationModel(
      id: json['id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      tenantName: json['tenant_name'] ?? '',
      tenantPhone: json['tenant_phone'] ?? '',
      landlordId: json['landlord_id'] ?? '',
      landlordName: json['landlord_name'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.tryParse(json['resolved_at'])
          : null,
      notes: json['notes'],
    );
  }

  // ─── Tenancy ───────────────────────────────────────────────────

  TenancyModel _tenancyFromJson(Map<String, dynamic> json) {
    return TenancyModel(
      id: json['id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      tenantName: json['tenant_name'] ?? '',
      landlordId: json['landlord_id'] ?? '',
      landlordName: json['landlord_name'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      propertyLocation: json['property_location'] ?? '',
      moveInDate: DateTime.tryParse(json['move_in_date'] ?? '') ?? DateTime.now(),
      expectedMoveOutDate:
          DateTime.tryParse(json['expected_move_out_date'] ?? '') ?? DateTime.now(),
      rentAmount: (json['rent_amount'] as num?)?.toDouble() ?? 0,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble() ?? 0,
      status: TenancyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TenancyStatus.upcoming,
      ),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'])
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'])
          : null,
    );
  }

  // ─── Move Checklist ────────────────────────────────────────────

  MoveChecklistModel _checklistFromJson(Map<String, dynamic> json) {
    return MoveChecklistModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      moveId: json['move_id'],
      tenancyId: json['tenancy_id'],
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // ─── Rent Schedule ─────────────────────────────────────────────

  RentScheduleModel _rentScheduleFromJson(Map<String, dynamic> json) {
    return RentScheduleModel(
      id: json['id'] ?? '',
      tenancyId: json['tenancy_id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      dueDate: DateTime.tryParse(json['due_date'] ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at']) : null,
    );
  }

  // ─── Maintenance Request ───────────────────────────────────────

  MaintenanceRequestModel _maintenanceFromJson(Map<String, dynamic> json) {
    return MaintenanceRequestModel(
      id: json['id'] ?? '',
      tenantId: json['tenant_id'] ?? '',
      tenantName: json['tenant_name'] ?? '',
      landlordId: json['landlord_id'] ?? '',
      propertyId: json['property_id'] ?? '',
      propertyTitle: json['property_title'] ?? '',
      category: MaintenanceCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => MaintenanceCategory.general,
      ),
      description: json['description'] ?? '',
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MaintenanceStatus.open,
      ),
      photos: (json['photos'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at']) : null,
      resolutionNotes: json['resolution_notes'],
    );
  }

  // ─── Notification ────────────────────────────────────────────

  NotificationModel _notificationFromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => NotificationType.system,
      ),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      targetId: json['target_id'],
      targetCollection: json['target_collection'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
