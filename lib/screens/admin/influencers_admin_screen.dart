import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/screens/admin/influencer_detail_admin_screen.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class InfluencersAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const InfluencersAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text('Influencer Partnerships', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Review applications and manage influencers', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            ),
            const SizedBox(height: 16),
            TabBar(
              labelColor: AppTheme.primaryDark,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryDark,
              tabs: const [
                Tab(text: 'Applications'),
                Tab(text: 'Influencers'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ApplicationsTab(adminId: adminId, adminName: adminName, adminRole: adminRole),
                  _InfluencersTab(adminId: adminId, adminName: adminName, adminRole: adminRole),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationsTab extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const _ApplicationsTab({required this.adminId, required this.adminName, required this.adminRole});

  Future<void> _approve(BuildContext context, Map<String, dynamic> application) async {
    final name = application['full_name'] ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Application'),
        content: Text('Approve $name as an influencer? A referral code will be generated and the user will be notified.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final code = await AdminService().approveApplication(
        adminId: adminId,
        adminName: adminName,
        adminRole: adminRole,
        applicationId: application['id'],
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approved — referral code: $code'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reject(BuildContext context, Map<String, dynamic> application) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Rejection reason', border: OutlineInputBorder()),
          maxLines: 2,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await AdminService().rejectApplication(
        adminId: adminId,
        adminName: adminName,
        adminRole: adminRole,
        applicationId: application['id'],
        reason: reason,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService().getInfluencerApplications(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
            }
            final applications = snapshot.data ?? [];
            if (applications.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No applications found')));
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Followers')),
                  DataColumn(label: Text('Niche')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Socials')),
                  DataColumn(label: Text('Applied')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: applications.map((a) {
                  final status = a['status'] ?? 'pending';
                  final socials = [
                    if ((a['tiktok_url'] ?? '').toString().isNotEmpty) 'TikTok',
                    if ((a['instagram_url'] ?? '').toString().isNotEmpty) 'Instagram',
                    if ((a['youtube_url'] ?? '').toString().isNotEmpty) 'YouTube',
                  ].join(' · ');
                  return DataRow(
                    cells: [
                      DataCell(Text(a['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text('${a['followers_count'] ?? 0}')),
                      DataCell(Text(a['content_niche'] ?? '')),
                      DataCell(Text(a['audience_location'] ?? '')),
                      DataCell(Text(socials, style: const TextStyle(fontSize: 12))),
                      DataCell(Text(
                        DateFormat('dd MMM yyyy').format(DateTime.tryParse(a['created_at'] ?? '') ?? DateTime.now()),
                        style: const TextStyle(fontSize: 12),
                      )),
                      DataCell(_StatusChip(status: status)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status == 'pending')
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              tooltip: 'Approve',
                              onPressed: () => _approve(context, a),
                            ),
                          if (status == 'pending')
                            IconButton(
                              icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                              tooltip: 'Reject',
                              onPressed: () => _reject(context, a),
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
    );
  }
}

class _InfluencersTab extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const _InfluencersTab({required this.adminId, required this.adminName, required this.adminRole});

  Future<void> _setStatus(BuildContext context, Map<String, dynamic> influencer, String newStatus) async {
    final user = influencer['users'] as Map<String, dynamic>?;
    final name = user?['full_name'] ?? influencer['referral_code'] ?? '';
    final actionLabel = newStatus == 'suspended' ? 'Suspend' : 'Reactivate';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel Influencer'),
        content: Text('$actionLabel $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(actionLabel)),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminService().setInfluencerStatus(
        adminId: adminId,
        adminName: adminName,
        adminRole: adminRole,
        userId: influencer['user_id'],
        status: newStatus,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Influencer ${newStatus == 'suspended' ? 'suspended' : 'reactivated'}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 2,
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: AdminService().getInfluencers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
            }
            final influencers = snapshot.data ?? [];
            if (influencers.isEmpty) {
              return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No influencers yet')));
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Code')),
                  DataColumn(label: Text('Followers')),
                  DataColumn(label: Text('Conversions')),
                  DataColumn(label: Text('Earnings')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: influencers.map((i) {
                  final user = i['users'] as Map<String, dynamic>?;
                  final status = i['status'] ?? 'pending';
                  return DataRow(
                    cells: [
                      DataCell(Text(user?['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                      DataCell(Text(i['referral_code'] ?? '', style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
                      DataCell(Text('${i['followers_count'] ?? 0}')),
                      DataCell(Text('${i['total_conversions'] ?? 0}')),
                      DataCell(Text(
                        Helpers.formatPrice((i['total_earnings'] as num?)?.toDouble() ?? 0.0),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      )),
                      DataCell(_StatusChip(status: status)),
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: Colors.blue, size: 18),
                            tooltip: 'View',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InfluencerDetailAdminScreen(
                                    adminId: adminId,
                                    adminName: adminName,
                                    adminRole: adminRole,
                                    influencerId: i['user_id'],
                                  ),
                                ),
                              );
                            },
                          ),
                          if (status == 'active')
                            IconButton(
                              icon: const Icon(Icons.block, color: Colors.red, size: 18),
                              tooltip: 'Suspend',
                              onPressed: () => _setStatus(context, i, 'suspended'),
                            ),
                          if (status == 'suspended')
                            IconButton(
                              icon: const Icon(Icons.play_circle, color: Colors.green, size: 18),
                              tooltip: 'Reactivate',
                              onPressed: () => _setStatus(context, i, 'active'),
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
      'active' || 'approved' => Colors.green,
      'suspended' || 'rejected' => Colors.red,
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
