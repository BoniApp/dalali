import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/tenancy_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/maintenance_request_model.dart';
import 'package:dalali/models/rent_schedule_model.dart';
import 'package:dalali/models/inspection_model.dart';
import 'package:dalali/models/deposit_transaction_model.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/providers/tenancy_state.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/screens/tenancy/move_checklist_screen.dart';
import 'package:dalali/widgets/pay_agency_fee_button.dart';
import 'package:provider/provider.dart';

class TenancyDetailScreen extends StatelessWidget {
  final String tenancyId;
  const TenancyDetailScreen({super.key, required this.tenancyId});

  @override
  Widget build(BuildContext context) {
    final tenancyState = context.watch<TenancyState>();
    final currentUser = context.watch<UserState>().currentUser;
    final tenancy = tenancyState.tenancies.firstWhere((t) => t.id == tenancyId);
    final isLandlord = currentUser?.id == tenancy.landlordId;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tenancy Details'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.info), text: 'Details'),
              Tab(icon: Icon(Icons.checklist), text: 'Checklist'),
              Tab(icon: Icon(Icons.build), text: 'Maintenance'),
              Tab(icon: Icon(Icons.payments), text: 'Rent'),
              Tab(icon: Icon(Icons.moving), text: 'Move-Out'),
            ],
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
        body: TabBarView(
          children: [
            _DetailsTab(tenancy: tenancy, isLandlord: isLandlord, tenancyState: tenancyState),
            MoveChecklistScreen(tenancyId: tenancyId),
            _MaintenanceTab(
              tenancy: tenancy,
              tenancyState: tenancyState,
              isLandlord: isLandlord,
              currentUser: currentUser,
            ),
            _RentTab(tenancy: tenancy, tenancyState: tenancyState),
            _MoveOutTab(tenancy: tenancy, tenancyState: tenancyState, isLandlord: isLandlord),
          ],
        ),
      ),
    );
  }
}

class _DetailsTab extends StatelessWidget {
  final TenancyModel tenancy;
  final bool isLandlord;
  final TenancyState tenancyState;
  const _DetailsTab({required this.tenancy, required this.isLandlord, required this.tenancyState});

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
        if (tenancy.isUpcoming && !isLandlord) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.action.withAlpha(13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18, color: AppTheme.actionPressed),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your application was approved. Pay the agency fee to secure your tenancy before move-in.',
                    style: TextStyle(fontSize: 12, color: AppTheme.actionPressed),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          PayAgencyFeeButton(propertyId: tenancy.propertyId),
          const SizedBox(height: 12),
        ],
        if (tenancy.isUpcoming && isLandlord)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => tenancyState.activateTenancy(tenancy.id),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirm Move-in (Activate)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
          ),
        if (tenancy.isActive) ...[
          if (tenancy.noticeGiven)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.deepOrange.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notice given by ${tenancy.noticeBy}. Planned move-out: ${tenancy.plannedMoveOutDate != null ? _fmt(tenancy.plannedMoveOutDate!) : '-'}.',
                      style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                    ),
                  ),
                ],
              ),
            )
          else if (tenancy.renewalRequested)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.blue.withAlpha(20), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.autorenew, size: 18, color: Colors.blue),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('Renewal requested — awaiting landlord confirmation.', style: TextStyle(fontSize: 12, color: Colors.blue)),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRequestRenewalDialog(context, tenancyState, isLandlord),
                    icon: const Icon(Icons.autorenew),
                    label: const Text('Request Renewal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showGiveNoticeDialog(context, tenancyState, isLandlord),
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Give Notice'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          if (isLandlord && tenancy.renewalRequested) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _confirmRenewal(context, tenancyState),
                icon: const Icon(Icons.check_circle),
                label: const Text('Confirm Renewal'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isLandlord)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => tenancyState.completeTenancy(tenancy.id),
                icon: const Icon(Icons.done_all),
                label: const Text('Mark Tenancy Complete'),
              ),
            ),
        ],
      ],
    );
  }

  void _showGiveNoticeDialog(BuildContext context, TenancyState tenancyState, bool isLandlord) {
    DateTime plannedDate = DateTime.now().add(const Duration(days: 30));
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Text('Give Move-Out Notice'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Planned move-out: ${_fmt(plannedDate)}'),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: dialogContext,
                    initialDate: plannedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => plannedDate = picked);
                },
                child: const Text('Change Date'),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'Reason (optional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                tenancyState.giveNotice(
                  tenancy.id,
                  givenBy: isLandlord ? 'landlord' : 'tenant',
                  plannedMoveOutDate: plannedDate,
                  reason: reasonController.text.isEmpty ? null : reasonController.text,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Submit Notice'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestRenewalDialog(BuildContext context, TenancyState tenancyState, bool isLandlord) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Request Renewal'),
        content: const Text('Ask the other party to renew this tenancy for another term?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              tenancyState.requestRenewal(tenancy.id, requestedBy: isLandlord ? 'landlord' : 'tenant');
              Navigator.pop(dialogContext);
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  void _confirmRenewal(BuildContext context, TenancyState tenancyState) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await tenancyState.confirmRenewal(tenancy.id);
      messenger.showSnackBar(const SnackBar(content: Text('Tenancy renewed.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Renewal failed: $e'), backgroundColor: Colors.red));
    }
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
      TenancyStatus.active => tenancy.noticeGiven ? Colors.deepOrange : Colors.green,
      TenancyStatus.completed => Colors.blue,
      TenancyStatus.terminated => Colors.red,
      TenancyStatus.renewed => Colors.blueGrey,
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
          Icon(icon, size: 20, color: AppTheme.primary),
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
  final TenancyState tenancyState;
  final bool isLandlord;
  final UserModel? currentUser;
  const _MaintenanceTab({
    required this.tenancy,
    required this.tenancyState,
    required this.isLandlord,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    final requests = tenancyState.maintenanceRequests.where((r) => r.propertyId == tenancy.propertyId).toList();

    return Column(
      children: [
        Expanded(
          child: requests.isEmpty
              ? Center(child: Text('No maintenance requests.', style: TextStyle(color: Colors.grey[600])))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: requests.length,
                  itemBuilder: (_, i) => _MaintenanceCard(request: requests[i], isLandlord: isLandlord, tenancyState: tenancyState),
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
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
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
    final user = currentUser;
    if (user == null) return;

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
                  tenancyState.addMaintenanceRequest(MaintenanceRequestModel(
                    id: 'mr${DateTime.now().millisecondsSinceEpoch}',
                    tenantId: user.id,
                    tenantName: user.fullName,
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
  final TenancyState tenancyState;
  const _MaintenanceCard({required this.request, required this.isLandlord, required this.tenancyState});

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
                  backgroundColor: AppTheme.primary.withAlpha(13),
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
                      onPressed: () => tenancyState.updateMaintenanceStatus(request.id, MaintenanceStatus.inProgress),
                      child: const Text('Mark In Progress'),
                    ),
                  TextButton(
                    onPressed: () => tenancyState.updateMaintenanceStatus(request.id, MaintenanceStatus.resolved),
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
  final TenancyState tenancyState;
  const _RentTab({required this.tenancy, required this.tenancyState});

  @override
  Widget build(BuildContext context) {
    final schedules = tenancyState.rentSchedules.where((r) => r.tenancyId == tenancy.id).toList()
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
                    onPressed: () => tenancyState.markRentPaid(s.id),
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                    child: const Text('Pay'),
                  ),
          ),
        );
      },
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

/// Post-tenancy turnover: inspection (scheduled by process-tenancy-
/// expiry or manually) and deposit settlement. Record-keeping only —
/// no payment moves through the app for the deposit, same as rent.
class _MoveOutTab extends StatelessWidget {
  final TenancyModel tenancy;
  final TenancyState tenancyState;
  final bool isLandlord;
  const _MoveOutTab({required this.tenancy, required this.tenancyState, required this.isLandlord});

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<UserState>().currentUser?.id;
    final deposits = (isLandlord
            ? tenancyState.landlordDepositTransactionsFor(userId)
            : tenancyState.myDepositTransactionsFor(userId))
        .where((d) => d.tenancyId == tenancy.id)
        .toList();
    final deposit = deposits.isNotEmpty ? deposits.first : null;
    final canWindDown = tenancy.isActive || tenancy.isCompleted || tenancy.isTerminated;

    if (!canWindDown) {
      return Center(
        child: Text('Move-out details appear once the tenancy ends.', style: TextStyle(color: Colors.grey[600])),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Inspection', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        StreamBuilder<List<InspectionModel>>(
          stream: DataService().getInspectionsForTenancy(tenancy.id),
          builder: (context, snapshot) {
            final inspections = snapshot.data ?? [];
            if (inspections.isEmpty) {
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('No inspection scheduled yet'),
                  trailing: isLandlord && !tenancy.isActive
                      ? TextButton(
                          onPressed: () => tenancyState.scheduleInspection(
                            propertyId: tenancy.propertyId,
                            tenancyId: tenancy.id,
                            landlordId: tenancy.landlordId,
                            scheduledDate: DateTime.now().add(const Duration(days: 3)),
                          ),
                          child: const Text('Schedule'),
                        )
                      : null,
                ),
              );
            }
            final inspection = inspections.first;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          inspection.isCompleted ? Icons.check_circle : Icons.schedule,
                          color: inspection.isCompleted ? Colors.green : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(inspection.isCompleted ? 'Inspection completed' : 'Inspection scheduled'),
                      ],
                    ),
                    if (inspection.isCompleted) ...[
                      const SizedBox(height: 8),
                      Text('Condition: ${inspection.conditionAfter ?? '-'}', style: const TextStyle(fontSize: 13)),
                      Text(
                        inspection.hasDamage
                            ? 'Damages found: TZS ${inspection.damageCost.toStringAsFixed(0)}'
                            : 'No damages found',
                        style: TextStyle(fontSize: 13, color: inspection.hasDamage ? Colors.red : Colors.green),
                      ),
                    ] else if (isLandlord)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showCompleteInspectionDialog(context, inspection),
                          child: const Text('Complete Inspection'),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const Text('Deposit Settlement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        if (deposit == null)
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: Text('Deposit held: TZS ${tenancy.depositAmount.toStringAsFixed(0)}'),
              subtitle: const Text('Not yet settled'),
              trailing: isLandlord && !tenancy.isActive
                  ? TextButton(
                      onPressed: () => tenancyState.openDepositTransaction(
                        tenancyId: tenancy.id,
                        tenantId: tenancy.tenantId,
                        landlordId: tenancy.landlordId,
                        amount: tenancy.depositAmount,
                      ),
                      child: const Text('Open Settlement'),
                    )
                  : null,
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Amount held: TZS ${deposit.amount.toStringAsFixed(0)}'),
                  if (deposit.isSettled) ...[
                    Text('Deductions: TZS ${deposit.deductions.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red)),
                    Text('Refund: TZS ${deposit.refundAmount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    if (deposit.notes != null && deposit.notes!.isNotEmpty) Text(deposit.notes!, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ] else if (isLandlord)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showSettleDepositDialog(context, deposit),
                        child: const Text('Settle Deposit'),
                      ),
                    )
                  else
                    const Text('Awaiting landlord settlement.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _showCompleteInspectionDialog(BuildContext context, InspectionModel inspection) {
    final conditionController = TextEditingController();
    final damageController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Complete Inspection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: conditionController,
              decoration: const InputDecoration(labelText: 'Condition found', border: OutlineInputBorder()),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: damageController,
              decoration: const InputDecoration(labelText: 'Damage cost (TZS, 0 if none)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              try {
                await tenancyState.completeInspection(
                  inspection.id,
                  conditionAfter: conditionController.text,
                  damageCost: double.tryParse(damageController.text) ?? 0,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
              } catch (e) {
                messenger.showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSettleDepositDialog(BuildContext context, DepositTransactionModel deposit) {
    final deductionsController = TextEditingController(text: '0');
    final notesController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Settle Deposit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount held: TZS ${deposit.amount.toStringAsFixed(0)}'),
            const SizedBox(height: 12),
            TextField(
              controller: deductionsController,
              decoration: const InputDecoration(labelText: 'Deductions (TZS)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final deductions = double.tryParse(deductionsController.text) ?? 0;
              tenancyState.settleDeposit(
                deposit.id,
                amount: deposit.amount,
                deductions: deductions,
                notes: notesController.text.isEmpty ? null : notesController.text,
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
