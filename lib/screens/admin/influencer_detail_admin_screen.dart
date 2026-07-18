import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class InfluencerDetailAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;
  final String influencerId;

  const InfluencerDetailAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
    required this.influencerId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Influencer Detail'),
        backgroundColor: AppTheme.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: AdminService().getInfluencerDetail(influencerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final influencer = snapshot.data!;
          final user = influencer['users'] as Map<String, dynamic>?;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?['full_name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            'Code: ${influencer['referral_code'] ?? ''}',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    _StatusChip(status: influencer['status'] ?? 'pending'),
                  ],
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(label: 'Clicks', value: '${influencer['total_clicks'] ?? 0}', color: Colors.blue),
                    _StatCard(label: 'Registrations', value: '${influencer['total_registrations'] ?? 0}', color: Colors.purple),
                    _StatCard(label: 'Conversions', value: '${influencer['total_conversions'] ?? 0}', color: AppTheme.primary),
                    _StatCard(
                      label: 'Total Earnings',
                      value: Helpers.formatPrice((influencer['total_earnings'] as num?)?.toDouble() ?? 0.0),
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const Divider(),
                        _InfoRow(label: 'Email', value: user?['email'] ?? ''),
                        _InfoRow(label: 'Phone', value: user?['phone'] ?? ''),
                        _InfoRow(label: 'Followers', value: '${influencer['followers_count'] ?? 0}'),
                        _InfoRow(label: 'Niche', value: influencer['content_niche'] ?? ''),
                        _InfoRow(label: 'Audience Location', value: influencer['audience_location'] ?? ''),
                        if ((influencer['tiktok_url'] ?? '').toString().isNotEmpty)
                          _InfoRow(label: 'TikTok', value: influencer['tiktok_url']),
                        if ((influencer['instagram_url'] ?? '').toString().isNotEmpty)
                          _InfoRow(label: 'Instagram', value: influencer['instagram_url']),
                        if ((influencer['youtube_url'] ?? '').toString().isNotEmpty)
                          _InfoRow(label: 'YouTube', value: influencer['youtube_url']),
                        _InfoRow(label: 'Joined', value: _fmtDate(influencer['created_at'])),
                        if (influencer['activated_at'] != null)
                          _InfoRow(label: 'Activated', value: _fmtDate(influencer['activated_at'])),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: AdminService().getReferralConversions(influencerId: influencerId),
                    builder: (context, convSnapshot) {
                      if (convSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                      }
                      final conversions = convSnapshot.data ?? [];
                      if (conversions.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No conversions yet')));
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Date')),
                          ],
                          rows: conversions.map((c) {
                            return DataRow(
                              cells: [
                                DataCell(Text(c['conversion_type'] ?? '')),
                                DataCell(Text(
                                  Helpers.formatPrice((c['commission_amount'] as num?)?.toDouble() ?? 0.0),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )),
                                DataCell(_StatusChip(status: c['status'] ?? 'pending')),
                                DataCell(Text(_fmtDate(c['created_at']), style: const TextStyle(fontSize: 12))),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 2,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: AdminService().getFraudLogs(influencerId: influencerId),
                    builder: (context, fraudSnapshot) {
                      if (fraudSnapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                      }
                      final logs = fraudSnapshot.data ?? [];
                      if (logs.isEmpty) {
                        return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No fraud flags')));
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Reason')),
                            DataColumn(label: Text('Severity')),
                            DataColumn(label: Text('Date')),
                          ],
                          rows: logs.map((f) {
                            return DataRow(
                              cells: [
                                DataCell(Text(f['reason'] ?? '')),
                                DataCell(_SeverityChip(severity: f['severity'] ?? 'low')),
                                DataCell(Text(_fmtDate(f['created_at']), style: const TextStyle(fontSize: 12))),
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
          );
        },
      ),
    );
  }

  String _fmtDate(dynamic iso) {
    return DateFormat('dd MMM yyyy').format(DateTime.tryParse(iso?.toString() ?? '') ?? DateTime.now());
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 140, child: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
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
      'pending' => Colors.orange,
      'active' || 'approved' || 'paid' => Colors.green,
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

class _SeverityChip extends StatelessWidget {
  final String severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final color = switch (severity) {
      'low' => Colors.blue,
      'medium' => Colors.orange,
      'high' => Colors.red,
      _ => Colors.grey,
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
