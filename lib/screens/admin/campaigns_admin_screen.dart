import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class CampaignsAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const CampaignsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  Future<void> _createCampaign(BuildContext context) async {
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _CampaignFormDialog(),
    );
    if (data == null) return;
    try {
      await AdminService().createCampaign(
        adminId: adminId,
        adminName: adminName,
        adminRole: adminRole,
        data: data,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Campaign created')),
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

  Future<void> _setStatus(BuildContext context, Map<String, dynamic> campaign, String status) async {
    try {
      await AdminService().setCampaignStatus(
        adminId: adminId,
        adminName: adminName,
        adminRole: adminRole,
        campaignId: campaign['id'],
        status: status,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Campaign $status')),
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

  void _showMatches(BuildContext context, Map<String, dynamic> campaign) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Matched Influencers — ${campaign['name'] ?? ''}'),
        content: SizedBox(
          width: 420,
          height: 320,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: AdminService().matchInfluencers(campaign['id']),
            builder: (ctx, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              final matches = snapshot.data ?? [];
              if (matches.isEmpty) {
                return const Center(child: Text('No active influencers match this campaign'));
              }
              return ListView.builder(
                itemCount: matches.length,
                itemBuilder: (ctx, index) {
                  final m = matches[index];
                  final score = (m['score'] as num?)?.toDouble() ?? 0.0;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.primary.withAlpha(13),
                      child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
                    ),
                    title: Text('${m['full_name'] ?? ''} (${m['referral_code'] ?? ''})', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(
                      '${m['content_niche'] ?? '-'} · ${m['followers_count'] ?? 0} followers · ${m['total_conversions'] ?? 0} conversions',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Text(
                      score.toStringAsFixed(1),
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryDark),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

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
              children: [
                const Expanded(
                  child: Text('Campaigns', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _createCampaign(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Campaign'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryDark, foregroundColor: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Promotional campaigns for the influencer program', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: AdminService().getCampaigns(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                  }
                  final campaigns = snapshot.data ?? [];
                  if (campaigns.isEmpty) {
                    return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No campaigns yet')));
                  }
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Dates')),
                        DataColumn(label: Text('Budget')),
                        DataColumn(label: Text('Target Audience')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: campaigns.map((c) {
                        final status = c['status'] ?? 'draft';
                        return DataRow(
                          cells: [
                            DataCell(Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text('${_fmtDate(c['start_date'])} – ${_fmtDate(c['end_date'])}', style: const TextStyle(fontSize: 12))),
                            DataCell(Text(Helpers.formatPrice((c['budget'] as num?)?.toDouble() ?? 0.0))),
                            DataCell(Text(c['target_audience'] ?? '')),
                            DataCell(_StatusChip(status: status)),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (status == 'draft' || status == 'paused')
                                  IconButton(
                                    icon: const Icon(Icons.play_arrow, color: Colors.green, size: 18),
                                    tooltip: 'Activate',
                                    onPressed: () => _setStatus(context, c, 'active'),
                                  ),
                                if (status == 'active')
                                  IconButton(
                                    icon: const Icon(Icons.pause, color: Colors.orange, size: 18),
                                    tooltip: 'Pause',
                                    onPressed: () => _setStatus(context, c, 'paused'),
                                  ),
                                if (status == 'active' || status == 'paused')
                                  IconButton(
                                    icon: const Icon(Icons.stop, color: Colors.red, size: 18),
                                    tooltip: 'End',
                                    onPressed: () => _setStatus(context, c, 'ended'),
                                  ),
                                if (status == 'active')
                                  IconButton(
                                    icon: const Icon(Icons.auto_awesome, color: Colors.purple, size: 18),
                                    tooltip: 'Match Influencers',
                                    onPressed: () => _showMatches(context, c),
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

  String _fmtDate(dynamic iso) {
    final parsed = DateTime.tryParse(iso?.toString() ?? '');
    if (parsed == null) return '—';
    return DateFormat('dd MMM yyyy').format(parsed);
  }
}

class _CampaignFormDialog extends StatefulWidget {
  const _CampaignFormDialog();

  @override
  State<_CampaignFormDialog> createState() => _CampaignFormDialogState();
}

class _CampaignFormDialogState extends State<_CampaignFormDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _budgetController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _budgetController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, {
      'name': name,
      'description': _descriptionController.text.trim(),
      'budget': double.tryParse(_budgetController.text.trim()) ?? 0,
      'target_audience': _targetController.text.trim(),
      if (_startDate != null) 'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
      if (_endDate != null) 'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Campaign'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name *', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _budgetController,
                decoration: const InputDecoration(labelText: 'Budget (TZS)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _targetController,
                decoration: const InputDecoration(labelText: 'Target audience', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_startDate == null ? 'Start date' : DateFormat('dd MMM yyyy').format(_startDate!)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(_endDate == null ? 'End date' : DateFormat('dd MMM yyyy').format(_endDate!)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'draft' => Colors.grey,
      'active' => Colors.green,
      'paused' => Colors.orange,
      'ended' => Colors.red,
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
