import 'package:flutter/material.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/wallet_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key});

  String _typeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.agencyFee:
        return 'Agency Fee';
      case TransactionType.revenueShare:
        return 'Revenue Share';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.refund:
        return 'Refund';
      case TransactionType.adminAdjustment:
        return 'Adjustment';
    }
  }

  Color _statusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Colors.orange;
      case TransactionStatus.processing:
        return Colors.blue;
      case TransactionStatus.locked:
        return Colors.purple;
      case TransactionStatus.available:
        return Colors.green;
      case TransactionStatus.completed:
        return Colors.teal;
      case TransactionStatus.failed:
        return Colors.red;
      case TransactionStatus.reversed:
        return Colors.grey;
    }
  }

  IconData _typeIcon(TransactionType type) {
    switch (type) {
      case TransactionType.agencyFee:
        return Icons.payments;
      case TransactionType.revenueShare:
        return Icons.trending_up;
      case TransactionType.withdrawal:
        return Icons.account_balance_wallet;
      case TransactionType.refund:
        return Icons.replay;
      case TransactionType.adminAdjustment:
        return Icons.settings;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<List<TransactionModel>>(
              stream: WalletService().getUserTransactions(user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final transactions = snapshot.data ?? [];

                if (transactions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No transactions yet', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    final isIncoming = tx.payeeId == user.id;
                    final isOutgoing = tx.payerId == user.id;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(tx.status).withValues(alpha: 0.1),
                          child: Icon(_typeIcon(tx.type), color: _statusColor(tx.status), size: 20),
                        ),
                        title: Text(
                          _typeLabel(tx.type),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt),
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 2),
                            if (tx.propertyTitle != null)
                              Text(
                                tx.propertyTitle!,
                                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _statusColor(tx.status).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    tx.status.name.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: _statusColor(tx.status),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${isIncoming ? '+' : isOutgoing ? '-' : ''}${Helpers.formatPrice(tx.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isIncoming
                                ? Colors.green
                                : isOutgoing
                                    ? Colors.red
                                    : Colors.black,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
