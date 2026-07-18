import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/screens/admin/payment_providers_admin_screen.dart';

class SystemControlPanelAdminScreen extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const SystemControlPanelAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<SystemControlPanelAdminScreen> createState() => _SystemControlPanelAdminScreenState();
}

class _SystemControlPanelAdminScreenState extends State<SystemControlPanelAdminScreen> {
  final AdminService _adminService = AdminService();
  bool _isLoading = true;
  bool _isSaving = false;
  final Map<String, dynamic> _settings = {};

  final _appNameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _maintenanceMessageController = TextEditingController();
  final _minimumAppVersionController = TextEditingController();
  final _termsUrlController = TextEditingController();
  final _privacyUrlController = TextEditingController();
  final _serviceAreasController = TextEditingController();
  final _paymentProvidersController = TextEditingController();
  final _searchRadiusController = TextEditingController();
  final _defaultCurrencyController = TextEditingController();

  String _defaultLanguage = 'en';
  bool _maintenanceMode = false;
  bool _allowNewRegistrations = true;
  bool _enableSelcom = true;
  bool _enableAirtelMoney = true;
  bool _enableVodacom = true;
  bool _enableTigoPesa = true;
  bool _enableAiPhotoEnhancement = true;
  bool _enableAiDescription = true;
  bool _enableAiFraudDetection = true;
  bool _enableAiPricePrediction = true;
  bool _enableAiChatAssistant = true;
  bool _enablePropertyReels = false;
  bool _enableAiAssistant = false;
  bool _enableGuestHouses = false;
  bool _enableLandSales = false;
  bool _enableDeliveryServices = false;
  bool _enableWalletSystem = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final data = await _adminService.getSystemSettings();
      if (data != null) {
        _settings.addAll(data);
        _appNameController.text = (data['app_name'] ?? 'Dalali App').toString();
        _logoUrlController.text = (data['app_logo_url'] ?? '').toString();
        _serviceAreasController.text = (data['service_areas'] ?? '').toString();
        _minimumAppVersionController.text = (data['minimum_app_version'] ?? '1.0.0').toString();
        _termsUrlController.text = (data['terms_url'] ?? '').toString();
        _privacyUrlController.text = (data['privacy_url'] ?? '').toString();
        _defaultCurrencyController.text = (data['currency'] ?? 'TZS').toString();
        _maintenanceMode = (data['maintenance_mode'] as bool?) ?? false;
        _allowNewRegistrations = (data['allow_new_registrations'] as bool?) ?? true;
        _defaultLanguage = (data['default_language'] as String?) ?? 'en';
        _enableSelcom = (data['payment_selcom'] as bool?) ?? true;
        _enableAirtelMoney = (data['payment_airtel_money'] as bool?) ?? true;
        _enableVodacom = (data['payment_vodacom'] as bool?) ?? true;
        _enableTigoPesa = (data['payment_tigo_pesa'] as bool?) ?? true;
        _enableAiPhotoEnhancement = (data['feature_ai_photo_enhancement'] as bool?) ?? true;
        _enableAiDescription = (data['feature_ai_property_description'] as bool?) ?? true;
        _enableAiFraudDetection = (data['feature_ai_fraud_detection'] as bool?) ?? true;
        _enableAiPricePrediction = (data['feature_ai_price_prediction'] as bool?) ?? true;
        _enableAiChatAssistant = (data['feature_ai_chat_assistant'] as bool?) ?? true;
        _enablePropertyReels = (data['feature_property_reels'] as bool?) ?? false;
        _enableAiAssistant = (data['feature_ai_assistant'] as bool?) ?? false;
        _enableGuestHouses = (data['feature_guest_houses'] as bool?) ?? false;
        _enableLandSales = (data['feature_land_sales'] as bool?) ?? false;
        _enableDeliveryServices = (data['feature_delivery_services'] as bool?) ?? false;
        _enableWalletSystem = (data['feature_wallet_system'] as bool?) ?? false;
        _searchRadiusController.text = (data['search_radius_meters']?.toString() ?? '5000');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load control panel settings: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      await _adminService.updateSystemSettings(
        adminId: widget.adminId,
        adminName: widget.adminName,
        adminRole: widget.adminRole,
        settings: {
          'app_name': _appNameController.text.trim(),
          'app_logo_url': _logoUrlController.text.trim(),
          'default_language': _defaultLanguage,
          'currency': _defaultCurrencyController.text.trim(),
          'service_areas': _serviceAreasController.text.trim(),
          'maintenance_mode': _maintenanceMode,
          'allow_new_registrations': _allowNewRegistrations,
          'minimum_app_version': _minimumAppVersionController.text.trim(),
          'terms_url': _termsUrlController.text.trim(),
          'privacy_url': _privacyUrlController.text.trim(),
          'payment_selcom': _enableSelcom,
          'payment_airtel_money': _enableAirtelMoney,
          'payment_vodacom': _enableVodacom,
          'payment_tigo_pesa': _enableTigoPesa,
          'feature_ai_photo_enhancement': _enableAiPhotoEnhancement,
          'feature_ai_property_description': _enableAiDescription,
          'feature_ai_fraud_detection': _enableAiFraudDetection,
          'feature_ai_price_prediction': _enableAiPricePrediction,
          'feature_ai_chat_assistant': _enableAiChatAssistant,
          'feature_property_reels': _enablePropertyReels,
          'feature_ai_assistant': _enableAiAssistant,
          'feature_guest_houses': _enableGuestHouses,
          'feature_land_sales': _enableLandSales,
          'feature_delivery_services': _enableDeliveryServices,
          'feature_wallet_system': _enableWalletSystem,
          'search_radius_meters': int.tryParse(_searchRadiusController.text) ?? 5000,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('System control settings saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
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
                  const Text('System Control Panel', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Central command center for platform behaviour, security, listings, payments and AI.', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildStatusCard('Users Online', '1,245', Icons.people, Colors.blue),
                      _buildStatusCard('Active Listings', '35,600', Icons.home_work, Colors.teal),
                      _buildStatusCard('API Status', 'Supabase ✓ Storage ✓ Payments ✓ Notifications ✓', Icons.cloud_done, Colors.green),
                      _buildStatusCard('Server Load', '23%', Icons.monitor_heart, Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Platform Settings'),
                  const SizedBox(height: 12),
                  _buildPlatformSettingsCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('AI Control Center'),
                  const SizedBox(height: 12),
                  _buildAiControlCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Payment Gateway Control'),
                  const SizedBox(height: 12),
                  _buildPaymentGatewayCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Feature Flags'),
                  const SizedBox(height: 12),
                  _buildFeatureFlagsCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Location & Map Control'),
                  const SizedBox(height: 12),
                  _buildLocationControlCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Platform Behavior'),
                  const SizedBox(height: 12),
                  _buildPlatformBehaviorCard(),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save),
                        label: Text(_isSaving ? 'Saving...' : 'Save Control Panel'),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: _loadSettings,
                        child: const Text('Reload Saved Settings'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));
  }

  Widget _buildStatusCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 240,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Icon(icon, color: color),
                ],
              ),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlatformSettingsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('App Name', _appNameController),
            const SizedBox(height: 16),
            _buildTextField('Logo / Watermark URL', _logoUrlController),
            const SizedBox(height: 16),
            _buildTextField('Default Currency', _defaultCurrencyController),
            const SizedBox(height: 16),
            _buildTextField('Service Areas (comma separated)', _serviceAreasController),
            const SizedBox(height: 16),
            _buildDropdownField(
              'Default Language',
              ['en', 'sw'],
              _defaultLanguage,
              (value) => setState(() => _defaultLanguage = value),
            ),
            const SizedBox(height: 16),
            _buildTextField('Minimum App Version', _minimumAppVersionController),
            const SizedBox(height: 16),
            _buildTextField('Terms URL', _termsUrlController),
            const SizedBox(height: 16),
            _buildTextField('Privacy URL', _privacyUrlController),
            const SizedBox(height: 16),
            _buildSwitchTile('Maintenance Mode', _maintenanceMode, (value) => setState(() => _maintenanceMode = value)),
            _buildSwitchTile('Allow New Registrations', _allowNewRegistrations, (value) => setState(() => _allowNewRegistrations = value)),
          ],
        ),
      ),
    );
  }

  Widget _buildAiControlCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI Control Center', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSwitchTile('AI Photo Enhancement', _enableAiPhotoEnhancement, (value) => setState(() => _enableAiPhotoEnhancement = value)),
            _buildSwitchTile('AI Property Description', _enableAiDescription, (value) => setState(() => _enableAiDescription = value)),
            _buildSwitchTile('AI Fraud Detection', _enableAiFraudDetection, (value) => setState(() => _enableAiFraudDetection = value)),
            _buildSwitchTile('AI Price Prediction', _enableAiPricePrediction, (value) => setState(() => _enableAiPricePrediction = value)),
            _buildSwitchTile('AI Chat Assistant', _enableAiChatAssistant, (value) => setState(() => _enableAiChatAssistant = value)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentGatewayCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Gateway Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSwitchTile('Selcom', _enableSelcom, (value) => setState(() => _enableSelcom = value)),
            _buildSwitchTile('Airtel Money', _enableAirtelMoney, (value) => setState(() => _enableAirtelMoney = value)),
            _buildSwitchTile('Vodacom', _enableVodacom, (value) => setState(() => _enableVodacom = value)),
            _buildSwitchTile('Tigo Pesa', _enableTigoPesa, (value) => setState(() => _enableTigoPesa = value)),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => PaymentProvidersAdminScreen(
                  adminId: widget.adminId,
                  adminName: widget.adminName,
                  adminRole: widget.adminRole,
                )));
              },
              icon: const Icon(Icons.manage_accounts),
              label: const Text('Manage Providers'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureFlagsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Feature Flags', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildSwitchTile('Property Reels', _enablePropertyReels, (value) => setState(() => _enablePropertyReels = value)),
            _buildSwitchTile('AI Assistant', _enableAiAssistant, (value) => setState(() => _enableAiAssistant = value)),
            _buildSwitchTile('Guest Houses', _enableGuestHouses, (value) => setState(() => _enableGuestHouses = value)),
            _buildSwitchTile('Land Sales', _enableLandSales, (value) => setState(() => _enableLandSales = value)),
            _buildSwitchTile('Delivery Services', _enableDeliveryServices, (value) => setState(() => _enableDeliveryServices = value)),
            _buildSwitchTile('Wallet System', _enableWalletSystem, (value) => setState(() => _enableWalletSystem = value)),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationControlCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Location & Map Control', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField('Search Radius (meters)', _searchRadiusController, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            const Text('Control OpenStreetMap service areas and search radius.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformBehaviorCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Platform Behaviour', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Use this panel to control registrations, version enforcement, and platform governance.', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> options, String value, ValueChanged<String> onChanged) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: options.map((option) => DropdownMenuItem(value: option, child: Text(option.toUpperCase()))).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _logoUrlController.dispose();
    _maintenanceMessageController.dispose();
    _minimumAppVersionController.dispose();
    _termsUrlController.dispose();
    _privacyUrlController.dispose();
    _serviceAreasController.dispose();
    _paymentProvidersController.dispose();
    _searchRadiusController.dispose();
    _defaultCurrencyController.dispose();
    super.dispose();
  }
}
