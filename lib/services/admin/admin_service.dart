import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/user_model.dart';

/// Centralized admin service for dashboard operations.
/// All write operations log to adminLogs collection automatically.
class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collections
  CollectionReference get _users => _db.collection('users');
  CollectionReference get _properties => _db.collection('properties');
  CollectionReference get _wallets => _db.collection('wallets');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _withdrawals => _db.collection('withdrawals');
  CollectionReference get _adminLogs => _db.collection('adminLogs');
  CollectionReference get _fraudReports => _db.collection('fraudReports');
  CollectionReference get _disputes => _db.collection('disputes');
  DocumentReference get _systemSettings => _db.collection('systemSettings').doc('default');

  // ─── ADMIN LOGS ─────────────────────────────────────────────────

  Future<void> _logAction({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String action,
    required String targetCollection,
    String? targetId,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) async {
    await _adminLogs.add({
      'adminId': adminId,
      'adminName': adminName,
      'adminRole': adminRole.name,
      'action': action,
      'targetCollection': targetCollection,
      'targetId': targetId,
      'before': before,
      'after': after,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── USERS ──────────────────────────────────────────────────────

  Stream<List<UserModel>> getAllUsers({int limit = 100}) {
    return _users
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return _userFromJson(data, d.id);
        }).toList());
  }

  Stream<int> getTotalUsersCount() {
    return _users.snapshots().map((s) => s.size);
  }

  Stream<int> getActiveUsersToday() {
    final startOfDay = DateTime.now().subtract(const Duration(days: 1));
    return _users
        .where('lastActive', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> suspendUser(String userId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _users.doc(userId).get()).data() as Map<String, dynamic>?;
    await _users.doc(userId).update({'suspended': true, 'suspendedAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'SUSPEND_USER',
      targetCollection: 'users',
      targetId: userId,
      before: before,
      after: {'suspended': true},
    );
  }

  Future<void> verifyUser(String userId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _users.doc(userId).get()).data() as Map<String, dynamic>?;
    await _users.doc(userId).update({
      'verificationStatus': 'verified',
      'isVerifiedLandlord': true,
      'verifiedAt': FieldValue.serverTimestamp(),
    });
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'VERIFY_USER',
      targetCollection: 'users',
      targetId: userId,
      before: before,
      after: {'verificationStatus': 'verified'},
    );
  }

  // ─── LISTINGS ───────────────────────────────────────────────────

  Stream<List<PropertyModel>> getAllListings({int limit = 100}) {
    return _properties
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
          // We need FirestoreService's _propertyFromJson but can't import it cleanly.
          // We'll do a lightweight read here for the admin dashboard.
          final data = d.data() as Map<String, dynamic>;
          return _propertyFromJson(data, d.id);
        }).toList());
  }

  Stream<int> getPendingListingsCount() {
    return _properties
        .where('isApproved', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  Stream<int> getActiveListingsCount() {
    return _properties
        .where('status', isEqualTo: 'available')
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> approveListing(String propertyId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _properties.doc(propertyId).get()).data() as Map<String, dynamic>?;
    await _properties.doc(propertyId).update({'isApproved': true, 'approvedAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'APPROVE_LISTING',
      targetCollection: 'properties',
      targetId: propertyId,
      before: before,
      after: {'isApproved': true},
    );
  }

  Future<void> rejectListing(String propertyId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _properties.doc(propertyId).get()).data() as Map<String, dynamic>?;
    await _properties.doc(propertyId).update({'isApproved': false, 'rejectedAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'REJECT_LISTING',
      targetCollection: 'properties',
      targetId: propertyId,
      before: before,
      after: {'isApproved': false},
    );
  }

  Future<void> removeListing(String propertyId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _properties.doc(propertyId).get()).data() as Map<String, dynamic>?;
    await _properties.doc(propertyId).update({'status': 'removed', 'removedAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'REMOVE_LISTING',
      targetCollection: 'properties',
      targetId: propertyId,
      before: before,
      after: {'status': 'removed'},
    );
  }

  // ─── WALLETS ────────────────────────────────────────────────────

  Stream<List<WalletModel>> getAllWallets({int limit = 100}) {
    return _wallets
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            WalletModel.fromJson(d.data() as Map<String, dynamic>)).toList());
  }

  Future<void> freezeWallet(String userId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _wallets.doc(userId).get()).data() as Map<String, dynamic>?;
    await _wallets.doc(userId).update({'frozen': true, 'frozenAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'FREEZE_WALLET',
      targetCollection: 'wallets',
      targetId: userId,
      before: before,
      after: {'frozen': true},
    );
  }

  Future<void> unfreezeWallet(String userId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _wallets.doc(userId).get()).data() as Map<String, dynamic>?;
    await _wallets.doc(userId).update({'frozen': false, 'unfrozenAt': FieldValue.serverTimestamp()});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'UNFREEZE_WALLET',
      targetCollection: 'wallets',
      targetId: userId,
      before: before,
      after: {'frozen': false},
    );
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────────

  Stream<List<TransactionModel>> getAllTransactions({int limit = 100}) {
    return _transactions
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            TransactionModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Stream<int> getCompletedTransactionsCount() {
    return _transactions
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((s) => s.size);
  }

  // ─── WITHDRAWALS ────────────────────────────────────────────────

  Stream<List<WithdrawalModel>> getAllWithdrawals({int limit = 100}) {
    return _withdrawals
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            WithdrawalModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Stream<int> getPendingWithdrawalsCount() {
    return _withdrawals
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> approveWithdrawal(String withdrawalId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _withdrawals.doc(withdrawalId).get()).data() as Map<String, dynamic>?;
    await _withdrawals.doc(withdrawalId).update({'status': 'processing', 'approvedAt': FieldValue.serverTimestamp(), 'approvedBy': adminId});
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'APPROVE_WITHDRAWAL',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
      before: before,
      after: {'status': 'processing'},
    );
  }

  Future<void> rejectWithdrawal(String withdrawalId, {required String reason, required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _withdrawals.doc(withdrawalId).get()).data() as Map<String, dynamic>?;
    await _withdrawals.doc(withdrawalId).update({
      'status': 'failed',
      'failureReason': reason,
      'rejectedAt': FieldValue.serverTimestamp(),
      'rejectedBy': adminId,
    });
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'REJECT_WITHDRAWAL',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
      before: before,
      after: {'status': 'failed', 'failureReason': reason},
    );
  }

  // ─── FRAUD REPORTS ──────────────────────────────────────────────

  Stream<List<FraudReportModel>> getAllFraudReports({int limit = 100}) {
    return _fraudReports
        .where('resolved', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            FraudReportModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Stream<int> getUnresolvedFraudCount() {
    return _fraudReports
        .where('resolved', isEqualTo: false)
        .snapshots()
        .map((s) => s.size);
  }

  Future<void> resolveFraudReport(String reportId, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    await _fraudReports.doc(reportId).update({
      'resolved': true,
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'RESOLVE_FRAUD',
      targetCollection: 'fraudReports',
      targetId: reportId,
    );
  }

  // ─── DISPUTES ───────────────────────────────────────────────────

  Stream<List<DisputeModel>> getAllDisputes({int limit = 100}) {
    return _disputes
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            DisputeModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  Future<void> resolveDispute(String disputeId, {required String resolution, required String adminId, required String adminName, required AdminRole adminRole}) async {
    await _disputes.doc(disputeId).update({
      'status': 'resolved',
      'resolution': resolution,
      'resolvedBy': adminId,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'RESOLVE_DISPUTE',
      targetCollection: 'disputes',
      targetId: disputeId,
      after: {'status': 'resolved', 'resolution': resolution},
    );
  }

  // ─── SYSTEM SETTINGS ────────────────────────────────────────────

  Future<void> updateSystemSettings(Map<String, dynamic> settings, {required String adminId, required String adminName, required AdminRole adminRole}) async {
    final before = (await _systemSettings.get()).data() as Map<String, dynamic>?;
    await _systemSettings.update(settings);
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'UPDATE_SETTINGS',
      targetCollection: 'systemSettings',
      before: before,
      after: settings,
    );
  }

  // ─── ADMIN LOGS ─────────────────────────────────────────────────

  Stream<List<AdminLogModel>> getAdminLogs({int limit = 100}) {
    return _adminLogs
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) =>
            AdminLogModel.fromJson(d.data() as Map<String, dynamic>, d.id)).toList());
  }

  // ─── Lightweight JSON helpers for admin reads ───────────────────

  UserModel _userFromJson(Map<String, dynamic> json, String id) {
    return UserModel(
      id: id,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere((e) => e.name == json['role'], orElse: () => UserRole.seeker),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verificationStatus'],
        orElse: () => VerificationStatus.unverified,
      ),
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nationalId: json['nationalId'],
      agentLicense: json['agentLicense'],
      subscriptionTier: json['subscriptionTier'] ?? 0,
    );
  }

  PropertyModel _propertyFromJson(Map<String, dynamic> json, String id) {
    // Lightweight version for admin listing - enough for table display
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
      images: List<String>.from(json['images'] ?? []),
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
      isApproved: json['isApproved'] ?? false,
    );
  }
}
