import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Client-side wallet service.
///
/// ⚠️ IMPORTANT: This service is READ-ONLY for wallet balances.
/// All wallet mutations (credit, debit, split) happen server-side
/// via Supabase Edge Functions to prevent fraud.
class WalletService {
  final _db = SupabaseService.client;

  // ─── WALLET ─────────────────────────────────────────────────

  Stream<WalletModel?> getWallet(String userId) {
    return _db
        .from('wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isEmpty ? null : WalletModel.fromJson(rows.first));
  }

  Future<WalletModel?> getWalletOnce(String userId) async {
    final data = await _db
        .from('wallets')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return WalletModel.fromJson(data);
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────

  Stream<List<TransactionModel>> getUserTransactions(String userId, {int limit = 50}) {
    return _db
        .from('transactions')
        .stream(primaryKey: ['id'])
        .map((rows) => rows
            .where((r) => r['payer_id'] == userId || r['payee_id'] == userId)
            .map((r) => TransactionModel.fromJson(r, r['id'] ?? ''))
            .toList());
  }

  Future<void> createTransaction(TransactionModel tx) async {
    await _db.from('transactions').insert(tx.toJson());
  }

  // ─── WITHDRAWALS ────────────────────────────────────────────

  Stream<List<WithdrawalModel>> getUserWithdrawals(String userId, {int limit = 50}) {
    return _db
        .from('withdrawals')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((rows) => rows.map((r) => WithdrawalModel.fromJson(r, r['id'] ?? '')).toList());
  }

  Future<void> createWithdrawal(WithdrawalModel wd) async {
    await _db.from('withdrawals').insert(wd.toJson());
  }

  // ─── SYSTEM SETTINGS ────────────────────────────────────────

  Future<Map<String, dynamic>> getSystemSettings() async {
    final data = await _db
        .from('system_settings')
        .select()
        .eq('id', 'default')
        .maybeSingle();
    return data ?? {
      'agency_fee': 20000,
      'agent_share': 0.60,
      'platform_share': 0.40,
      'settlement_delay_hours': 48,
      'min_withdrawal': 5000,
    };
  }

  Future<Map<String, dynamic>> getSystemSettingsOnce() async {
    return await getSystemSettings();
  }

  Future<void> requestWithdrawal(WithdrawalModel withdrawal) async {
    await createWithdrawal(withdrawal);
  }
}
