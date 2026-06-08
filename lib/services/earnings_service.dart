import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/services/data_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// EARNINGS SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Manages the earnings wallet: agency fee tracking, availability,
/// and withdrawal request integration.
///
class EarningsService {
  final DataService _data = DataService();

  static const double agencyFeeAmount = 20000.0;

  /// Create an earnings entry when a tenancy is confirmed.
  Future<EarningsEntryModel> createAgencyFeeEntry({
    required String userId,
    required String dealId,
    required String propertyId,
    String? propertyTitle,
  }) async {
    final entry = EarningsEntryModel(
      entryId: 'ear_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      dealId: dealId,
      propertyId: propertyId,
      propertyTitle: propertyTitle,
      type: EarningsEntryType.agencyFee,
      status: EarningsEntryStatus.pending,
      amount: agencyFeeAmount,
      currency: 'TZS',
      createdAt: DateTime.now(),
    );
    await _data.addEarningsEntry(entry);
    return entry;
  }

  /// Mark an entry as available for withdrawal.
  Future<void> markAvailable(String entryId) async {
    final entries = await _data.getEarningsForUser('').first;
    final entry = entries.firstWhere((e) => e.entryId == entryId);
    await _data.updateEarningsEntry(entry.copyWith(
      status: EarningsEntryStatus.available,
      availableAt: DateTime.now(),
    ));
  }

  /// Mark entry as withdrawn and link to withdrawal record.
  Future<void> markWithdrawn(String entryId, String withdrawalId) async {
    final entries = await _data.getEarningsForUser('').first;
    final entry = entries.firstWhere((e) => e.entryId == entryId);
    await _data.updateEarningsEntry(entry.copyWith(
      status: EarningsEntryStatus.withdrawn,
      withdrawnAt: DateTime.now(),
      withdrawalId: withdrawalId,
    ));
  }

  /// Compute aggregate summary for a user.
  EarningsSummaryModel computeSummary(List<EarningsEntryModel> entries) {
    double totalEarned = 0;
    double pending = 0;
    double withdrawable = 0;
    int successful = 0;

    for (final e in entries) {
      totalEarned += e.amount;
      if (e.status == EarningsEntryStatus.pending) {
        pending += e.amount;
      } else if (e.status == EarningsEntryStatus.available) {
        withdrawable += e.amount;
        successful++;
      } else if (e.status == EarningsEntryStatus.withdrawn) {
        successful++;
      }
    }

    return EarningsSummaryModel(
      totalEarned: totalEarned,
      pendingEarnings: pending,
      withdrawableBalance: withdrawable,
      successfulListings: successful,
      pendingListings: entries.where((e) => e.status == EarningsEntryStatus.pending).length,
    );
  }
}
