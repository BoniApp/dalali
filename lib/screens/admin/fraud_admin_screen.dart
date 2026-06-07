import 'package:flutter/material.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:intl/intl.dart';

class FraudAdminScreen extends StatelessWidget {
  const FraudAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fraud Detection', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Review and resolve fraud alerts', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
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
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No unresolved fraud alerts')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('User')),
                        DataColumn(label: Text('Property')),
                        DataColumn(label: Text('Reason')),
                        DataColumn(label: Text('Severity')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: reports.map((r) => DataRow(
                        cells: [
                          DataCell(Text((r['id'] ?? '').substring(0, (r['id'] ?? '').length > 8 ? 8 : (r['id'] ?? '').length), style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                          DataCell(Text(r['user_id'] ?? '', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(r['property_id'] ?? '-', style: const TextStyle(fontSize: 12))),
                          DataCell(Text(r['reason'] ?? '')),
                          DataCell(_SeverityChip(severity: r['severity'] ?? 'medium')),
                          DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(r['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
                          DataCell(
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              tooltip: 'Resolve',
                              onPressed: () {},
                            ),
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
}

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity.toLowerCase()) {
      'critical' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.amber,
      _ => Colors.blue,
    };
    return Chip(
      label: Text(severity.toUpperCase(), style: const TextStyle(fontSize: 10)),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
