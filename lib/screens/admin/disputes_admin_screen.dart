import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:intl/intl.dart';

class DisputesAdminScreen extends StatelessWidget {
  const DisputesAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dispute Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Handle tenant-landlord and payment disputes', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllDisputes(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final disputes = snapshot.data ?? [];
                  if (disputes.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No disputes found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Reporter')),
                        DataColumn(label: Text('Respondent')),
                        DataColumn(label: Text('Subject')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: disputes.map((d) => DataRow(
                        cells: [
                          DataCell(Text((d['id'] as String).substring(0, 8), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text(d['reporter_id'] ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(d['respondent_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(d['type'] ?? '')),
                          DataCell(_StatusChip(status: d['status'] ?? '')),
                          DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(d['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
                          DataCell(
                            (d['status'] == 'open' || d['status'] == 'mediating')
                                ? IconButton(
                                    icon: const Icon(Icons.gavel, color: Colors.teal, size: 18),
                                    tooltip: 'Resolve',
                                    onPressed: () => _showResolveDialog(context, d),
                                  )
                                : const Icon(Icons.check_circle, color: Colors.green, size: 18),
                          ),
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

  void _showResolveDialog(BuildContext context, Map<String, dynamic> dispute) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resolve Dispute'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${dispute['type'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Description: ${dispute['description'] ?? ''}'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Resolution', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              await AdminService().resolveDispute(
                disputeId: dispute['id'] ?? '',
                resolution: controller.text,
                adminId: 'admin',
                adminName: 'Admin',
                adminRole: AdminRole.superAdmin,
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Resolve'),
          ),
        ],
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
      'open' => Colors.orange,
      'under_review' => Colors.blue,
      'resolved' => Colors.green,
      'closed' => Colors.grey,
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
