import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:intl/intl.dart';

class FraudAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const FraudAdminScreen({
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
            const Text('Fraud & Disputes', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Review flagged users, reports, and disputes', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllFraudReports(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final reports = snapshot.data ?? [];
                  if (reports.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No fraud reports')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Reporter')),
                        DataColumn(label: Text('Reported')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: reports.map((r) {
                        final reportId = r['id'] ?? '';
                        final status = r['status'] ?? 'pending';
                        return DataRow(
                          cells: [
                            DataCell(Text(r['reporter_id']?.toString().substring(0, 8) ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                            DataCell(Text(r['reported_id']?.toString().substring(0, 8) ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                            DataCell(Chip(
                              label: Text(r['type'] ?? '', style: const TextStyle(fontSize: 10)),
                              backgroundColor: Colors.red.withValues(alpha: 0.1),
                              labelStyle: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            )),
                            DataCell(Text(r['description'] ?? '', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                            DataCell(_StatusChip(status: status)),
                            DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'pending')
                                  IconButton(
                                    icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    tooltip: 'Mark Resolved',
                                    onPressed: () async {
                                      try {
                                        await AdminService().resolveFraudReport(
                                          adminId: adminId,
                                          adminName: adminName,
                                          adminRole: adminRole,
                                          reportId: reportId,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Report marked resolved')),
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
      'resolved' => Colors.green,
      'rejected' => Colors.red,
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
