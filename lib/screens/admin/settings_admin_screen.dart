import 'package:flutter/material.dart';
import 'package:dalali/services/app_settings.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/utils/helpers.dart';

class SettingsAdminScreen extends StatefulWidget {
  const SettingsAdminScreen({super.key});

  @override
  State<SettingsAdminScreen> createState() => _SettingsAdminScreenState();
}

class _SettingsAdminScreenState extends State<SettingsAdminScreen> {
  final _agencyFeeController = TextEditingController(text: AppSettings.agencyFee.toStringAsFixed(0));
  final _agentShareController = TextEditingController(text: '0.60');
  final _platformShareController = TextEditingController(text: '0.40');
  final _settlementDelayController = TextEditingController(text: '48');
  final _minWithdrawalController = TextEditingController(text: '5000');
  bool _isSaving = false;

  @override
  void dispose() {
    _agencyFeeController.dispose();
    _agentShareController.dispose();
    _platformShareController.dispose();
    _settlementDelayController.dispose();
    _minWithdrawalController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await AdminService().updateSystemSettings({
        'agencyFee': double.parse(_agencyFeeController.text),
        'agentShare': double.parse(_agentShareController.text),
        'platformShare': double.parse(_platformShareController.text),
        'settlementDelayHours': int.parse(_settlementDelayController.text),
        'minWithdrawal': double.parse(_minWithdrawalController.text),
        'updatedAt': DateTime.now().toIso8601String(),
      }, adminId: 'admin', adminName: 'Admin', adminRole: AdminRole.superAdmin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
            const Text('System Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Configure platform-wide financial rules', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fee Structure', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    _buildField('Agency Fee (TZS)', _agencyFeeController, keyboardType: TextInputType.number),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField('Agent Share (0-1)', _agentShareController)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Platform Share (0-1)', _platformShareController)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Settlement Rules', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildField('Settlement Delay (hours)', _settlementDelayController, keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildField('Min Withdrawal (TZS)', _minWithdrawalController, keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text('Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.teal.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _PreviewRow(label: 'Agency Fee', value: Helpers.formatPrice(double.tryParse(_agencyFeeController.text) ?? AppSettings.agencyFee)),
                            _PreviewRow(label: 'Agent Gets (60%)', value: Helpers.formatPrice((double.tryParse(_agencyFeeController.text) ?? AppSettings.agencyFee) * (double.tryParse(_agentShareController.text) ?? 0.60))),
                            _PreviewRow(label: 'Platform Gets (40%)', value: Helpers.formatPrice((double.tryParse(_agencyFeeController.text) ?? AppSettings.agencyFee) * (double.tryParse(_platformShareController.text) ?? 0.40))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: _isSaving
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      keyboardType: keyboardType,
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  const _PreviewRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
