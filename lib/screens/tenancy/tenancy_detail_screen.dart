import 'package:flutter/material.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/tenancy/move_checklist_screen.dart';
import 'package:provider/provider.dart';

class TenancyDetailScreen extends StatelessWidget {
  final String tenancyId;
  const TenancyDetailScreen({super.key, required this.tenancyId});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tenancy = appState.tenancies.firstWhere((t) => t.id == tenancyId);
    final isLandlord = appState.currentUser?.id == tenancy.landlordId;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tenancy Details'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Details'),
              Tab(icon: Icon(Icons.checklist), text: 'Checklist'),
              Tab(icon: Icon(Icons.build), text: 'Maintenance'),
              Tab(icon: Icon(Icons.payments), text: 'Rent'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _DetailsTab(tenancy: tenancy, isLandlord: isLandlord, appState: appState),
            MoveChecklistScreen(tenancyId: tenancyId),
            _MaintenanceTab(tenancy: tenancy, appState: appState, isLandlord: isLandlord),
            _RentTab(tenancy: tenancy, appState: appState),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final TenancyModel tenancy;
  final bool isLandlord;
  final AppState appState;
  const _DetailsTab({required this.tenancy, required this.isLandlord, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatusCard(tenancy: tenancy),
        const SizedBox(height: 16),
        _DetailRow(icon: Icons.person, label: isLandlord ? 'Tenant' : 'Landlord', value: isLandlord ? tenancy.tenantName : tenancy.landlordName),
        _DetailRow(icon: Icons.location_on, label: 'Property', value: tenancy.propertyLocation),
        _DetailRow(icon: Icons.calendar_today, label: 'Move-in Date', value: _fmt(tenancy.moveInDate)),
        _DetailRow(icon: Icons.exit_to_app, label: 'Expected Move-out', value: _fmt(tenancy.expectedMoveOutDate)),
        _DetailRow(icon: Icons.payments, label: 'Monthly Rent', value: 'TZS ${tenancy.rentAmount.toStringAsFixed(0)}'),
        _DetailRow(icon: Icons.account_balance_wallet, label: 'Deposit', value: 'TZS ${tenancy.depositAmount.toStringAsFixed(0)}'),
        const SizedBox(height: 24),
        if (tenancy.isUpcoming && isLandlord)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => appState.activateTenancy(tenancy.id),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirm Move-in (Activate)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        if (tenancy.isActive)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => appState.completeTenancy(tenancy.id),
              icon: const Icon(Icons.done_all),
              label: const Text('Mark Tenancy Complete'),
            ),
          ),
      ],
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _StatusCard extends StatelessWidget {
  final TenancyModel tenancy;
  const _StatusCard({required this.tenancy});

  @override
  Widget build(BuildContext context) {
    final color = switch (tenancy.status) {
      TenancyStatus.upcoming => Colors.orange,
      TenancyStatus.active => Colors.green,
      TenancyStatus.completed => Colors.blue,
      TenancyStatus.terminated => Colors.red,
    };
    return Card(
      color: color.withAlpha(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.home, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tenancy.status.name[0].toUpperCase() + tenancy.status.name.substring(1),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                  ),
                  Text(tenancy.propertyTitle, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.teal),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaintenanceTab extends StatelessWidget {
  final TenancyModel tenancy;
  final AppState appState;
  final bool isLandlord;
  const _MaintenanceTab({required this.tenancy, required this.appState, required this.isLandlord});

  @override
  Widget build(BuildContext context) {
    final requests = appState.maintenanceRequests.where((r) => r.propertyId == tenancy.propertyId).toList();

    return Column(
      children: [
        Expanded(
          child: requests.isEmpty
              ? Center(child: Text('No maintenance requests.', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _MaintenanceCard(request: requests[i], isLandlord: isLandlord, appState: appState),
                ),
        ),
        if (!isLandlord)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSubmitDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Maintenance Request'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  void _showSubmitDialog(BuildContext context) {
    final categories = MaintenanceCategory.values;
    MaintenanceCategory selected = MaintenanceCategory.general;
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Submit Maintenance Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<MaintenanceCategory>(
                initialValue: selected,
                decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: categories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c.name[0].toUpperCase() + c.name.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => selected = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (descController.text.isNotEmpty) {
                  appState.addMaintenanceRequest(MaintenanceRequestModel(
                    id: 'mr${DateTime.now().millisecondsSinceEpoch}',
                    tenantId: appState.currentUser!.id,
                    tenantName: appState.currentUser!.fullName,
                    landlordId: tenancy.landlordId,
                    propertyId: tenancy.propertyId,
                    propertyTitle: tenancy.propertyTitle,
                    category: selected,
                    description: descController.text,
                    createdAt: DateTime.now(),
                  ));
                  Navigator.pop(context);
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final MaintenanceRequestModel request;
  final bool isLandlord;
  final AppState appState;
  const _MaintenanceCard({required this.request, required this.isLandlord, required this.appState});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (request.status) {
      MaintenanceStatus.open => Colors.orange,
      MaintenanceStatus.inProgress => Colors.blue,
      MaintenanceStatus.resolved => Colors.green,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  label: Text(request.category.name[0].toUpperCase() + request.category.name.substring(1)),
                  backgroundColor: Colors.teal.shade50,
                  visualDensity: VisualDensity.compact,
                ),
                const Spacer(),
                Chip(
                  label: Text(request.status.name[0].toUpperCase() + request.status.name.substring(1)),
                  backgroundColor: statusColor.withAlpha(26),
                  labelStyle: TextStyle(color: statusColor, fontSize: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(request.description, style: const TextStyle(fontSize: 14)),
            if (isLandlord && request.status != MaintenanceStatus.resolved) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (request.status == MaintenanceStatus.open)
                    TextButton(
                      onPressed: () => appState.updateMaintenanceStatus(request.id, MaintenanceStatus.inProgress),
                      child: const Text('Mark In Progress'),
                    ),
                  TextButton(
                    onPressed: () => appState.updateMaintenanceStatus(request.id, MaintenanceStatus.resolved),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RentTab extends StatelessWidget {
  final TenancyModel tenancy;
  final AppState appState;
  const _RentTab({required this.tenancy, required this.appState});

  @override
  Widget build(BuildContext context) {
    final schedules = appState.rentSchedules.where((r) => r.tenancyId == tenancy.id).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: schedules.length,
      itemBuilder: (_, i) {
        final s = schedules[i];
        final isOverdue = s.isOverdue;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: s.status == PaymentStatus.paid
                  ? Colors.green.shade100
                  : isOverdue
                      ? Colors.red.shade100
                      : Colors.orange.shade100,
              child: Icon(
                s.status == PaymentStatus.paid ? Icons.check : Icons.schedule,
                color: s.status == PaymentStatus.paid
                    ? Colors.green
                    : isOverdue
                        ? Colors.red
                        : Colors.orange,
              ),
            ),
            title: Text('TZS ${s.amount.toStringAsFixed(0)}'),
            subtitle: Text('Due: ${_fmt(s.dueDate)}${isOverdue ? ' (Overdue)' : ''}'),
            trailing: s.status == PaymentStatus.paid
                ? Chip(label: const Text('Paid'), backgroundColor: Colors.green.shade100, labelStyle: const TextStyle(color: Colors.green))
                : ElevatedButton(
                    onPressed: () => appState.markRentPaid(s.id),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                    child: const Text('Pay'),
                  ),
          ),
        );
      },
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
