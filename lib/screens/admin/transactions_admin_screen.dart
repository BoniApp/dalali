import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class TransactionsAdminScreen extends StatelessWidget {
  const TransactionsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Transactions', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('All Selcom payment transactions', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllTransactions(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final txs = snapshot.data ?? [];
                  if (txs.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No transactions found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Payer')),
                        DataColumn(label: Text('Payee')),
                        DataColumn(label: Text('Property')),
                        DataColumn(label: Text('Selcom Ref')),
                        DataColumn(label: Text('Date')),
                      ],
                      rows: txs.map((tx) => DataRow(
                        cells: [
                          DataCell(Text((tx['id'] ?? '').substring(0, (tx['id'] ?? '').length > 8 ? 8 : (tx['id'] ?? '').length), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text(tx['type'] ?? '-')),
                          DataCell(_StatusChip(status: tx['status'] ?? 'pending')),
                          DataCell(Text(Helpers.formatPrice((tx['amount'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(tx['payer_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(tx['payee_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(tx['property_title'] ?? tx['property_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(tx['selcom_transaction_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(DateFormat('dd MMM yyyy HH:mm').format(DateTime.tryParse(tx['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
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
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status.toLowerCase()) {
      'pending' => (Colors.orange, 'Pending'),
      'processing' => (Colors.blue, 'Processing'),
      'locked' => (Colors.purple, 'Locked'),
      'available' => (Colors.green, 'Available'),
      'completed' => (AppTheme.primary, 'Completed'),
      'failed' => (Colors.red, 'Failed'),
      'reversed' => (Colors.grey, 'Reversed'),
      _ => (Colors.grey, status),
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
