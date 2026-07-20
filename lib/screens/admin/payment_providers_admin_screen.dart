import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/payment_service.dart';
import 'dart:convert';
import 'package:dalali/models/payment_gateway_model.dart';

class PaymentProvidersAdminScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const PaymentProvidersAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<PaymentProvidersAdminScreen> createState() => _PaymentProvidersAdminScreenState();
}

class _PaymentProvidersAdminScreenState extends State<PaymentProvidersAdminScreen> {
  final PaymentService _service = PaymentService();
  bool _isLoading = true;
  List<PaymentGatewayModel> _providers = [];

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    try {
      final list = await _service.getGateways();
      setState(() {
        _providers = list;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load providers: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Providers'),
        actions: [
          FilledButton.icon(
            onPressed: _createProvider,
            icon: const Icon(Icons.add),
            label: const Text('New'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Connected Payment Providers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: _providers.map((p) {
                          return ListTile(
                            title: Text(p.providerName),
                            subtitle: Text('${p.environment.toUpperCase()} — ${p.enabled ? 'CONNECTED' : 'DISABLED'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.science),
                                  tooltip: 'Test Connection',
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test not implemented')));
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit),
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    _editProvider(p);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Disable',
                                  onPressed: () async {
                                    final messenger = ScaffoldMessenger.of(context);
                                    try {
                                      await _service.updateGateway(p.id, {'enabled': false});
                                      await _loadProviders();
                                      messenger.showSnackBar(const SnackBar(content: Text('Provider disabled')));
                                    } catch (e) {
                                      messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
                                  },
                                ),
                              ],
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

  void _createProvider() {
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final envCtrl = TextEditingController(text: 'production');
    final configCtrl = TextEditingController(text: '{}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Payment Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: idCtrl, decoration: const InputDecoration(labelText: 'ID')),
              const SizedBox(height: 8),
              TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Provider Name')),
              const SizedBox(height: 8),
              TextFormField(controller: envCtrl, decoration: const InputDecoration(labelText: 'Environment')),
              const SizedBox(height: 8),
              TextFormField(controller: configCtrl, decoration: const InputDecoration(labelText: 'Config (JSON)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                final id = idCtrl.text.trim();
                final name = nameCtrl.text.trim();
                dynamic cfg = {};
                try {
                  cfg = jsonDecode(configCtrl.text.trim());
                } catch (_) {
                  cfg = {};
                }
                await _service.createGateway({'id': id, 'provider_name': name, 'environment': envCtrl.text.trim(), 'config': cfg, 'enabled': false});
                await _loadProviders();
                messenger.showSnackBar(const SnackBar(content: Text('Provider created')));
                navigator.pop();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _editProvider(PaymentGatewayModel p) {
    final envCtrl = TextEditingController(text: p.environment);
    final configCtrl = TextEditingController(text: jsonEncode(p.config));

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit ${p.providerName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: envCtrl, decoration: const InputDecoration(labelText: 'Environment')),
              const SizedBox(height: 8),
              TextFormField(controller: configCtrl, decoration: const InputDecoration(labelText: 'Config (JSON)')),            
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                final cfgText = configCtrl.text.trim();
                dynamic cfg;
                try {
                  cfg = cfgText.isNotEmpty ? jsonDecode(cfgText) : {};
                } catch (_) {
                  cfg = {};
                }
                await _service.updateGateway(p.id, {'environment': envCtrl.text.trim(), 'config': cfg});
                await _loadProviders();
                messenger.showSnackBar(const SnackBar(content: Text('Provider updated')));
                navigator.pop();
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
