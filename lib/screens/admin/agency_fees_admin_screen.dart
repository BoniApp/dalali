import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/agency_fee_model.dart';
import 'package:dalali/services/data_service.dart';

class AgencyFeesAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const AgencyFeesAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  Future<void> _approveFee(BuildContext context, AgencyFeeModel fee) async {
    final updated = fee.copyWith(
      status: AgencyFeeStatus.approved,
      approvedAt: DateTime.now(),
      approvedBy: adminId,
    );
    await DataService().updateAgencyFee(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency fee approved')),
      );
    }
  }

  Future<void> _markPaid(BuildContext context, AgencyFeeModel fee) async {
    final updated = fee.copyWith(
      status: AgencyFeeStatus.paid,
      paidAt: DateTime.now(),
    );
    await DataService().updateAgencyFee(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agency fee marked as paid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agency Fees'),
      ),
      body: StreamBuilder<List<AgencyFeeModel>>(
        stream: DataService().getPendingAgencyFees(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No pending agency fees.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final f = list[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('${f.amount.toStringAsFixed(0)} ${f.currency}'),
                  subtitle: Text('Creator: ${f.listingCreatorId}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (f.status == AgencyFeeStatus.pending)
                        FilledButton(
                          onPressed: () => _approveFee(context, f),
                          child: const Text('Approve'),
                        ),
                      if (f.status == AgencyFeeStatus.approved)
                        FilledButton(
                          onPressed: () => _markPaid(context, f),
                          child: const Text('Mark Paid'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
