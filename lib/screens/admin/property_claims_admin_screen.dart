import 'package:flutter/material.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/property_claim_model.dart';
import 'package:dalali/services/data_service.dart';

class PropertyClaimsAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const PropertyClaimsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  Future<void> _updateClaimStatus(BuildContext context, PropertyClaimModel claim, ClaimStatus status) async {
    final updated = claim.copyWith(
      status: status,
      reviewedBy: adminId,
      reviewedAt: DateTime.now(),
    );
    await DataService().updatePropertyClaim(updated);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Claim ${status.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Claims'),
      ),
      body: StreamBuilder<List<PropertyClaimModel>>(
        stream: DataService().getPropertyClaims(status: ClaimStatus.pending),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('No pending claims.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final c = list[index];
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Claim by ${c.claimantRole}: ${c.claimantId}'),
                      Text('Reason: ${c.reason}'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          FilledButton(
                            onPressed: () => _updateClaimStatus(context, c, ClaimStatus.approved),
                            child: const Text('Approve'),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _updateClaimStatus(context, c, ClaimStatus.rejected),
                            child: const Text('Reject'),
                          ),
                        ],
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
