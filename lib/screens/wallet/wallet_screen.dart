import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/wallet_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:dalali/screens/wallet/transaction_history_screen.dart';
import 'package:dalali/screens/wallet/withdrawal_screen.dart';
import 'package:provider/provider.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wallet'), backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
        body: const Center(child: Text('Please log in to view your wallet')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<WalletModel?>(
        stream: WalletService().getWallet(user.id),
        builder: (context, snapshot) {
          final wallet = snapshot.data;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BalanceCard(wallet: wallet, user: user),
                const SizedBox(height: 24),
                _ActionButton(
                  icon: Icons.account_balance_wallet,
                  label: 'Withdraw Funds',
                  color: AppTheme.primary,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WithdrawalScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                _ActionButton(
                  icon: Icons.receipt_long,
                  label: 'Transaction History',
                  color: Colors.blue,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Earnings Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _StatRow(label: 'Total Earned', value: wallet?.totalEarned ?? 0, color: Colors.green),
                _StatRow(label: 'Total Withdrawn', value: wallet?.totalWithdrawn ?? 0, color: Colors.orange),
                _StatRow(label: 'Pending', value: wallet?.pendingBalance ?? 0, color: Colors.amber),
                _StatRow(label: 'Locked', value: wallet?.lockedBalance ?? 0, color: Colors.red),
                const SizedBox(height: 24),
                const Text('How It Works', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const _HowItWorksCard(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final WalletModel? wallet;
  final UserModel user;

  const _BalanceCard({required this.wallet, required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primary,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Available Balance', style: TextStyle(fontSize: 14, color: Colors.white70)),
                Icon(Icons.account_balance_wallet, color: Colors.white.withValues(alpha: 0.7)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Helpers.formatPrice(wallet?.availableBalance ?? 0),
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Per Deal', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                      Text(
                        Helpers.formatPrice(AppSettings.agencyFee),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Share (60%)', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7))),
                      Text(
                        Helpers.formatPrice(AppSettings.agencyFee * 0.60),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _StatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ],
          ),
          Text(Helpers.formatPrice(value), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StepItem(number: 1, text: 'Pay agency fee via DPO Pay (TZS 20,000) to unlock a property\'s contact details'),
            const SizedBox(height: 12),
            _StepItem(number: 2, text: 'Funds are held in escrow for 48 hours for your protection'),
            const SizedBox(height: 12),
            _StepItem(number: 3, text: 'When you earn from deals, revenue is split 60% to you, 40% to platform'),
            const SizedBox(height: 12),
            _StepItem(number: 4, text: 'Withdraw your earnings anytime (min TZS 5,000)'),
          ],
        ),
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final int number;
  final String text;

  const _StepItem({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: AppTheme.primary.withAlpha(26),
          child: Text('$number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryDark)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4))),
      ],
    );
  }
}
