import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/appointment_model.dart';
import 'package:dalali/models/inquiry_model.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/models/review_model.dart';
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/user_preferences_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/move_checklist_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/models/agreement_model.dart';
import 'package:dalali/models/handover_report_model.dart';
import 'package:dalali/utils/helpers.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─── Offline Persistence ────────────────────────────────────

  Future<void> enableOfflinePersistence() async {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // ─── Properties ─────────────────────────────────────────────

  CollectionReference get _properties => _db.collection('properties');
  CollectionReference get _users => _db.collection('users');

  Stream<List<PropertyModel>> getProperties({int limit = 20}) {
    return _properties
        .where('status', isEqualTo: 'available')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _propertyFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<List<PropertyModel>> getPropertiesPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    var query = _properties
        .where('status', isEqualTo: 'available')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => _propertyFromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Stream<List<PropertyModel>> getFeaturedProperties({int limit = 10}) {
    return _properties
        .where('listingType', isEqualTo: 'featured')
        .where('status', isEqualTo: 'available')
        .where('isApproved', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _propertyFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<PropertyModel>> getPropertiesByLandlord(String landlordId, {int limit = 50}) {
    return _properties
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _propertyFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<PropertyModel?> getPropertyById(String id) async {
    final doc = await _properties.doc(id).get();
    if (!doc.exists) return null;
    return _propertyFromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<UserModel?> getUserById(String id) async {
    final doc = await _users.doc(id).get();
    if (!doc.exists) return null;
    return _userFromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> addProperty(PropertyModel property) async {
    await _properties.add(_propertyToJson(property));
  }

  Future<void> updateProperty(PropertyModel property) async {
    await _properties.doc(property.id).update(_propertyToJson(property));
  }

  Future<void> deleteProperty(String id) async {
    await _properties.doc(id).delete();
  }

  Future<void> incrementViewCount(String propertyId) async {
    await _properties.doc(propertyId).update({
      'viewCount': FieldValue.increment(1),
    });
  }

  Future<void> incrementInquiryCount(String propertyId) async {
    await _properties.doc(propertyId).update({
      'inquiryCount': FieldValue.increment(1),
    });
  }

  // ─── Favorites ──────────────────────────────────────────────

  CollectionReference get _favorites => _db.collection('favorites');

  Stream<List<String>> getFavoritePropertyIds(String userId) {
    return _favorites
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => (doc.data() as Map<String, dynamic>)['propertyId'] as String)
            .toList());
  }

  Future<void> addFavorite(String userId, String propertyId) async {
    await _favorites.add({
      'userId': userId,
      'propertyId': propertyId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeFavorite(String userId, String propertyId) async {
    final snapshot = await _favorites
        .where('userId', isEqualTo: userId)
        .where('propertyId', isEqualTo: propertyId)
        .get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
  }

  // ─── Appointments ───────────────────────────────────────────

  CollectionReference get _appointments => _db.collection('appointments');

  Stream<List<AppointmentModel>> getAppointments(String userId, {bool isLandlord = false}) {
    final field = isLandlord ? 'landlordId' : 'seekerId';
    return _appointments
        .where(field, isEqualTo: userId)
        .orderBy('scheduledDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _appointmentFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<List<AppointmentModel>> getAppointmentsPaginated(
    String userId, {
    bool isLandlord = false,
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    final field = isLandlord ? 'landlordId' : 'seekerId';
    var query = _appointments
        .where(field, isEqualTo: userId)
        .orderBy('scheduledDate', descending: false)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => _appointmentFromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> addAppointment(AppointmentModel appointment) async {
    await _appointments.add(_appointmentToJson(appointment));
  }

  Future<void> updateAppointmentStatus(String id, AppointmentStatus status) async {
    await _appointments.doc(id).update({'status': status.name});
  }

  // ─── Inquiries ──────────────────────────────────────────────

  CollectionReference get _inquiries => _db.collection('inquiries');

  Stream<List<InquiryModel>> getInquiriesForProperty(String propertyId, {int limit = 20}) {
    return _inquiries
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _inquiryFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<InquiryModel>> getInquiriesForLandlord(String landlordId) async* {
    final props = await _properties.where('landlordId', isEqualTo: landlordId).get();
    final propertyIds = props.docs.map((d) => d.id).toList();
    if (propertyIds.isEmpty) {
      yield [];
      return;
    }
    yield* _inquiries
        .where('propertyId', whereIn: propertyIds.take(10).toList())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _inquiryFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addInquiry(InquiryModel inquiry) async {
    await _inquiries.add(_inquiryToJson(inquiry));
  }

  Future<void> markInquiryRead(String id) async {
    await _inquiries.doc(id).update({'isRead': true});
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: MOVE LISTINGS
  // ═══════════════════════════════════════════════════════════

  CollectionReference get _moveListings => _db.collection('move_listings');

  Stream<List<MoveListingModel>> getActiveMoveListings({int limit = 20}) {
    return _moveListings
        .where('status', whereIn: ['planning', 'active'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _moveListingFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<MoveListingModel>> getMoveListingsByUser(String userId) {
    return _moveListings
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _moveListingFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<MoveListingModel?> getMoveListingById(String id) async {
    final doc = await _moveListings.doc(id).get();
    if (!doc.exists) return null;
    return _moveListingFromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<DocumentReference> addMoveListing(MoveListingModel move) async {
    return await _moveListings.add(_moveListingToJson(move));
  }

  Future<void> updateMoveListing(MoveListingModel move) async {
    await _moveListings.doc(move.id).update(_moveListingToJson(move));
  }

  Future<void> updateMoveStatus(String id, MoveStatus status, {String? newPropertyId}) async {
    final data = <String, dynamic>{'status': status.name};
    if (newPropertyId != null) data['newPropertyId'] = newPropertyId;
    await _moveListings.doc(id).update(data);
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: REVIEWS
  // ═══════════════════════════════════════════════════════════

  CollectionReference get _reviews => _db.collection('reviews');

  Stream<List<ReviewModel>> getReviewsForProperty(String propertyId, {int limit = 20}) {
    return _reviews
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _reviewFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<List<ReviewModel>> getReviewsForPropertyOnce(String propertyId, {int limit = 50}) async {
    final snapshot = await _reviews
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _reviewFromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<void> addReview(ReviewModel review) async {
    await _reviews.add(_reviewToJson(review));
  }

  Future<Map<String, double>> getPropertyReviewAverages(String propertyId) async {
    final snapshot = await _reviews.where('propertyId', isEqualTo: propertyId).get();
    if (snapshot.docs.isEmpty) {
      return {
        'cleanliness': 0,
        'valueForMoney': 0,
        'safety': 0,
        'communication': 0,
        'fairness': 0,
        'maintenance': 0,
        'overall': 0,
      };
    }

    double cleanliness = 0;
    double value = 0;
    double safety = 0;
    double comm = 0;
    double fairness = 0;
    double maintenance = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      cleanliness += (data['cleanliness'] as num?)?.toDouble() ?? 0;
      value += (data['valueForMoney'] as num?)?.toDouble() ?? 0;
      safety += (data['safety'] as num?)?.toDouble() ?? 0;
      comm += (data['communication'] as num?)?.toDouble() ?? 0;
      fairness += (data['fairness'] as num?)?.toDouble() ?? 0;
      maintenance += (data['maintenance'] as num?)?.toDouble() ?? 0;
    }

    final count = snapshot.docs.length;
    return {
      'cleanliness': cleanliness / count,
      'valueForMoney': value / count,
      'safety': safety / count,
      'communication': comm / count,
      'fairness': fairness / count,
      'maintenance': maintenance / count,
      'overall': (cleanliness + value + safety + comm + fairness + maintenance) / (count * 6),
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: REWARDS
  // ═══════════════════════════════════════════════════════════

  CollectionReference get _rewards => _db.collection('rewards');
  CollectionReference get _neighbourhoodReports => _db.collection('neighbourhood_reports');

  Stream<List<RewardModel>> getRewardsForUser(String userId) {
    return _rewards
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _rewardFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addReward(RewardModel reward) async {
    await _rewards.add(_rewardToJson(reward));
  }

  Future<void> claimReward(String rewardId) async {
    await _rewards.doc(rewardId).update({
      'claimed': true,
      'claimedAt': FieldValue.serverTimestamp(),
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  HTN: NEIGHBOURHOOD REPORTS
  // ═══════════════════════════════════════════════════════════

  Stream<List<NeighbourhoodReportModel>> getNeighbourhoodReports({int limit = 100}) {
    return _neighbourhoodReports
        .where('resolved', isEqualTo: false)
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _neighbourhoodReportFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<List<NeighbourhoodReportModel>> getReportsNearLocation(
    double lat,
    double lng, {
    double radiusKm = 2.0,
    int limit = 100,
  }) async {
    // Note: Firestore doesn't support geoqueries natively.
    // For production, use geohash or a cloud function.
    // Here we fetch recent reports and filter client-side.
    final snapshot = await _neighbourhoodReports
        .where('resolved', isEqualTo: false)
        .orderBy('reportedAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => _neighbourhoodReportFromJson(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  Future<DocumentReference> addNeighbourhoodReport(NeighbourhoodReportModel report) async {
    return await _neighbourhoodReports.add(_neighbourhoodReportToJson(report));
  }

  Future<void> resolveNeighbourhoodReport(String id, String resolverId) async {
    await _neighbourhoodReports.doc(id).update({
      'resolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': resolverId,
    });
  }

  Future<int> getTotalPointsForUser(String userId) async {
    final snapshot = await _rewards.where('userId', isEqualTo: userId).where('claimed', isEqualTo: true).get();
    return snapshot.docs.fold<int>(
      0,
      (total, doc) => total + ((doc.data() as Map<String, dynamic>)['points'] as int? ?? 0),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  Preferences
  // ═══════════════════════════════════════════════════════════

  Future<void> updateUserPreferences(String userId, UserPreferencesModel prefs) async {
    await _users.doc(userId).update({
      'preferences': prefs.toJson(),
    });
  }

  Stream<List<ReviewModel>> getReviews({int limit = 50}) {
    return _reviews
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _reviewFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  UserModel _userFromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      id: uid,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.seeker,
      ),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verificationStatus'],
        orElse: () => VerificationStatus.unverified,
      ),
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      profileImage: json['profileImage'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      nationalId: json['nationalId'],
      agentLicense: json['agentLicense'],
      subscriptionTier: json['subscriptionTier'] ?? 0,
      preferences: json['preferences'] != null
          ? UserPreferencesModel.fromJson(json['preferences'] as Map<String, dynamic>)
          : const UserPreferencesModel(),
    );
  }

  Future<UserPreferencesModel> getUserPreferences(String userId) async {
    final doc = await _users.doc(userId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return UserPreferencesModel.fromJson(
      data?['preferences'] as Map<String, dynamic>?,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Property
  // ═══════════════════════════════════════════════════════════

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
      'rentAmount': p.rentAmount,
      'paymentOptions': p.paymentOptions.map((t) => t.name).toList(),
      'minimumAcceptedTerm': p.minimumAcceptedTerm?.name,
      'depositRequired': p.depositRequired,
      'depositAmount': p.depositAmount,
    };
  }

  PropertyModel _propertyFromJson(Map<String, dynamic> json, String id) {
    return PropertyModel(
      id: id,
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      rentPrice: (json['rentPrice'] as num?)?.toDouble() ?? 0,
      bedrooms: json['bedrooms'] ?? 0,
      bathrooms: json['bathrooms'] ?? 0,
      propertyType: PropertyType.values.firstWhere(
        (e) => e.name == json['propertyType'],
        orElse: () => PropertyType.apartment,
      ),
      isFurnished: json['isFurnished'] ?? false,
      hasWater: json['hasWater'] ?? false,
      hasParking: json['hasParking'] ?? false,
      hasSecurity: json['hasSecurity'] ?? false,
      sharedCompound: json['sharedCompound'] ?? false,
      hasBorehole: json['hasBorehole'] ?? false,
      images: List<String>.from(json['images'] ?? []),
      videoUrl: json['videoUrl'],
      status: PropertyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PropertyStatus.available,
      ),
      listingType: ListingType.values.firstWhere(
        (e) => e.name == json['listingType'],
        orElse: () => ListingType.basic,
      ),
      sourceType: ListingSource.values.firstWhere(
        (e) => e.name == json['sourceType'],
        orElse: () => ListingSource.landlordListing,
      ),
      landlordId: json['landlordId'] ?? '',
      landlordName: json['landlordName'] ?? '',
      landlordPhone: json['landlordPhone'] ?? '',
      isLandlordVerified: json['isLandlordVerified'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
      viewCount: json['viewCount'] ?? 0,
      inquiryCount: json['inquiryCount'] ?? 0,
      isApproved: json['isApproved'] ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] ?? 0,
      isBoosted: json['isBoosted'] ?? false,
      boostExpiresAt: (json['boostExpiresAt'] as Timestamp?)?.toDate(),
      tags: List<String>.from(json['tags'] ?? []),
      utilities: json['utilities'] != null
          ? PropertyUtilities.fromJson(json['utilities'] as Map<String, dynamic>)
          : const PropertyUtilities(),
      rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? (json['rentPrice'] as num?)?.toDouble() ?? 0,
      paymentOptions: Helpers.paymentTermsFromJson(json['paymentOptions'] as List<dynamic>?),
      minimumAcceptedTerm: Helpers.paymentTermFromString(json['minimumAcceptedTerm'] as String?),
      depositRequired: json['depositRequired'] ?? false,
      depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0,
    );
  }

  // ─── JSON Helpers: Appointment ──────────────────────────────

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

  AppointmentModel _appointmentFromJson(Map<String, dynamic> json, String id) {
    return AppointmentModel(
      id: id,
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      seekerId: json['seekerId'] ?? '',
      seekerName: json['seekerName'] ?? '',
      seekerPhone: json['seekerPhone'] ?? '',
      landlordId: json['landlordId'] ?? '',
      scheduledDate: (json['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      notes: json['notes'] ?? '',
      status: AppointmentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => AppointmentStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ─── JSON Helpers: Inquiry ──────────────────────────────────

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

  InquiryModel _inquiryFromJson(Map<String, dynamic> json, String id) {
    return InquiryModel(
      id: id,
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      seekerId: json['seekerId'] ?? '',
      seekerName: json['seekerName'] ?? '',
      seekerPhone: json['seekerPhone'] ?? '',
      message: json['message'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Move Listing
  // ═══════════════════════════════════════════════════════════

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

  MoveListingModel _moveListingFromJson(Map<String, dynamic> json, String id) {
    return MoveListingModel(
      id: id,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      currentPropertyId: json['currentPropertyId'],
      currentPropertyTitle: json['currentPropertyTitle'] ?? '',
      currentLocation: json['currentLocation'] ?? '',
      moveDate: (json['moveDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MoveStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MoveStatus.planning,
      ),
      newPropertyId: json['newPropertyId'],
      budgetMin: (json['budgetMin'] as num?)?.toDouble(),
      budgetMax: (json['budgetMax'] as num?)?.toDouble(),
      preferredLocation: json['preferredLocation'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Review
  // ═══════════════════════════════════════════════════════════

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

  ReviewModel _reviewFromJson(Map<String, dynamic> json, String id) {
    return ReviewModel(
      id: id,
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      reviewerId: json['reviewerId'] ?? '',
      reviewerName: json['reviewerName'] ?? '',
      stayVerified: json['stayVerified'] ?? false,
      cleanliness: (json['cleanliness'] as num?)?.toDouble() ?? 0,
      valueForMoney: (json['valueForMoney'] as num?)?.toDouble() ?? 0,
      safety: (json['safety'] as num?)?.toDouble() ?? 0,
      communication: (json['communication'] as num?)?.toDouble() ?? 0,
      fairness: (json['fairness'] as num?)?.toDouble() ?? 0,
      maintenance: (json['maintenance'] as num?)?.toDouble() ?? 0,
      comment: json['comment'],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Reward
  // ═══════════════════════════════════════════════════════════

  Map<String, dynamic> _rewardToJson(RewardModel r) {
    return {
      'userId': r.userId,
      'type': r.type.name,
      'points': r.points,
      'description': r.description,
      'createdAt': Timestamp.fromDate(r.createdAt),
      'claimed': r.claimed,
      'claimedAt': r.claimedAt != null ? Timestamp.fromDate(r.claimedAt!) : null,
    };
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Neighbourhood Report
  // ═══════════════════════════════════════════════════════════

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

  NeighbourhoodReportModel _neighbourhoodReportFromJson(Map<String, dynamic> json, String id) {
    return NeighbourhoodReportModel(
      id: id,
      reporterId: json['reporterId'] ?? '',
      reporterName: json['reporterName'] ?? '',
      reporterVerified: json['reporterVerified'] ?? false,
      reporterTrustScore: json['reporterTrustScore'] ?? 50,
      type: IncidentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => IncidentType.other,
      ),
      severity: IncidentSeverity.values.firstWhere(
        (e) => e.name == json['severity'],
        orElse: () => IncidentSeverity.medium,
      ),
      location: json['location'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      description: json['description'],
      reportedAt: (json['reportedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved: json['resolved'] ?? false,
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: json['resolvedBy'],
    );
  }

  RewardModel _rewardFromJson(Map<String, dynamic> json, String id) {
    return RewardModel(
      id: id,
      userId: json['userId'] ?? '',
      type: RewardType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RewardType.moveComplete,
      ),
      points: json['points'] ?? 0,
      description: json['description'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      claimed: json['claimed'] ?? false,
      claimedAt: (json['claimedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  TENANCY LIFECYCLE
  // ═══════════════════════════════════════════════════════════

  CollectionReference get _tenancyApplications => _db.collection('tenancy_applications');
  CollectionReference get _tenancies => _db.collection('tenancies');
  CollectionReference get _moveChecklists => _db.collection('move_checklists');
  CollectionReference get _maintenanceRequests => _db.collection('maintenance_requests');
  CollectionReference get _rentSchedules => _db.collection('rent_schedules');
  CollectionReference get _agreements => _db.collection('agreements');
  CollectionReference get _handoverReports => _db.collection('handover_reports');

  // ─── Tenancy Applications ───────────────────────────────────

  Stream<List<TenancyApplicationModel>> getApplicationsForTenant(String tenantId) {
    return _tenancyApplications
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _tenancyApplicationFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<TenancyApplicationModel>> getApplicationsForLandlord(String landlordId) {
    return _tenancyApplications
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _tenancyApplicationFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addTenancyApplication(TenancyApplicationModel app) async {
    await _tenancyApplications.add(_tenancyApplicationToJson(app));
  }

  Future<void> updateApplicationStatus(String id, ApplicationStatus status) async {
    await _tenancyApplications.doc(id).update({
      'status': status.name,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Tenancies ──────────────────────────────────────────────

  Stream<List<TenancyModel>> getTenanciesForTenant(String tenantId) {
    return _tenancies
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _tenancyFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<TenancyModel>> getTenanciesForLandlord(String landlordId) {
    return _tenancies
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _tenancyFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addTenancy(TenancyModel tenancy) async {
    await _tenancies.add(_tenancyToJson(tenancy));
  }

  Future<void> updateTenancyStatus(String id, TenancyStatus status) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == TenancyStatus.active) {
      updates['activatedAt'] = FieldValue.serverTimestamp();
    } else if (status == TenancyStatus.completed || status == TenancyStatus.terminated) {
      updates['completedAt'] = FieldValue.serverTimestamp();
    }
    await _tenancies.doc(id).update(updates);
  }

  // ─── Maintenance Requests ───────────────────────────────────

  Stream<List<MaintenanceRequestModel>> getMaintenanceForTenant(String tenantId) {
    return _maintenanceRequests
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _maintenanceRequestFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<MaintenanceRequestModel>> getMaintenanceForLandlord(String landlordId) {
    return _maintenanceRequests
        .where('landlordId', isEqualTo: landlordId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _maintenanceRequestFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addMaintenanceRequest(MaintenanceRequestModel req) async {
    await _maintenanceRequests.add(_maintenanceRequestToJson(req));
  }

  Future<void> updateMaintenanceStatus(String id, MaintenanceStatus status, {String? resolutionNotes}) async {
    final updates = <String, dynamic>{'status': status.name};
    if (status == MaintenanceStatus.resolved) {
      updates['resolvedAt'] = FieldValue.serverTimestamp();
      if (resolutionNotes != null) updates['resolutionNotes'] = resolutionNotes;
    }
    await _maintenanceRequests.doc(id).update(updates);
  }

  // ─── Rent Schedules ─────────────────────────────────────────

  Stream<List<RentScheduleModel>> getRentSchedulesForTenant(String tenantId) {
    return _rentSchedules
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _rentScheduleFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Stream<List<RentScheduleModel>> getRentSchedulesForTenancy(String tenancyId) {
    return _rentSchedules
        .where('tenancyId', isEqualTo: tenancyId)
        .orderBy('dueDate', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _rentScheduleFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addRentSchedule(RentScheduleModel schedule) async {
    await _rentSchedules.add(_rentScheduleToJson(schedule));
  }

  Future<void> markRentPaid(String id) async {
    await _rentSchedules.doc(id).update({
      'status': PaymentStatus.paid.name,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── Move Checklists ────────────────────────────────────────

  Future<MoveChecklistModel?> getChecklist(String id) async {
    final doc = await _moveChecklists.doc(id).get();
    if (!doc.exists) return null;
    return _moveChecklistFromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> addChecklist(MoveChecklistModel checklist) async {
    await _moveChecklists.add(_moveChecklistToJson(checklist));
  }

  Future<void> updateChecklist(MoveChecklistModel checklist) async {
    await _moveChecklists.doc(checklist.id).update(_moveChecklistToJson(checklist));
  }

  // ─── Agreements ─────────────────────────────────────────────

  Stream<List<AgreementModel>> getAgreementsForTenancy(String tenancyId) {
    return _agreements
        .where('tenancyId', isEqualTo: tenancyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => _agreementFromJson(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  Future<void> addAgreement(AgreementModel agreement) async {
    await _agreements.add(_agreementToJson(agreement));
  }

  // ─── Handover Reports ───────────────────────────────────────

  Future<HandoverReportModel?> getHandoverReport(String tenancyId) async {
    final snapshot = await _handoverReports
        .where('tenancyId', isEqualTo: tenancyId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return _handoverReportFromJson(
      snapshot.docs.first.data() as Map<String, dynamic>,
      snapshot.docs.first.id,
    );
  }

  Future<void> addHandoverReport(HandoverReportModel report) async {
    await _handoverReports.add(_handoverReportToJson(report));
  }

  // ═══════════════════════════════════════════════════════════
  //  JSON Helpers: Tenancy Lifecycle
  // ═══════════════════════════════════════════════════════════

  Map<String, dynamic> _tenancyApplicationToJson(TenancyApplicationModel a) {
    return {
      'propertyId': a.propertyId,
      'propertyTitle': a.propertyTitle,
      'tenantId': a.tenantId,
      'tenantName': a.tenantName,
      'tenantPhone': a.tenantPhone,
      'landlordId': a.landlordId,
      'landlordName': a.landlordName,
      'status': a.status.name,
      'createdAt': Timestamp.fromDate(a.createdAt),
      'resolvedAt': a.resolvedAt != null ? Timestamp.fromDate(a.resolvedAt!) : null,
      'notes': a.notes,
    };
  }

  TenancyApplicationModel _tenancyApplicationFromJson(Map<String, dynamic> json, String id) {
    return TenancyApplicationModel(
      id: id,
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      tenantId: json['tenantId'] ?? '',
      tenantName: json['tenantName'] ?? '',
      tenantPhone: json['tenantPhone'] ?? '',
      landlordId: json['landlordId'] ?? '',
      landlordName: json['landlordName'] ?? '',
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
      notes: json['notes'],
    );
  }

  Map<String, dynamic> _tenancyToJson(TenancyModel t) {
    return {
      'tenantId': t.tenantId,
      'tenantName': t.tenantName,
      'landlordId': t.landlordId,
      'landlordName': t.landlordName,
      'propertyId': t.propertyId,
      'propertyTitle': t.propertyTitle,
      'propertyLocation': t.propertyLocation,
      'moveInDate': Timestamp.fromDate(t.moveInDate),
      'expectedMoveOutDate': Timestamp.fromDate(t.expectedMoveOutDate),
      'rentAmount': t.rentAmount,
      'depositAmount': t.depositAmount,
      'status': t.status.name,
      'createdAt': Timestamp.fromDate(t.createdAt),
      'activatedAt': t.activatedAt != null ? Timestamp.fromDate(t.activatedAt!) : null,
      'completedAt': t.completedAt != null ? Timestamp.fromDate(t.completedAt!) : null,
    };
  }

  TenancyModel _tenancyFromJson(Map<String, dynamic> json, String id) {
    return TenancyModel(
      id: id,
      tenantId: json['tenantId'] ?? '',
      tenantName: json['tenantName'] ?? '',
      landlordId: json['landlordId'] ?? '',
      landlordName: json['landlordName'] ?? '',
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      propertyLocation: json['propertyLocation'] ?? '',
      moveInDate: (json['moveInDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expectedMoveOutDate: (json['expectedMoveOutDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? 0,
      depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0,
      status: TenancyStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => TenancyStatus.upcoming,
      ),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      activatedAt: (json['activatedAt'] as Timestamp?)?.toDate(),
      completedAt: (json['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _maintenanceRequestToJson(MaintenanceRequestModel m) {
    return {
      'tenantId': m.tenantId,
      'tenantName': m.tenantName,
      'landlordId': m.landlordId,
      'propertyId': m.propertyId,
      'propertyTitle': m.propertyTitle,
      'category': m.category.name,
      'description': m.description,
      'status': m.status.name,
      'photos': m.photos,
      'createdAt': Timestamp.fromDate(m.createdAt),
      'resolvedAt': m.resolvedAt != null ? Timestamp.fromDate(m.resolvedAt!) : null,
      'resolutionNotes': m.resolutionNotes,
    };
  }

  MaintenanceRequestModel _maintenanceRequestFromJson(Map<String, dynamic> json, String id) {
    return MaintenanceRequestModel(
      id: id,
      tenantId: json['tenantId'] ?? '',
      tenantName: json['tenantName'] ?? '',
      landlordId: json['landlordId'] ?? '',
      propertyId: json['propertyId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      category: MaintenanceCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => MaintenanceCategory.general,
      ),
      description: json['description'] ?? '',
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MaintenanceStatus.open,
      ),
      photos: List<String>.from(json['photos'] ?? []),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      resolvedAt: (json['resolvedAt'] as Timestamp?)?.toDate(),
      resolutionNotes: json['resolutionNotes'],
    );
  }

  Map<String, dynamic> _rentScheduleToJson(RentScheduleModel r) {
    return {
      'tenancyId': r.tenancyId,
      'tenantId': r.tenantId,
      'propertyTitle': r.propertyTitle,
      'dueDate': Timestamp.fromDate(r.dueDate),
      'amount': r.amount,
      'status': r.status.name,
      'paidAt': r.paidAt != null ? Timestamp.fromDate(r.paidAt!) : null,
    };
  }

  RentScheduleModel _rentScheduleFromJson(Map<String, dynamic> json, String id) {
    return RentScheduleModel(
      id: id,
      tenancyId: json['tenancyId'] ?? '',
      tenantId: json['tenantId'] ?? '',
      propertyTitle: json['propertyTitle'] ?? '',
      dueDate: (json['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      paidAt: (json['paidAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> _moveChecklistToJson(MoveChecklistModel c) {
    return {
      'userId': c.userId,
      'moveId': c.moveId,
      'tenancyId': c.tenancyId,
      'items': c.items.map((i) => i.toJson()).toList(),
      'createdAt': Timestamp.fromDate(c.createdAt),
      'updatedAt': Timestamp.fromDate(c.updatedAt),
    };
  }

  MoveChecklistModel _moveChecklistFromJson(Map<String, dynamic> json, String id) {
    return MoveChecklistModel(
      id: id,
      userId: json['userId'] ?? '',
      moveId: json['moveId'],
      tenancyId: json['tenancyId'],
      items: (json['items'] as List<dynamic>?)
          ?.map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _agreementToJson(AgreementModel a) {
    return {
      'tenancyId': a.tenancyId,
      'documentUrl': a.documentUrl,
      'uploadedBy': a.uploadedBy,
      'uploadedByName': a.uploadedByName,
      'createdAt': Timestamp.fromDate(a.createdAt),
    };
  }

  AgreementModel _agreementFromJson(Map<String, dynamic> json, String id) {
    return AgreementModel(
      id: id,
      tenancyId: json['tenancyId'] ?? '',
      documentUrl: json['documentUrl'] ?? '',
      uploadedBy: json['uploadedBy'] ?? '',
      uploadedByName: json['uploadedByName'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> _handoverReportToJson(HandoverReportModel h) {
    return {
      'tenancyId': h.tenancyId,
      'propertyId': h.propertyId,
      'waterReading': h.waterReading,
      'electricityReading': h.electricityReading,
      'photos': h.photos,
      'videoUrl': h.videoUrl,
      'notes': h.notes,
      'createdBy': h.createdBy,
      'createdByName': h.createdByName,
      'createdAt': Timestamp.fromDate(h.createdAt),
    };
  }

  HandoverReportModel _handoverReportFromJson(Map<String, dynamic> json, String id) {
    return HandoverReportModel(
      id: id,
      tenancyId: json['tenancyId'] ?? '',
      propertyId: json['propertyId'] ?? '',
      waterReading: json['waterReading'],
      electricityReading: json['electricityReading'],
      photos: List<String>.from(json['photos'] ?? []),
      videoUrl: json['videoUrl'],
      notes: json['notes'] ?? '',
      createdBy: json['createdBy'] ?? '',
      createdByName: json['createdByName'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

}
