import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/providers/property_state.dart';
import 'package:dalali/providers/tenancy_state.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:dalali/screens/shared/property_detail_screen.dart';
import 'package:dalali/screens/landlord/edit_property_screen.dart';
import 'package:dalali/screens/shared/mark_rented_sheet.dart';
import 'package:dalali/screens/tenancy/tenancy_detail_screen.dart';
import 'package:dalali/screens/earnings/agency_fee_history_screen.dart';
import 'package:dalali/widgets/notification_bell.dart';
import 'package:provider/provider.dart';

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>().currentUser;
    final properties = context.watch<PropertyState>().landlordProperties;
    final totalViews = properties.fold<int>(0, (sum, p) => sum + p.viewCount);
    final totalInquiries = properties.fold<int>(0, (sum, p) => sum + p.inquiryCount);

    final managedTenancies = context
        .watch<TenancyState>()
        .tenancies
        .where((t) => t.agentId == user?.id)
        .toList();
    final activeDeals = managedTenancies.where((t) => t.isActive).toList();
    final upcomingExpiries = activeDeals.where((t) => t.isExpiringSoon).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agent Dashboard'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: const [NotificationBell(iconColor: Colors.white)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.purple,
                      child: Text(
                        user?.fullName.substring(0, 1) ?? 'A',
                        style: const TextStyle(fontSize: 24, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user?.fullName ?? 'Agent', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('VERIFIED AGENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(height: 4),
                          Text('License: ${user?.agentLicense ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _StatCard(
                  icon: Icons.home,
                  label: 'My Listings',
                  value: '${properties.length}',
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.visibility,
                  label: 'Total Views',
                  value: '$totalViews',
                  color: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _StatCard(
                  icon: Icons.message,
                  label: 'Inquiries',
                  value: '$totalInquiries',
                  color: Colors.orange,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  icon: Icons.monetization_on,
                  label: 'Est. Commission',
                  value: 'TZS 0',
                  color: Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.workspace_premium, color: Colors.amber),
                title: const Text('Premium Plan'),
                subtitle: Text(user?.subscriptionTier == 1 ? 'Active until 31 Dec 2024' : 'Basic Plan - Upgrade for more features'),
                trailing: user?.subscriptionTier == 1
                    ? const Chip(label: Text('Active'), backgroundColor: Colors.green, labelStyle: TextStyle(color: Colors.white))
                    : ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                        child: const Text('Upgrade'),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Managed Tenancies', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AgencyFeeHistoryScreen()),
                  ),
                  child: const Text('Commission History'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatCard(icon: Icons.handshake, label: 'Active Deals', value: '${activeDeals.length}', color: Colors.teal),
                const SizedBox(width: 12),
                _StatCard(icon: Icons.hourglass_bottom, label: 'Expiring ≤60d', value: '${upcomingExpiries.length}', color: Colors.deepOrange),
              ],
            ),
            if (activeDeals.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...activeDeals.map((t) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        t.isExpiringSoon ? Icons.warning_amber : Icons.home,
                        color: t.isExpiringSoon ? Colors.deepOrange : Colors.purple,
                      ),
                      title: Text(t.propertyTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        t.isExpiringSoon
                            ? 'Expires in ${t.daysUntilEnd} days'
                            : 'Tenant: ${t.tenantName}',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TenancyDetailScreen(tenancyId: t.id)),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 24),
            const Text('My Listings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (properties.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.home_work_outlined, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('No listings yet', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final p = properties[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => PropertyDetailScreen(property: p)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                p.images.first,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(p.location, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                  const SizedBox(height: 4),
                                  Text(Helpers.formatPrice(p.rentPrice), style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            Column(
                              children: [
                                _StatusChip(status: p.status),
                                const SizedBox(height: 8),
                                Text('${p.viewCount} views', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18, color: Colors.purple),
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => EditPropertyScreen(property: p)),
                                  ),
                                  tooltip: 'Edit',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                if (p.status == PropertyStatus.available)
                                  IconButton(
                                    icon: const Icon(Icons.handshake, size: 18, color: AppTheme.action),
                                    onPressed: () => MarkRentedSheet.show(context, p),
                                    tooltip: AppLocalizations.of(context)!.markAsRented,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PropertyStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case PropertyStatus.available:
        color = Colors.green;
        label = 'Available';
        break;
      case PropertyStatus.occupied:
        color = Colors.red;
        label = 'Occupied';
        break;
      case PropertyStatus.pending:
        color = Colors.orange;
        label = 'Pending';
        break;
      case PropertyStatus.unlisted:
        color = Colors.grey;
        label = 'Unlisted';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
