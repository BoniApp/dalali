import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/wallet_model.dart';

/// Client-side wallet service.
///
/// ⚠️ IMPORTANT: This service is READ-ONLY for wallet balances.
/// All wallet mutations (credit, debit, split) happen server-side
/// via Firebase Functions to prevent fraud.
class WalletService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _wallets => _db.collection('wallets');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _withdrawals => _db.collection('withdrawals');
  DocumentReference get _systemSettings => _db.collection('systemSettings').doc('default');

  // ─── WALLET ─────────────────────────────────────────────────

  /// Stream a user's wallet document.
  Stream<WalletModel?> getWallet(String userId) {
    return _wallets
        .doc(userId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return WalletModel.fromJson(doc.data() as Map<String, dynamic>);
    });
  }

  /// Get wallet once (for initial load).
  Future<WalletModel?> getWalletOnce(String userId) async {
    final doc = await _wallets.doc(userId).get();
    if (!doc.exists) return null;
    return WalletModel.fromJson(doc.data() as Map<String, dynamic>);
  }

  // ─── TRANSACTIONS ───────────────────────────────────────────

  /// Stream a user's transactions (as payer or payee).
  Stream<List<TransactionModel>> getUserTransactions(String userId, {int limit = 50}) {
    return _transactions
        .where(Filter.or(
          Filter('payerId', isEqualTo: userId),
          Filter('payeeId', isEqualTo: userId),
        ))
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Stream transactions for a specific property.
  Stream<List<TransactionModel>> getPropertyTransactions(String propertyId, {int limit = 20}) {
    return _transactions
        .where('propertyId', isEqualTo: propertyId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromJson(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // ─── WITHDRAWALS ────────────────────────────────────────────

  /// Stream a user's withdrawal requests.
  Stream<List<WithdrawalModel>> getUserWithdrawals(String userId, {int limit = 30}) {
    return _withdrawals
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WithdrawalModel.fromJson(
                doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  /// Create a withdrawal request.
  /// This writes to Firestore; the backend Firebase Function
  /// picks it up and processes the Selcom payout.
  Future<void> requestWithdrawal(WithdrawalModel withdrawal) async {
    await _withdrawals.doc(withdrawal.id).set(withdrawal.toJson());
  }

  // ─── SYSTEM SETTINGS ────────────────────────────────────────

  /// Stream system-wide financial settings.
  Stream<SystemSettingsModel> getSystemSettings() {
    return _systemSettings.snapshots().map((doc) {
      if (!doc.exists) return SystemSettingsModel(updatedAt: DateTime.now());
      return SystemSettingsModel.fromJson(doc.data() as Map<String, dynamic>);
    });
  }

  /// Get system settings once.
  Future<SystemSettingsModel> getSystemSettingsOnce() async {
    final doc = await _systemSettings.get();
    if (!doc.exists) return SystemSettingsModel(updatedAt: DateTime.now());
    return SystemSettingsModel.fromJson(doc.data() as Map<String, dynamic>);
  }
}
