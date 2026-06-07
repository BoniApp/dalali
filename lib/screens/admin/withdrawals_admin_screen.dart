import 'package:flutter/material.dart';
import 'package:dalali/models/wallet_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class WithdrawalsAdminScreen extends StatelessWidget {
  const WithdrawalsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdrawal Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Approve or reject agent withdrawal requests', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<WithdrawalModel>>(
                stream: AdminService().getAllWithdrawals(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final wds = snapshot.data ?? [];
                  if (wds.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No withdrawals found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Provider')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: wds.map((w) => DataRow(
                        cells: [
                          DataCell(Text(w.id.substring(0, w.id.length > 8 ? 8 : w.id.length), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text(w.userId, style: const TextStyle(fontSize: 12))),
                          DataCell(Text(Helpers.formatPrice(w.amount), style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(w.phone)),
                          DataCell(Text(w.provider.name)),
                          DataCell(_StatusChip(status: w.status)),
                          DataCell(Text(DateFormat('dd MMM yyyy').format(w.createdAt), style: const TextStyle(fontSize: 12))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (w.status == WithdrawalStatus.pending) ...[
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  tooltip: 'Approve',
                                  onPressed: () {},
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                  tooltip: 'Reject',
                                  onPressed: () {},
                                ),
                              ],
                            ],
                          )),
                        ],
                      )).toList(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final WithdrawalStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      WithdrawalStatus.pending => (Colors.orange, 'Pending'),
      WithdrawalStatus.processing => (Colors.blue, 'Processing'),
      WithdrawalStatus.completed => (Colors.green, 'Completed'),
      WithdrawalStatus.failed => (Colors.red, 'Failed'),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
