import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/models/earnings_model.dart';
import 'package:dalali/screens/earnings/agency_fee_history_screen.dart';
import 'package:dalali/screens/wallet/withdrawal_screen.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appState = context.watch<AppState>();
    final summary = appState.earningsSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.earnings),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EarningsCard(
                label: l10n.totalEarned,
                amount: summary.totalEarned,
                icon: Icons.paid,
                color: Colors.green,
              ),
              const SizedBox(height: 12),
              _EarningsCard(
                label: l10n.pendingEarnings,
                amount: summary.pendingEarnings,
                icon: Icons.hourglass_top,
                color: Colors.orange,
              ),
              const SizedBox(height: 12),
              _EarningsCard(
                label: l10n.withdrawableBalance,
                amount: summary.withdrawableBalance,
                icon: Icons.account_balance_wallet,
                color: Colors.teal,
              ),
              const SizedBox(height: 12),
              _EarningsCard(
                label: l10n.successfulListings,
                amount: summary.successfulListings.toDouble(),
                icon: Icons.check_circle,
                color: Colors.blue,
                isInteger: true,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                  );
                },
                icon: const Icon(Icons.output),
                label: Text(l10n.withdrawableBalance),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgencyFeeHistoryScreen()),
                  );
                },
                icon: const Icon(Icons.history),
                label: Text(l10n.agencyFeeHistory),
              ),
              const SizedBox(height: 24),
              if (appState.myEarnings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      l10n.noEarningsYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                )
              else
                ...appState.myEarnings.take(5).map((e) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _statusColor(e.status).withAlpha(30),
                        child: Icon(
                          e.type == EarningsEntryType.agencyFee
                              ? Icons.handshake
                              : Icons.card_giftcard,
                          color: _statusColor(e.status),
                        ),
                      ),
                      title: Text(e.propertyTitle ?? l10n.agencyFeeHistory),
                      subtitle: Text('${e.amount.toStringAsFixed(0)} ${e.currency}'),
                      trailing: Chip(
                        label: Text(
                          e.status.name,
                          style: const TextStyle(fontSize: 10),
                        ),
                        backgroundColor: _statusColor(e.status).withAlpha(30),
                      ),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(dynamic status) {
    switch (status.toString()) {
      case 'EarningsEntryStatus.available':
        return Colors.green;
      case 'EarningsEntryStatus.pending':
        return Colors.orange;
      case 'EarningsEntryStatus.withdrawn':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _EarningsCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  final bool isInteger;

  const _EarningsCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
    this.isInteger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 4),
                  Text(
                    isInteger ? amount.toInt().toString() : '${amount.toStringAsFixed(0)} TZS',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
