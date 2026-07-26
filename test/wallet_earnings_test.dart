import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/services/earnings_service.dart';

EarningsEntryModel _entry({
  required String entryId,
  required EarningsEntryStatus status,
  double amount = 20000,
}) {
  return EarningsEntryModel(
    entryId: entryId,
    userId: 'u1',
    type: EarningsEntryType.agencyFee,
    status: status,
    amount: amount,
    createdAt: DateTime.now(),
  );
}

void main() {
  group('WalletModel.totalBalance', () {
    test('sums available, pending and locked balances', () {
      final wallet = WalletModel(
        userId: 'u1',
        availableBalance: 10000,
        pendingBalance: 5000,
        lockedBalance: 2000,
        updatedAt: DateTime.now(),
      );
      expect(wallet.totalBalance, 17000);
    });

    test('defaults to zero balances', () {
      final wallet = WalletModel(userId: 'u1', updatedAt: DateTime.now());
      expect(wallet.totalBalance, 0);
    });
  });

  group('EarningsService.computeSummary', () {
    final service = EarningsService();

    test('empty entries produce a zeroed summary', () {
      final summary = service.computeSummary(const []);
      expect(summary.totalEarned, 0);
      expect(summary.pendingEarnings, 0);
      expect(summary.withdrawableBalance, 0);
      expect(summary.successfulListings, 0);
      expect(summary.pendingListings, 0);
    });

    test('sums pending entries into pendingEarnings, not withdrawableBalance', () {
      final summary = service.computeSummary([
        _entry(entryId: 'e1', status: EarningsEntryStatus.pending, amount: 20000),
        _entry(entryId: 'e2', status: EarningsEntryStatus.pending, amount: 20000),
      ]);
      expect(summary.totalEarned, 40000);
      expect(summary.pendingEarnings, 40000);
      expect(summary.withdrawableBalance, 0);
      expect(summary.pendingListings, 2);
      expect(summary.successfulListings, 0);
    });

    test('sums available entries into withdrawableBalance and counts them successful', () {
      final summary = service.computeSummary([
        _entry(entryId: 'e1', status: EarningsEntryStatus.available, amount: 20000),
      ]);
      expect(summary.withdrawableBalance, 20000);
      expect(summary.successfulListings, 1);
      expect(summary.pendingListings, 0);
    });

    test('withdrawn entries count as successful but not withdrawable', () {
      final summary = service.computeSummary([
        _entry(entryId: 'e1', status: EarningsEntryStatus.withdrawn, amount: 20000),
      ]);
      expect(summary.withdrawableBalance, 0);
      expect(summary.successfulListings, 1);
      expect(summary.totalEarned, 20000);
    });

    test('a mix of statuses aggregates correctly', () {
      final summary = service.computeSummary([
        _entry(entryId: 'e1', status: EarningsEntryStatus.pending, amount: 20000),
        _entry(entryId: 'e2', status: EarningsEntryStatus.available, amount: 20000),
        _entry(entryId: 'e3', status: EarningsEntryStatus.withdrawn, amount: 20000),
      ]);
      expect(summary.totalEarned, 60000);
      expect(summary.pendingEarnings, 20000);
      expect(summary.withdrawableBalance, 20000);
      expect(summary.successfulListings, 2);
      expect(summary.pendingListings, 1);
    });
  });
}
