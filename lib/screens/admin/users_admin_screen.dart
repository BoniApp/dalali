import 'package:flutter/material.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:intl/intl.dart';

class UsersAdminScreen extends StatelessWidget {
  const UsersAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('User Management', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Manage seekers, landlords, and agents', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getAllUsers(limit: 100),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final users = snapshot.data ?? [];
                  if (users.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No users found')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Phone')),
                        DataColumn(label: Text('Role')),
                        DataColumn(label: Text('Verification')),
                        DataColumn(label: Text('Joined')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: users.map((u) => DataRow(
                        cells: [
                          DataCell(Text(u['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(u['email'] ?? '')),
                          DataCell(Text(u['phone'] ?? '')),
                          DataCell(Chip(
                            label: Text(u['role'] ?? 'seeker', style: const TextStyle(fontSize: 10)),
                            backgroundColor: _roleColor(u['role'] ?? 'seeker').withValues(alpha: 0.1),
                            labelStyle: TextStyle(fontSize: 10, color: _roleColor(u['role'] ?? 'seeker'), fontWeight: FontWeight.bold),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          )),
                          DataCell(
                            (u['verification_status'] ?? '') == 'verified'
                                ? const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.verified, color: Colors.green, size: 16), SizedBox(width: 4), Text('Verified')])
                                : Text(u['verification_status'] ?? '', style: const TextStyle(color: Colors.grey)),
                          ),
                          DataCell(Text(DateFormat('dd MMM yyyy').format(DateTime.tryParse(u['created_at'] ?? '') ?? DateTime.now()), style: const TextStyle(fontSize: 12))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.verified_user, size: 18),
                                tooltip: 'Verify',
                                onPressed: () {},
                              ),
                              IconButton(
                                icon: const Icon(Icons.block, color: Colors.red, size: 18),
                                tooltip: 'Suspend',
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

  Color _roleColor(String role) {
    return switch (role.toLowerCase()) {
      'seeker' => Colors.blue,
      'landlord' => Colors.teal,
      'agent' => Colors.purple,
      _ => Colors.grey,
    };
  }
}
