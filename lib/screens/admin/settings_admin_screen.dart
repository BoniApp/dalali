import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';

class SettingsAdminScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const SettingsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<SettingsAdminScreen> createState() => _SettingsAdminScreenState();
}

class _SettingsAdminScreenState extends State<SettingsAdminScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, dynamic> _settings = {};

  final _commissionCtrl = TextEditingController();
  final _minWithdrawalCtrl = TextEditingController();
  final _maxWithdrawalCtrl = TextEditingController();
  final _dailyLimitCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await AdminService().getSystemSettings();
      setState(() {
        if (data != null) {
          _settings.addAll(data);
          _commissionCtrl.text = (data['commission_rate'] ?? '5').toString();
          _minWithdrawalCtrl.text = (data['min_withdrawal'] ?? '10000').toString();
          _maxWithdrawalCtrl.text = (data['max_withdrawal'] ?? '1000000').toString();
          _dailyLimitCtrl.text = (data['daily_withdrawal_limit'] ?? '500000').toString();
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load settings: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await AdminService().updateSystemSettings(
        adminId: widget.adminId,
        adminName: widget.adminName,
        adminRole: widget.adminRole,
        settings: {
          'commission_rate': double.tryParse(_commissionCtrl.text) ?? 5.0,
          'min_withdrawal': double.tryParse(_minWithdrawalCtrl.text) ?? 10000.0,
          'max_withdrawal': double.tryParse(_maxWithdrawalCtrl.text) ?? 1000000.0,
          'daily_withdrawal_limit': double.tryParse(_dailyLimitCtrl.text) ?? 500000.0,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Settings', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Configure platform-wide settings', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Financial Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          _buildTextField('Commission Rate (%)', _commissionCtrl),
                          const SizedBox(height: 16),
                          _buildTextField('Min Withdrawal (TZS)', _minWithdrawalCtrl),
                          const SizedBox(height: 16),
                          _buildTextField('Max Withdrawal (TZS)', _maxWithdrawalCtrl),
                          const SizedBox(height: 16),
                          _buildTextField('Daily Withdrawal Limit (TZS)', _dailyLimitCtrl),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: 200,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _save,
                              icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                              label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
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

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  @override
  void dispose() {
    _commissionCtrl.dispose();
    _minWithdrawalCtrl.dispose();
    _maxWithdrawalCtrl.dispose();
    _dailyLimitCtrl.dispose();
    super.dispose();
  }
}
