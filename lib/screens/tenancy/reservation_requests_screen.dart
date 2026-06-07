import 'package:flutter/material.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/models/tenancy_application_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:provider/provider.dart';

class ReservationRequestsScreen extends StatelessWidget {
  const ReservationRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final user = appState.currentUser;
    final isLandlord = user?.role == UserRole.landlord || user?.role == UserRole.agent;

    return Scaffold(
      appBar: AppBar(
        title: Text(isLandlord ? 'Reservation Approvals' : 'My Applications'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: isLandlord
          ? _LandlordView(appState: appState)
          : _TenantView(appState: appState),
    );
  }
}

class _TenantView extends StatelessWidget {
  final AppState appState;
  const _TenantView({required this.appState});

  @override
  Widget build(BuildContext context) {
    final myApps = appState.myTenancyApplications;
    if (myApps.isEmpty) {
      return _EmptyState(message: 'You have not applied for any properties yet.', icon: Icons.send);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: myApps.length,
      itemBuilder: (_, i) => _ApplicationCard(application: myApps[i], isLandlord: false),
    );
  }
}

class _LandlordView extends StatelessWidget {
  final AppState appState;
  const _LandlordView({required this.appState});

  @override
  Widget build(BuildContext context) {
    final pending = appState.pendingApplicationsForLandlord;
    final all = appState.tenancyApplications.where((a) => a.landlordId == appState.currentUser!.id).toList();

    if (all.isEmpty) {
      return _EmptyState(message: 'No reservation requests yet.', icon: Icons.inbox);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (pending.isNotEmpty) ...[
          Text('Pending (${pending.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...pending.map((a) => _ApplicationCard(application: a, isLandlord: true, appState: appState)),
          const SizedBox(height: 16),
        ],
        if (all.any((a) => a.status != ApplicationStatus.pending)) ...[
          const Text('History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...all.where((a) => a.status != ApplicationStatus.pending).map(
            (a) => _ApplicationCard(application: a, isLandlord: true, appState: appState),
          ),
        ],
      ],
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final TenancyApplicationModel application;
  final bool isLandlord;
  final AppState? appState;
  const _ApplicationCard({required this.application, required this.isLandlord, this.appState});

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
            if (isLandlord && application.status == ApplicationStatus.pending && appState != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => appState!.approveApplication(application.id),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => appState!.rejectApplication(application.id),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    ),
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

class _EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const _EmptyState({required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 15, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

/// Button widget to apply for a property from the detail screen.
class ApplyForTenancyButton extends StatelessWidget {
  final PropertyModel property;
  const ApplyForTenancyButton({super.key, required this.property});

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null || user.role != UserRole.seeker) return const SizedBox.shrink();

    // Check if already applied
    final alreadyApplied = appState.tenancyApplications.any(
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
      onPressed: () => _submitApplication(context, appState, user),
      icon: const Icon(Icons.send),
      label: const Text('Apply to Rent'),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
    );
  }

  void _submitApplication(BuildContext context, AppState appState, UserModel user) {
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
              appState.applyForTenancy(TenancyApplicationModel(
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
