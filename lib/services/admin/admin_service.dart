import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/supabase_service.dart';

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

  Future<List<Map<String, dynamic>>> getAllUsers({int limit = 100}) async {
    final rows = await _db.from('users').select().limit(limit);
    return rows;
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
    await _db.from('users').update({'role': newRole}).eq('id', userId);
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
    await _db.from('users').update({
      'is_verified_landlord': true,
      'verification_status': 'verified',
    }).eq('id', userId);
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
    await _db.from('users').update({'is_approved': false}).eq('id', userId);
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
    await _db.from('properties').update({'is_approved': true}).eq('id', propertyId);
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
    await _db.from('properties').update({'is_approved': false}).eq('id', propertyId);
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

  Future<List<Map<String, dynamic>>> getAllWallets({int limit = 100}) async {
    final rows = await _db.from('wallets').select().limit(limit);
    return rows;
  }

  Future<Map<String, dynamic>?> getWalletByUserId(String userId) async {
    return await _db.from('wallets').select().eq('user_id', userId).maybeSingle();
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllTransactions({int limit = 200}) async {
    final rows = await _db.from('transactions').select().order('created_at', ascending: false).limit(limit);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getTransactionsByStatus(String status, {int limit = 100}) async {
    final rows = await _db.from('transactions').select().eq('status', status).limit(limit);
    return rows;
  }

  // ─── WITHDRAWALS ────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAllWithdrawals({int limit = 200}) async {
    final rows = await _db.from('withdrawals').select().order('created_at', ascending: false).limit(limit);
    return rows;
  }

  Future<void> approveWithdrawal({
    required String adminId,
    required String adminName,
    required AdminRole adminRole,
    required String withdrawalId,
  }) async {
    await _db.from('withdrawals').update({'status': 'processing'}).eq('id', withdrawalId);
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
    await _db.from('withdrawals').update({
      'status': 'failed',
      'failure_reason': reason,
    }).eq('id', withdrawalId);
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'reject_withdrawal',
      targetCollection: 'withdrawals',
      targetId: withdrawalId,
    );
  }

  // ─── FRAUD / DISPUTES ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFraudReports({int limit = 100}) async {
    final rows = await _db.from('fraud_reports').select().limit(limit);
    return rows;
  }

  Future<List<Map<String, dynamic>>> getDisputes({int limit = 100}) async {
    final rows = await _db.from('disputes').select().limit(limit);
    return rows;
  }

  // ─── ANALYTICS ──────────────────────────────────────────────────

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
    await _db.from('system_settings').update(settings).eq('id', 'default');
    await _logAction(
      adminId: adminId,
      adminName: adminName,
      adminRole: adminRole,
      action: 'update_system_settings',
      targetCollection: 'system_settings',
    );
  }
}
