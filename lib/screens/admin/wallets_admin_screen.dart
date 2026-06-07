import 'package:flutter/material.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';

class WalletsAdminScreen extends StatelessWidget {
  const WalletsAdminScreen({super.key});

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
                const Text('Wallet Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.file_download),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('View and manage user wallet balances', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllWallets(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final wallets = snapshot.data ?? [];
                  if (wallets.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No wallets found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('User ID')),
                        DataColumn(label: Text('Available')),
                        DataColumn(label: Text('Pending')),
                        DataColumn(label: Text('Locked')),
                        DataColumn(label: Text('Total Earned')),
                        DataColumn(label: Text('Total Withdrawn')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: wallets.map((w) => DataRow(
                        cells: [
                          DataCell(Text(w['user_id'] ?? '', style: const TextStyle(fontSize: 12, fontFamily: 'monospace'))),
                          DataCell(Text(Helpers.formatPrice((w['available_balance'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(Helpers.formatPrice((w['pending_balance'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Text(Helpers.formatPrice((w['locked_balance'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Text(Helpers.formatPrice((w['total_earned'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Text(Helpers.formatPrice((w['total_withdrawn'] as num?)?.toDouble() ?? 0.0))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.lock, size: 18),
                                tooltip: 'Freeze',
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                tooltip: 'Adjust',
                                onPressed: () {},
                              ),
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
