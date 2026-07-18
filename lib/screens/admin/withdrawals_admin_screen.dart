import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class WithdrawalsAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const WithdrawalsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Withdrawal Requests', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Review and process agent/landlord payouts', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllWithdrawals(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final withdrawals = snapshot.data ?? [];
                  if (withdrawals.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No withdrawal requests')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Amount')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Provider')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: withdrawals.map((w) {
                        final status = w['status'] ?? 'pending';
                        final withdrawalId = w['id'] ?? '';
                        return DataRow(
                          cells: [
                            DataCell(Text(w['user_id']?.toString().substring(0, 8) ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                            DataCell(Text(Helpers.formatPrice((w['amount'] as num?)?.toDouble() ?? 0.0), style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(w['phone'] ?? '')),
                            DataCell(Text(w['provider'] ?? '')),
                            DataCell(_StatusChip(status: status)),
                            DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(w['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    tooltip: 'Approve',
                                    onPressed: () async {
                                      try {
                                        await AdminService().approveWithdrawal(
                                          adminId: adminId,
                                          adminName: adminName,
                                          adminRole: adminRole,
                                          withdrawalId: withdrawalId,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Withdrawal approved')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                                    tooltip: 'Reject',
                                    onPressed: () async {
                                      try {
                                        await AdminService().rejectWithdrawal(
                                          adminId: adminId,
                                          adminName: adminName,
                                          adminRole: adminRole,
                                          withdrawalId: withdrawalId,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Withdrawal rejected')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                  ),
                                if (status == 'processing')
                                  IconButton(
                                    icon: const Icon(Icons.send, color: Colors.blue, size: 18),
                                    tooltip: 'Execute Payout',
                                    onPressed: () async {
                                      try {
                                        await AdminService().executeWithdrawal(
                                          adminId: adminId,
                                          adminName: adminName,
                                          adminRole: adminRole,
                                          withdrawalId: withdrawalId,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Payout executed')),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                          );
                                        }
                                      }
                                    },
                                  ),
                              ],
                            )),
                          ],
                        );
                      }).toList(),
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
    final color = switch (status) {
      'pending' => Colors.orange,
      'processing' => Colors.blue,
      'completed' => Colors.green,
      'failed' => Colors.red,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
