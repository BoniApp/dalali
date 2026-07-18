import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:intl/intl.dart';

class InfluencerReportsAdminScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const InfluencerReportsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<InfluencerReportsAdminScreen> createState() => _InfluencerReportsAdminScreenState();
}

class _InfluencerReportsAdminScreenState extends State<InfluencerReportsAdminScreen> {
  late Future<List<Map<String, dynamic>>> _entriesFuture;
  late Future<Map<String, dynamic>?> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _entriesFuture = AdminService().getCommissionEntries();
    _settingsFuture = AdminService().getSystemSettings();
  }

  Future<void> _editRates(Map<String, dynamic> settings) async {
    final rates = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _RatesEditDialog(settings: settings),
    );
    if (rates == null) return;
    try {
      await AdminService().setInfluencerRates(
        adminId: widget.adminId,
        adminName: widget.adminName,
        adminRole: widget.adminRole,
        agencyFeePct: rates['agencyFeePct'] as double?,
        premiumPct: rates['premiumPct'] as double?,
        registrationBonus: rates['registrationBonus'] as double?,
        programEnabled: rates['programEnabled'] as bool?,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Influencer rates updated')),
        );
        setState(_reload);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            const Text('Influencer Reports', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Referral commissions and program rates', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            FutureBuilder<Map<String, dynamic>?>(
              future: _settingsFuture,
              builder: (context, snapshot) {
                final settings = snapshot.data;
                return Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Program Rates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (settings == null)
                                const Text('Loading...', style: TextStyle(fontSize: 13, color: Colors.grey))
                              else
                                Text(
                                  'Agency fee: ${_pct(settings['influencer_agency_fee_pct'])}  ·  '
                                  'Premium: ${_pct(settings['influencer_premium_pct'])}  ·  '
                                  'Registration bonus: ${Helpers.formatPrice((settings['influencer_registration_bonus'] as num?)?.toDouble() ?? 0.0)}  ·  '
                                  'Program: ${(settings['influencer_program_enabled'] == true) ? 'Enabled' : 'Disabled'}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        if (settings != null)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Edit Rates',
                            onPressed: () => _editRates(settings),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _entriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
                }
                final entries = snapshot.data ?? [];
                double sumFor(String status) => entries
                    .where((e) => e['status'] == status)
                    .fold(0.0, (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0.0));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SummaryCard(label: 'Pending', value: Helpers.formatPrice(sumFor('pending')), color: Colors.orange),
                        _SummaryCard(label: 'Available', value: Helpers.formatPrice(sumFor('available')), color: Colors.green),
                        _SummaryCard(label: 'Withdrawn', value: Helpers.formatPrice(sumFor('withdrawn')), color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 2,
                      child: entries.isEmpty
                          ? const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No commission entries yet')))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(label: Text('Influencer')),
                                  DataColumn(label: Text('Amount')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Date')),
                                ],
                                rows: entries.map((e) {
                                  final user = e['users'] as Map<String, dynamic>?;
                                  final name = (user?['full_name'] ?? '').toString().isNotEmpty
                                      ? user!['full_name']
                                      : e['user_id']?.toString().substring(0, 8) ?? '';
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                      DataCell(Text(
                                        Helpers.formatPrice((e['amount'] as num?)?.toDouble() ?? 0.0),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      )),
                                      DataCell(_StatusChip(status: e['status'] ?? 'pending')),
                                      DataCell(Text(
                                        DateFormat('dd MMM yyyy').format(DateTime.tryParse(e['created_at'] ?? '') ?? DateTime.now()),
                                        style: const TextStyle(fontSize: 12),
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _pct(dynamic v) {
    final pct = ((v as num?)?.toDouble() ?? 0.0) * 100;
    return '${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)}%';
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              const SizedBox(height: 4),
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatesEditDialog extends StatefulWidget {
  final Map<String, dynamic> settings;

  const _RatesEditDialog({required this.settings});

  @override
  State<_RatesEditDialog> createState() => _RatesEditDialogState();
}

class _RatesEditDialogState extends State<_RatesEditDialog> {
  late final TextEditingController _agencyFeeController;
  late final TextEditingController _premiumController;
  late final TextEditingController _bonusController;
  late bool _programEnabled;

  @override
  void initState() {
    super.initState();
    _agencyFeeController = TextEditingController(text: '${widget.settings['influencer_agency_fee_pct'] ?? 0.10}');
    _premiumController = TextEditingController(text: '${widget.settings['influencer_premium_pct'] ?? 0.20}');
    _bonusController = TextEditingController(text: '${widget.settings['influencer_registration_bonus'] ?? 0}');
    _programEnabled = widget.settings['influencer_program_enabled'] == true;
  }

  @override
  void dispose() {
    _agencyFeeController.dispose();
    _premiumController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.pop(context, {
      'agencyFeePct': double.tryParse(_agencyFeeController.text.trim()),
      'premiumPct': double.tryParse(_premiumController.text.trim()),
      'registrationBonus': double.tryParse(_bonusController.text.trim()),
      'programEnabled': _programEnabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Influencer Rates'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _agencyFeeController,
              decoration: const InputDecoration(
                labelText: 'Agency fee commission',
                helperText: 'Fraction, e.g. 0.10 = 10%',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _premiumController,
              decoration: const InputDecoration(
                labelText: 'Premium commission',
                helperText: 'Fraction, e.g. 0.20 = 20%',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bonusController,
              decoration: const InputDecoration(
                labelText: 'Registration bonus (TZS)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Program enabled'),
              value: _programEnabled,
              onChanged: (v) => setState(() => _programEnabled = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
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
      'pending' => Colors.orange,
      'available' => Colors.green,
      'withdrawn' => Colors.blue,
      'cancelled' => Colors.red,
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
