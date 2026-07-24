import 'dart:convert';

import 'package:dalali/config/supabase_config.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:http/http.dart' as http;

/// Centralized admin service for dashboard operations.
/// All write operations log to admin_logs table automatically.
class AdminService {
  final _db = SupabaseService.client;

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
    await _db.from('admin_logs').insert({
      'admin_id': adminId,
      'admin_name': adminName,
      'admin_role': adminRole.name,
      'action': action,
      'target_table': targetCollection,
      'target_id': targetId,
      'details': {'before': before, 'after': after},
    });
  }

  // ─── USERS ──────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllUsers({int limit = 100}) {
    return _db.from('users').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Future<Map<String, dynamic>?> getUserById(String userId) async {
    return await _db.from('users').select().eq('id', userId).maybeSingle();
  }

  Future<void> updateUserRole({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String userId,
    required String newRole,
  }) async {
    final before = await getUserById(userId);
    final result = await _db.from('users').update({'role': newRole}).eq('id', userId).select();
    if (result.isEmpty) {
      throw Exception(
        'Update user role failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'update_user_role',
      targetCollection: 'users',
      targetId: userId,
      before: before,
      after: {'role': newRole},
    );
  }

  Future<void> verifyLandlord({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String userId,
  }) async {
    // Verifying someone as a landlord grants the landlord role too —
    // otherwise the user shows a "Verified Landlord" badge while
    // staying a seeker (as happened with legacy rows).
    final result = await _db.from('users').update({
      'is_verified_landlord': true,
      'verification_status': 'verified',
      'role': 'landlord',
    }).eq('id', userId).select();
    if (result.isEmpty) {
      throw Exception(
        'Verify landlord failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'verify_landlord',
      targetCollection: 'users',
      targetId: userId,
    );
  }

  Future<void> banUser({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String userId,
  }) async {
    final result = await _db.from('users').update({'is_approved': false}).eq('id', userId).select();
    if (result.isEmpty) {
      throw Exception(
        'Ban user failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'ban_user',
      targetCollection: 'users',
      targetId: userId,
    );
  }

  // ─── PROPERTIES ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllProperties({int limit = 100}) async {
    final rows = await _db.from('properties').select().limit(limit);
    return rows;
  }

  Future<void> approveProperty({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String propertyId,
  }) async {
    final result = await _db.from('properties').update({'is_approved': true}).eq('id', propertyId).select();
    if (result.isEmpty) {
      throw Exception(
        'Approve failed: RLS blocked the update. '
        'Ensure the "Admins can update any property" policy exists and your user has is_admin=true.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'approve_property',
      targetCollection: 'properties',
      targetId: propertyId,
    );
  }

  Future<void> rejectProperty({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String propertyId,
    String? reason,
  }) async {
    final result = await _db.from('properties').update({'is_approved': false}).eq('id', propertyId).select();
    if (result.isEmpty) {
      throw Exception(
        'Reject failed: RLS blocked the update. '
        'Ensure the "Admins can update any property" policy exists and your user has is_admin=true.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'reject_property',
      targetCollection: 'properties',
      targetId: propertyId,
    );
  }

  Future<void> boostProperty({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String propertyId,
    required int durationDays,
  }) async {
    await _db.from('properties').update({
      'is_boosted': true,
      'boost_expires_at': DateTime.now().add(Duration(days: durationDays)).toIso8601String(),
    }).eq('id', propertyId);
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'boost_property',
      targetCollection: 'properties',
      targetId: propertyId,
    );
  }

  // ─── WALLETS ────────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllWallets({int limit = 100}) {
    return _db.from('wallets').stream(primaryKey: ['user_id']).limit(limit).map((rows) => rows);
  }

  Future<Map<String, dynamic>?> getWalletByUserId(String userId) async {
    return await _db.from('wallets').select().eq('user_id', userId).maybeSingle();
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllTransactions({int limit = 200}) {
    return _db.from('transactions').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Future<List<Map<String, dynamic>>> getTransactionsByStatus(String status, {int limit = 100}) async {
    final rows = await _db.from('transactions').select().eq('status', status).limit(limit);
    return rows;
  }

  // ─── WITHDRAWALS ────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllWithdrawals({int limit = 200}) {
    return _db.from('withdrawals').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Future<void> approveWithdrawal({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String withdrawalId,
  }) async {
    final result = await _db.from('withdrawals').update({'status': 'processing'}).eq('id', withdrawalId).select();
    if (result.isEmpty) {
      throw Exception(
        'Approve withdrawal failed: RLS blocked the update. '
        'Ensure the "Admins can update withdrawals" policy exists.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'approve_withdrawal',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
    );
  }

  Future<void> rejectWithdrawal({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String withdrawalId,
    String? reason,
  }) async {
    final result = await _db.from('withdrawals').update({
      'status': 'failed',
      'failure_reason': reason,
    }).eq('id', withdrawalId).select();
    if (result.isEmpty) {
      throw Exception(
        'Reject withdrawal failed: RLS blocked the update. '
        'Ensure the "Admins can update withdrawals" policy exists.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'reject_withdrawal',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
    );
  }

  /// Execute the payout by invoking the `process_withdrawal` Edge Function.
  /// Uses the current admin's access token for authorization.
  Future<void> executeWithdrawal({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String withdrawalId,
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final functionsHost = SupabaseConfig.url.replaceFirst('.supabase.co', '.functions.supabase.co');
    final url = Uri.parse('$functionsHost/process_withdrawal');
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'withdrawal_id': withdrawalId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Payout execution failed: ${resp.statusCode} ${resp.body}');
    }

    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'execute_withdrawal',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
    );
  }

  // ─── FRAUD / DISPUTES ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFraudReports({int limit = 100}) async {
    final rows = await _db.from('fraud_reports').select().limit(limit);
    return rows;
  }

  Future<void> resolveFraudReport({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String reportId,
  }) async {
    final result = await _db.from('fraud_reports').update({
      'status': 'resolved',
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', reportId).select();
    if (result.isEmpty) {
      throw Exception(
        'Resolve fraud report failed: no rows updated. '
        'Check if the report ID exists and you have admin permissions.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'resolve_fraud_report',
      targetCollection: 'fraud_reports',
      targetId: reportId,
    );
  }

  Future<List<Map<String, dynamic>>> getDisputes({int limit = 100}) async {
    final rows = await _db.from('disputes').select().limit(limit);
    return rows;
  }

  // ─── ANALYTICS ──────────────────────────────────────────────────

  Stream<int> getTotalUsersCount() {
    return _db.from('users').stream(primaryKey: ['id']).map((rows) => rows.length);
  }

  Stream<int> getActiveUsersToday() {
    return _db.from('users').stream(primaryKey: ['id']).map((rows) => rows.length);
  }

  Stream<int> getActiveListingsCount() {
    return _db.from('properties').stream(primaryKey: ['id']).map((rows) => rows.where((r) => r['status'] == 'available').length);
  }

  Stream<int> getPendingListingsCount() {
    return _db.from('properties').stream(primaryKey: ['id']).map((rows) => rows.where((r) => r['is_approved'] == false).length);
  }

  Stream<int> getCompletedTransactionsCount() {
    return _db.from('transactions').stream(primaryKey: ['id']).map((rows) => rows.where((r) => r['status'] == 'completed').length);
  }

  Stream<int> getPendingWithdrawalsCount() {
    return _db.from('withdrawals').stream(primaryKey: ['id']).map((rows) => rows.where((r) => r['status'] == 'pending').length);
  }

  Stream<int> getUnresolvedFraudCount() {
    return _db.from('fraud_reports').stream(primaryKey: ['id']).map((rows) => rows.where((r) => r['status'] == 'open').length);
  }

  Stream<List<Map<String, dynamic>>> getAllFraudReports({int limit = 100}) {
    return _db.from('fraud_reports').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Stream<List<Map<String, dynamic>>> getAllListings({int limit = 100}) {
    return _db.from('properties').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    // Simple count by fetching all IDs (for small datasets)
    final users = await _db.from('users').select('id');
    final properties = await _db.from('properties').select('id');
    final transactions = await _db.from('transactions').select('id');

    return {
      'totalUsers': users.length,
      'totalProperties': properties.length,
      'totalTransactions': transactions.length,
    };
  }

  // ─── DISPUTES ───────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getAllDisputes({int limit = 100}) {
    return _db
        .from('disputes')
        .stream(primaryKey: ['id'])
        .limit(limit)
        .map((rows) => rows);
  }

  Future<void> resolveDispute({
    required String disputeId,
    required String resolution,
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
  }) async {
    final result = await _db.from('disputes').update({
      'status': 'resolved',
      'resolution': resolution,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', disputeId).select();
    if (result.isEmpty) {
      throw Exception(
        'Resolve dispute failed: no rows updated. '
        'Check if the dispute ID exists and you have admin permissions.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'resolve_dispute',
      targetCollection: 'disputes',
      targetId: disputeId,
    );
  }

  // ─── SYSTEM SETTINGS ────────────────────────────────────────────

  Future<Map<String, dynamic>?> getSystemSettings() async {
    return await _db.from('system_settings').select().eq('id', 'default').maybeSingle();
  }

  Future<void> updateSystemSettings({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required Map<String, dynamic> settings,
  }) async {
    final result = await _db.from('system_settings').update(settings).eq('id', 'default').select();
    if (result.isEmpty) {
      throw Exception(
        'Update system settings failed: no rows updated. '
        'Check if the default settings row exists and you have admin permissions.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'update_system_settings',
      targetCollection: 'system_settings',
    );
  }

  // ─── INFLUENCERS ─────────────────────────────────────────────

  /// Influencer applications, newest first, optionally filtered by
  /// status ('pending' | 'approved' | 'rejected'). The table already
  /// carries full_name/phone/email, so no user join is needed.
  Stream<List<Map<String, dynamic>>> getInfluencerApplications({String? status}) {
    final query = _db.from('influencer_applications').stream(primaryKey: ['id']);
    final filtered = status != null ? query.eq('status', status) : query;
    return filtered.order('created_at', ascending: false).map((rows) => rows);
  }

  /// Influencer profiles ordered by total earnings.
  /// Realtime streams cannot embed relations, so the owning users row
  /// (full_name, email, phone) is fetched and merged under a 'users'
  /// key on each emission.
  Stream<List<Map<String, dynamic>>> getInfluencers() {
    return _db
        .from('influencers')
        .stream(primaryKey: ['user_id'])
        .order('total_earnings', ascending: false)
        .asyncMap((rows) async {
      if (rows.isEmpty) return <Map<String, dynamic>>[];
      final ids = rows.map((r) => r['user_id']).whereType<String>().toList();
      final users = await _db.from('users').select('id, full_name, email, phone').inFilter('id', ids);
      final byId = {for (final u in users) u['id']: u};
      return rows.map((r) => {...r, 'users': byId[r['user_id']]}).toList();
    });
  }

  /// Single influencer row with the owning users row embedded.
  Future<Map<String, dynamic>> getInfluencerDetail(String userId) async {
    final data = await _db
        .from('influencers')
        .select('*, users(full_name, email, phone)')
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) throw Exception('Influencer not found');
    return data;
  }

  /// Approve an influencer application by invoking the
  /// `generate-referral-code` Edge Function. The function approves the
  /// application, activates the influencer, mints the referral code,
  /// flips the user role, ensures a wallet, and notifies the user.
  /// Uses the current admin's access token for authorization.
  /// Returns the minted referral code.
  Future<String> approveApplication({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String applicationId,
  }) async {
    final session = SupabaseService.client.auth.currentSession;
    final token = session?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final functionsHost = SupabaseConfig.url.replaceFirst('.supabase.co', '.functions.supabase.co');
    final url = Uri.parse('$functionsHost/generate-referral-code');
    final resp = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'application_id': applicationId}),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      String message = resp.body;
      try {
        final body = json.decode(resp.body);
        if (body is Map && body['error'] != null) message = body['error'].toString();
      } catch (_) {}
      throw Exception('Approve application failed: ${resp.statusCode} $message');
    }

    final body = json.decode(resp.body) as Map<String, dynamic>;
    final referralCode = body['referral_code']?.toString() ?? '';

    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'approve_influencer_application',
      targetCollection: 'influencer_applications',
      targetId: applicationId,
      after: {'status': 'approved', 'referral_code': referralCode},
    );

    return referralCode;
  }

  Future<void> rejectApplication({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String applicationId,
    required String reason,
  }) async {
    final result = await _db.from('influencer_applications').update({
      'status': 'rejected',
      'rejection_reason': reason,
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId).select();
    if (result.isEmpty) {
      throw Exception(
        'Reject application failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'reject_influencer_application',
      targetCollection: 'influencer_applications',
      targetId: applicationId,
      after: {'status': 'rejected', 'rejection_reason': reason},
    );
  }

  /// Set an influencer's status ('active' | 'suspended').
  Future<void> setInfluencerStatus({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String userId,
    required String status,
  }) async {
    final result = await _db.from('influencers').update({'status': status}).eq('user_id', userId).select();
    if (result.isEmpty) {
      throw Exception(
        'Update influencer status failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'set_influencer_status',
      targetCollection: 'influencers',
      targetId: userId,
      after: {'status': status},
    );
  }

  /// Update the influencer program commission rates on the singleton
  /// system_settings row. Only non-null fields are written.
  Future<void> setInfluencerRates({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    double? agencyFeePct,
    double? premiumPct,
    double? registrationBonus,
    bool? programEnabled,
  }) async {
    final updates = <String, dynamic>{
      if (agencyFeePct != null) 'influencer_agency_fee_pct': agencyFeePct,
      if (premiumPct != null) 'influencer_premium_pct': premiumPct,
      if (registrationBonus != null) 'influencer_registration_bonus': registrationBonus,
      if (programEnabled != null) 'influencer_program_enabled': programEnabled,
    };
    if (updates.isEmpty) return;
    final result = await _db.from('system_settings').update(updates).eq('id', 'default').select();
    if (result.isEmpty) {
      throw Exception(
        'Update influencer rates failed: no rows updated. '
        'Check if the default settings row exists and you have admin permissions.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'set_influencer_rates',
      targetCollection: 'system_settings',
      after: updates,
    );
  }

  // ─── CAMPAIGNS ────────────────────────────────────────────────

  Stream<List<Map<String, dynamic>>> getCampaigns() {
    return _db
        .from('campaigns')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows);
  }

  Future<void> createCampaign({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required Map<String, dynamic> data,
  }) async {
    await _db.from('campaigns').insert({
      ...data,
      'status': 'draft',
      'created_by': adminId,
    });
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'create_campaign',
      targetCollection: 'campaigns',
      after: data,
    );
  }

  /// Set a campaign's status ('active' | 'paused' | 'ended').
  Future<void> setCampaignStatus({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String campaignId,
    required String status,
  }) async {
    final result = await _db.from('campaigns').update({'status': status}).eq('id', campaignId).select();
    if (result.isEmpty) {
      throw Exception(
        'Update campaign status failed: RLS blocked the update. '
        'Ensure your user has is_admin=true in the users table.',
      );
    }
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'set_campaign_status',
      targetCollection: 'campaigns',
      targetId: campaignId,
      after: {'status': status},
    );
  }

  Future<List<Map<String, dynamic>>> getCampaignParticipants(String campaignId) async {
    final rows = await _db
        .from('campaign_participants')
        .select('*, influencers(referral_code, users(full_name, email))')
        .eq('campaign_id', campaignId);
    return rows;
  }

  /// AI-ready heuristic matching of active influencers to a campaign
  /// (see match_influencers_for_campaign in migration 011).
  Future<List<Map<String, dynamic>>> matchInfluencers(String campaignId) async {
    final rows = await _db.rpc('match_influencers_for_campaign', params: {'p_campaign_id': campaignId});
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ─── REFERRAL CONVERSIONS / FRAUD / COMMISSIONS ───────────────

  Future<List<Map<String, dynamic>>> getReferralConversions({String? influencerId, int limit = 100}) async {
    var query = _db.from('referral_conversions').select();
    if (influencerId != null) query = query.eq('influencer_id', influencerId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getFraudLogs({String? influencerId, int limit = 100}) async {
    var query = _db.from('fraud_logs').select();
    if (influencerId != null) query = query.eq('influencer_id', influencerId);
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows;
  }

  /// Influencer commission ledger rows (earnings of type
  /// 'referralCommission'), newest first, with the influencer's
  /// full_name embedded under 'users'.
  Future<List<Map<String, dynamic>>> getCommissionEntries({int limit = 200}) async {
    final rows = await _db
        .from('earnings')
        .select('*, users(full_name)')
        .eq('type', 'referralCommission')
        .order('created_at', ascending: false)
        .limit(limit);
    return rows;
  }

  // ─── DIAGNOSTIC ───────────────────────────────────────────────

  /// Check if the current user has admin privileges in the database.
  /// Returns a map with 'is_admin', 'role', 'admin_role' values.
  Future<Map<String, dynamic>> checkAdminStatus() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Not authenticated');
    }
    final data = await _db.from('users').select('is_admin, role, admin_role, full_name').eq('id', userId).maybeSingle();
    if (data == null) {
      throw Exception('User not found in database');
    }
    return data;
  }
}
