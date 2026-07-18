import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/payment_service.dart';

class CommissionsAdminScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const CommissionsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<CommissionsAdminScreen> createState() => _CommissionsAdminScreenState();
}

class _CommissionsAdminScreenState extends State<CommissionsAdminScreen> {
  final PaymentService _service = PaymentService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _commissions = [];

  @override
  void initState() {
    super.initState();
    _loadCommissions();
  }

  Future<void> _loadCommissions() async {
    try {
      // In future: call a service that returns aggregated commissions
      // For now we fetch transactions and derive commissions client-side (demo)
      final rows = await _service.getAllTransactions(limit: 200).first;
      setState(() {
        _commissions = rows.where((r) => r['type'] == 'agency_fee').toList();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commissions & Wallets')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agent Commissions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: _commissions.map((c) {
                          final agent = c['agent_id'] ?? '-';
                          final amount = ((c['amount'] as num?)?.toDouble() ?? 0.0);
                          return ListTile(
                            title: Text('Agent: $agent'),
                            subtitle: Text('Amount: ${amount.toStringAsFixed(0)} ${c['currency'] ?? 'TZS'}'),
                            trailing: FilledButton(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout not implemented')));
                              },
                              child: const Text('Payout'),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
