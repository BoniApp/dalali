import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/models/payment_gateway_model.dart';

class PaymentService {
  final _db = SupabaseService.client;

  Stream<List<Map<String, dynamic>>> getAllTransactions({int limit = 200}) {
    return _db.from('transactions').stream(primaryKey: ['id']).limit(limit).map((rows) => rows);
  }

  Future<Map<String, dynamic>?> getTransactionById(String id) async {
    return await _db.from('transactions').select().eq('id', id).maybeSingle();
  }

  Future<void> createTransaction({
    required String id,
    required String userId,
    required double amount,
    required String currency,
    required String provider,
    required String reference,
    required String service,
  }) async {
    await _db.from('transactions').insert({
      'id': id,
      'user_id': userId,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'reference': reference,
      'service': service,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateTransactionStatus(String id, String status) async {
    await _db.from('transactions').update({'status': status}).eq('id', id);
  }

  // ─── WALLETS / LEDGER ─────────────────────────────────────
  Future<Map<String, dynamic>?> getWalletByUser(String userId) async {
    return await _db.from('wallets').select().eq('user_id', userId).maybeSingle();
  }

  Future<void> createWalletForUser(String userId) async {
    await _db.from('wallets').insert({'user_id': userId, 'balance': 0, 'commission_total': 0, 'withdrawn_amount': 0});
  }

  Future<void> creditWallet(String userId, double amount) async {
    await _db.rpc('wallet_credit', params: {'p_user_id': userId, 'p_amount': amount});
  }

  Future<void> debitWallet(String userId, double amount) async {
    await _db.rpc('wallet_debit', params: {'p_user_id': userId, 'p_amount': amount});
  }

  Future<void> recordCommission({
    required String agentId,
    required String transactionId,
    required double percentage,
    required double amount,
  }) async {
    await _db.from('commissions').insert({
      'agent_id': agentId,
      'transaction_id': transactionId,
      'percentage': percentage,
      'amount': amount,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<PaymentGatewayModel>> getGateways() async {
    final rows = await _db.from('payment_gateways').select().order('provider_name').limit(50);
    return (rows as List).map((r) => PaymentGatewayModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<void> updateGateway(String id, Map<String, dynamic> payload) async {
    await _db.from('payment_gateways').update(payload).eq('id', id);
  }

  Future<void> createGateway(Map<String, dynamic> payload) async {
    await _db.from('payment_gateways').insert(payload);
  }

  Future<void> deleteGateway(String id) async {
    await _db.from('payment_gateways').delete().eq('id', id);
  }
}
