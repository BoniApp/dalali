import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/providers/tenancy_state.dart';
import 'package:dalali/widgets/pay_agency_fee_button.dart';
import 'package:dalali/widgets/guest_gate.dart';
import 'package:provider/provider.dart';

class ReservationRequestsScreen extends StatelessWidget {
  const ReservationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>().currentUser;
    final tenancyState = context.watch<TenancyState>();
    final isLandlord = user?.role == UserRole.landlord || user?.role == UserRole.agent;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLandlord ? 'Reservation Approvals' : 'My Applications'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: isLandlord
          ? _LandlordView(tenancyState: tenancyState, userId: user?.id)
          : _TenantView(tenancyState: tenancyState, userId: user?.id),
    );
  }
}

class _TenantView extends StatelessWidget {
  final TenancyState tenancyState;
  final String? userId;
  const _TenantView({required this.tenancyState, required this.userId});

  @override
  Widget build(BuildContext context) {
    final myApps = tenancyState.myTenancyApplicationsFor(userId);
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => context.read<TenancyState>().refreshData(),
      child: myApps.isEmpty
          ? _EmptyState(message: 'You have not applied for any properties yet.', icon: Icons.send)
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: myApps.length,
              itemBuilder: (_, i) => _ApplicationCard(application: myApps[i], isLandlord: false),
            ),
    );
  }
}

class _LandlordView extends StatelessWidget {
  final TenancyState tenancyState;
  final String? userId;
  const _LandlordView({required this.tenancyState, required this.userId});

  @override
  Widget build(BuildContext context) {
    final pending = tenancyState.pendingApplicationsForLandlordFor(userId);
    final all = tenancyState.tenancyApplications.where((a) => a.landlordId == userId).toList();

    if (all.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => context.read<TenancyState>().refreshData(),
        child: _EmptyState(message: 'No reservation requests yet.', icon: Icons.inbox),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => context.read<TenancyState>().refreshData(),
      child: ListView(
        padding: const EdgeInsets.all(12),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
        if (pending.isNotEmpty) ...[
          Text('Pending (${pending.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...pending.map((a) => _ApplicationCard(application: a, isLandlord: true, tenancyState: tenancyState)),
          const SizedBox(height: 16),
        ],
        if (all.any((a) => a.status != ApplicationStatus.pending)) ...[
          const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...all.where((a) => a.status != ApplicationStatus.pending).map(
            (a) => _ApplicationCard(application: a, isLandlord: true, tenancyState: tenancyState),
          ),
        ],
      ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final TenancyApplicationModel application;
  final bool isLandlord;
  final TenancyState? tenancyState;
  const _ApplicationCard({required this.application, required this.isLandlord, this.tenancyState});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (application.status) {
      ApplicationStatus.pending => Colors.orange,
      ApplicationStatus.approved => Colors.green,
      ApplicationStatus.rejected => Colors.red,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    application.propertyTitle,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  label: Text(
                    application.status.name[0].toUpperCase() + application.status.name.substring(1),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  backgroundColor: statusColor.withAlpha(26),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isLandlord ? 'From: ${application.tenantName}' : 'To: ${application.landlordName}',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            if (application.notes != null && application.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(application.notes!, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
              ),
            ],
            if (isLandlord && application.status == ApplicationStatus.pending && tenancyState != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => tenancyState!.approveApplication(application.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => tenancyState!.rejectApplication(application.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
            if (!isLandlord && application.status == ApplicationStatus.approved) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.action.withAlpha(13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.celebration, size: 18, color: AppTheme.actionPressed),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approved! Pay the agency fee to secure your tenancy.',
                        style: TextStyle(fontSize: 12, color: AppTheme.actionPressed, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              PayAgencyFeeButton(propertyId: application.propertyId),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 160),
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
      ],
    );
  }
}

/// Button widget to apply for a property from the detail screen.
class ApplyForTenancyButton extends StatelessWidget {
  final PropertyModel property;
  const ApplyForTenancyButton({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserState>().currentUser;
    final tenancyState = context.watch<TenancyState>();
    // Landlords/agents never apply to their own listings; a guest or a
    // seeker always can (guest is gated on tap below).
    if (user != null && user.role != UserRole.seeker) return const SizedBox.shrink();

    // Check if already applied
    final alreadyApplied = user != null && tenancyState.tenancyApplications.any(
      (a) => a.propertyId == property.id && a.tenantId == user.id,
    );

    if (alreadyApplied) {
      return const Chip(
        label: Text('Application Submitted'),
        backgroundColor: Colors.orange,
        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
      );
    }

    return ElevatedButton.icon(
      onPressed: () {
        if (!GuestGate.requireAuth(context, message: 'Sign up to apply for this property.')) return;
        _submitApplication(context, tenancyState, context.read<UserState>().currentUser!);
      },
      icon: const Icon(Icons.send),
      label: const Text('Apply to Rent'),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
    );
  }

  void _submitApplication(BuildContext context, TenancyState tenancyState, UserModel user) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply to Rent'),
        content: TextField(
          controller: noteController,
          decoration: const InputDecoration(
            labelText: 'Message to landlord (optional)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              tenancyState.applyForTenancy(TenancyApplicationModel(
                id: 'ta${DateTime.now().millisecondsSinceEpoch}',
                propertyId: property.id,
                propertyTitle: property.title,
                tenantId: user.id,
                tenantName: user.fullName,
                tenantPhone: user.phone,
                landlordId: property.landlordId,
                landlordName: property.landlordName,
                createdAt: DateTime.now(),
                notes: noteController.text.isNotEmpty ? noteController.text : null,
              ));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Application submitted!')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
