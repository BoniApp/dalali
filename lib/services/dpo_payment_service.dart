import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/models/payment_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Result of create-dpo-token.
class DpoTokenResult {
  final String paymentUrl;
  final String token;
  final String paymentId;
  const DpoTokenResult({required this.paymentUrl, required this.token, required this.paymentId});
}

/// ═══════════════════════════════════════════════════════════════
/// DPO PAYMENT SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Client for the DPO Pay edge functions. The DPO company token
/// never leaves the server — the app only talks to Supabase:
///
///   createToken → create-dpo-token → hosted payment page URL
///   verify      → verify-dpo-payment → VerifyToken + settle
class DpoPaymentService {
  final SupabaseClient _db = SupabaseService.client;

  /// Mint a DPO token for the agency fee on [propertyId]. Returns the
  /// hosted payment page to open. Throws on error (message is
  /// user-presentable).
  Future<DpoTokenResult> createToken(String propertyId) async {
    final res = await _db.functions.invoke(
      'create-dpo-token',
      body: {'property_id': propertyId},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return DpoTokenResult(
      paymentUrl: data['paymentUrl'] as String,
      token: data['token'] as String,
      paymentId: data['paymentId'] as String,
    );
  }

  /// Verify + settle a payment after the customer returns from the
  /// hosted page. Returns the updated payment (check `status`).
  Future<PaymentModel> verify(String token) async {
    final res = await _db.functions.invoke(
      'verify-dpo-payment',
      body: {'token': token},
    );
    final data = res.data as Map<String, dynamic>;
    if (data['error'] != null) throw Exception(data['error']);
    return PaymentModel.fromJson(Map<String, dynamic>.from(data['payment'] as Map));
  }

  /// Watch a payment row (settlement may also land via dpo-callback).
  Stream<PaymentModel?> watchPayment(String paymentId) {
    return _db
        .from('payments')
        .stream(primaryKey: ['id'])
        .eq('id', paymentId)
        .map((rows) => rows.isEmpty ? null : PaymentModel.fromJson(rows.first));
  }

  /// Fetch a payment by its DPO token (deep-link entry).
  Future<PaymentModel?> getPaymentByToken(String token) async {
    final row = await _db.from('payments').select().eq('dpo_token', token).maybeSingle();
    return row == null ? null : PaymentModel.fromJson(row);
  }

  /// Whether [userId] has paid access (contact unlocked) to [propertyId].
  Stream<bool> watchPropertyAccess(String userId, String propertyId) {
    return _db
        .from('property_access')
        .stream(primaryKey: ['id'])
        .eq('property_id', propertyId)
        .map((rows) => rows.any((r) => r['tenant_id'] == userId && r['paid'] == true));
  }
}
