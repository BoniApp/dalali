import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/tenancy/tenancy_detail_screen.dart';
import 'package:provider/provider.dart';

class MyTenanciesScreen extends StatelessWidget {
  const MyTenanciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isLandlord = appState.currentUser?.role == UserRole.landlord ||
        appState.currentUser?.role == UserRole.agent;
    final tenancies = isLandlord ? appState.landlordTenancies : appState.myTenancies;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLandlord ? 'Active Tenancies' : 'My Tenancies'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: tenancies.isEmpty
          ? _EmptyState(isLandlord: isLandlord)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tenancies.length,
              itemBuilder: (context, index) => _TenancyCard(tenancy: tenancies[index]),
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isLandlord;
  const _EmptyState({required this.isLandlord});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.home_work, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isLandlord ? 'No active tenancies yet.' : 'You have no active tenancies.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            isLandlord
                ? 'Approved reservations will appear here.'
                : 'Apply for a property to start your tenancy journey.',
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _TenancyCard extends StatelessWidget {
  final TenancyModel tenancy;
  const _TenancyCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (tenancy.status) {
      TenancyStatus.upcoming => Colors.orange,
      TenancyStatus.active => Colors.green,
      TenancyStatus.completed => Colors.blue,
      TenancyStatus.terminated => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TenancyDetailScreen(tenancyId: tenancy.id)),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tenancy.propertyTitle,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Chip(
                    label: Text(
                      tenancy.status.name[0].toUpperCase() + tenancy.status.name.substring(1),
                      style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: statusColor.withAlpha(26),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(tenancy.propertyLocation, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InfoChip(icon: Icons.calendar_today, label: 'Move-in', value: _formatDate(tenancy.moveInDate)),
                  const SizedBox(width: 16),
                  _InfoChip(icon: Icons.payments, label: 'Rent', value: 'TZS ${tenancy.rentAmount.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 8),
              if (tenancy.isUpcoming)
                LinearProgressIndicator(
                  value: 0.3,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  borderRadius: BorderRadius.circular(4),
                ),
              if (tenancy.isActive)
                LinearProgressIndicator(
                  value: _tenancyProgress(tenancy),
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  borderRadius: BorderRadius.circular(4),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  double _tenancyProgress(TenancyModel t) {
    final total = t.expectedMoveOutDate.difference(t.moveInDate).inDays;
    final elapsed = DateTime.now().difference(t.moveInDate).inDays;
    if (total <= 0) return 1;
    return (elapsed / total).clamp(0.0, 1.0);
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[500]),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
