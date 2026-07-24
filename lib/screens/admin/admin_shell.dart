import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/screens/admin/dashboard_admin_screen.dart';
import 'package:dalali/screens/admin/wallets_admin_screen.dart';
import 'package:dalali/screens/admin/transactions_admin_screen.dart';
import 'package:dalali/screens/admin/dpo_payments_admin_screen.dart';
import 'package:dalali/screens/admin/listings_admin_screen.dart';
import 'package:dalali/screens/admin/users_admin_screen.dart';
import 'package:dalali/screens/admin/withdrawals_admin_screen.dart';
import 'package:dalali/screens/admin/fraud_admin_screen.dart';
import 'package:dalali/screens/admin/analytics_admin_screen.dart';
import 'package:dalali/screens/admin/settings_admin_screen.dart';
import 'package:dalali/screens/admin/system_control_panel_admin_screen.dart';
import 'package:dalali/screens/admin/commissions_admin_screen.dart';
import 'package:dalali/screens/admin/disputes_admin_screen.dart';
import 'package:dalali/screens/admin/property_registry_admin_screen.dart';
import 'package:dalali/screens/admin/property_claims_admin_screen.dart';
import 'package:dalali/screens/admin/agency_fees_admin_screen.dart';
import 'package:dalali/screens/admin/influencers_admin_screen.dart';
import 'package:dalali/screens/admin/campaigns_admin_screen.dart';
import 'package:dalali/screens/admin/influencer_reports_admin_screen.dart';
import 'package:dalali/screens/admin/broadcast_admin_screen.dart';
import 'package:dalali/screens/admin/login_admin_screen.dart';
import 'package:dalali/screens/shared/conversations_screen.dart';
import 'package:dalali/services/supabase_service.dart';

class AdminShell extends StatefulWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const AdminShell({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _selectedIndex = 0;

  List<_NavItem> get _allItems => [
    _NavItem(icon: Icons.dashboard, label: 'Dashboard', screenBuilder: () => const DashboardAdminScreen()),
    _NavItem(icon: Icons.admin_panel_settings, label: 'System Control', screenBuilder: () => SystemControlPanelAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.account_balance_wallet, label: 'Wallets', screenBuilder: () => const WalletsAdminScreen()),
    _NavItem(icon: Icons.payment, label: 'Payments', screenBuilder: () => DpoPaymentsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.monetization_on, label: 'Commissions', screenBuilder: () => CommissionsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.receipt_long, label: 'Transactions', screenBuilder: () => const TransactionsAdminScreen()),
    _NavItem(icon: Icons.home_work, label: 'Listings', screenBuilder: () => ListingsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.people, label: 'Users', screenBuilder: () => UsersAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.account_balance, label: 'Withdrawals', screenBuilder: () => WithdrawalsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.warning_amber, label: 'Fraud Alerts', screenBuilder: () => FraudAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.gavel, label: 'Disputes', screenBuilder: () => DisputesAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.analytics, label: 'Analytics', screenBuilder: () => const AnalyticsAdminScreen()),
    _NavItem(icon: Icons.settings, label: 'Settings', screenBuilder: () => SettingsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.app_registration, label: 'Registry', screenBuilder: () => PropertyRegistryAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.gavel, label: 'Claims', screenBuilder: () => PropertyClaimsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.paid, label: 'Agency Fees', screenBuilder: () => AgencyFeesAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.campaign, label: 'Influencers', screenBuilder: () => InfluencersAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.rocket_launch, label: 'Campaigns', screenBuilder: () => CampaignsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.insights, label: 'Influencer Reports', screenBuilder: () => InfluencerReportsAdminScreen(
      adminId: widget.adminId,
      adminName: widget.adminName,
      adminRole: widget.adminRole,
    )),
    _NavItem(icon: Icons.campaign_outlined, label: 'Broadcast', screenBuilder: () => BroadcastAdminScreen(
      adminId: widget.adminId,
    )),
    _NavItem(icon: Icons.chat_bubble_outline, label: 'Messages', screenBuilder: () => ConversationsScreen(
      userId: widget.adminId,
    )),
  ];

  List<_NavItem> get _visibleItems {
    return _allItems.where((item) {
      switch (item.label) {
        case 'Wallets':
          return AdminPermissions.canManageWallets(widget.adminRole);
        case 'Transactions':
          return AdminPermissions.canManageTransactions(widget.adminRole);
        case 'Listings':
          return AdminPermissions.canManageListings(widget.adminRole);
        case 'Users':
          return AdminPermissions.canManageUsers(widget.adminRole);
        case 'Withdrawals':
          return AdminPermissions.canManageWithdrawals(widget.adminRole);
        case 'Fraud Alerts':
          return AdminPermissions.canViewFraud(widget.adminRole);
        case 'Disputes':
          return AdminPermissions.canManageDisputes(widget.adminRole);
        case 'Analytics':
          return AdminPermissions.canViewAnalytics(widget.adminRole);
        case 'Settings':
          return AdminPermissions.canManageSettings(widget.adminRole);
        case 'Registry':
          return AdminPermissions.canManageListings(widget.adminRole);
        case 'Claims':
          return AdminPermissions.canManageDisputes(widget.adminRole);
        case 'Agency Fees':
          return AdminPermissions.canManageWallets(widget.adminRole);
        case 'Influencers':
        case 'Campaigns':
        case 'Influencer Reports':
          return AdminPermissions.canManageInfluencers(widget.adminRole);
        case 'Broadcast':
          return AdminPermissions.canBroadcast(widget.adminRole);
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _logout() async {
    await SupabaseService.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginAdminScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _visibleItems;
    final screen = items[_selectedIndex.clamp(0, items.length - 1)].screenBuilder();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;

        return Scaffold(
          appBar: isDesktop
              ? null
              : AppBar(
                  title: Text(items[_selectedIndex.clamp(0, items.length - 1)].label),
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Row(
                        children: [
                          Chip(
                            label: Text(widget.adminRole.name, style: const TextStyle(fontSize: 11)),
                            backgroundColor: Colors.amber,
                            labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: _logout,
                            tooltip: 'Logout',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          drawer: isDesktop ? null : _buildDrawer(items),
          body: Row(
            children: [
              if (isDesktop) _buildSidebar(items),
              Expanded(child: screen),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(List<_NavItem> items) {
    return Container(
      width: 260,
      color: AppTheme.primaryDark,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: AppTheme.primary.withAlpha(51), size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Dalali Admin',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(widget.adminName, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Chip(
                  label: Text(widget.adminRole.name, style: const TextStyle(fontSize: 10)),
                  backgroundColor: Colors.amber.shade700,
                  labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final selected = index == _selectedIndex;
                return ListTile(
                  leading: Icon(items[index].icon, color: selected ? Colors.white : Colors.white60),
                  title: Text(
                    items[index].label,
                    style: TextStyle(color: selected ? Colors.white : Colors.white70, fontSize: 14),
                  ),
                  selected: selected,
                  selectedTileColor: AppTheme.primaryDark,
                  onTap: () => setState(() => _selectedIndex = index),
                );
              },
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.white60),
            title: const Text('Logout', style: TextStyle(color: Colors.white70, fontSize: 14)),
            onTap: _logout,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildDrawer(List<_NavItem> items) {
    return Drawer(
      child: Container(
        color: AppTheme.primaryDark,
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppTheme.primaryDark),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: AppTheme.primary.withAlpha(51), size: 28),
                      const SizedBox(width: 12),
                      const Text('Dalali Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(widget.adminName, style: const TextStyle(color: Colors.white70)),
                  Chip(
                    label: Text(widget.adminRole.name, style: const TextStyle(fontSize: 10)),
                    backgroundColor: Colors.amber.shade700,
                    labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final selected = index == _selectedIndex;
                  return ListTile(
                    leading: Icon(items[index].icon, color: selected ? Colors.white : Colors.white60),
                    title: Text(items[index].label, style: TextStyle(color: selected ? Colors.white : Colors.white70)),
                    selected: selected,
                    selectedTileColor: AppTheme.primaryDark,
                    onTap: () {
                      setState(() => _selectedIndex = index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.white60),
              title: const Text('Logout', style: TextStyle(color: Colors.white70)),
              onTap: _logout,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget Function() screenBuilder;

  _NavItem({required this.icon, required this.label, required this.screenBuilder});
}
