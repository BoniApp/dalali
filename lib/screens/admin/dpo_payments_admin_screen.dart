import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/models/admin/admin_user_model.dart';
import 'package:dalali/models/payment_model.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/utils/helpers.dart';

/// ═══════════════════════════════════════════════════════════════
/// DPO PAYMENTS ADMIN DASHBOARD
/// ═══════════════════════════════════════════════════════════════
///
/// Revenue overview for DPO agency-fee collections: totals, today's
/// revenue, status counts, and the most recent payments.
class DpoPaymentsAdminScreen extends StatelessWidget {
  final String adminId;
  final String adminName;
  final AdminRole adminRole;

  const DpoPaymentsAdminScreen({
    super.key,
    required this.adminId,
    required this.adminName,
    required this.adminRole,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DPO Payments')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: SupabaseService.client
            .from('payments')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false)
            .limit(200),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snapshot.data ?? [];
          final payments = rows.map(PaymentModel.fromJson).toList();

          final paid = payments.where((p) => p.status == PaymentStatus.paid).toList();
          final pending = payments.where((p) => p.status == PaymentStatus.pending).length;
          final failed = payments.where((p) => p.status == PaymentStatus.failed).length;
          final totalRevenue = paid.fold<double>(0, (s, p) => s + p.amount);
          final today = DateUtils.dateOnly(DateTime.now());
          final todayRevenue = paid
              .where((p) => p.paidAt != null && DateUtils.dateOnly(p.paidAt!) == today)
              .fold<double>(0, (s, p) => s + p.amount);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Total Revenue', value: Helpers.formatPrice(totalRevenue), color: Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: "Today's Revenue", value: Helpers.formatPrice(todayRevenue), color: AppTheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Paid', value: '${paid.length}', color: Colors.green)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: 'Pending', value: '$pending', color: Colors.orange)),
                  const SizedBox(width: 8),
                  Expanded(child: _StatCard(label: 'Failed', value: '$failed', color: Colors.red)),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Recent Payments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (payments.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No payments yet.')),
                )
              else
                ...payments.take(50).map((p) => Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _statusColor(p.status).withAlpha(30),
                          child: Icon(Icons.payments, color: _statusColor(p.status), size: 18),
                        ),
                        title: Text(Helpers.formatPrice(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          '${p.receiptNumber} · ${p.paymentMethod ?? 'DPO'} · ${Helpers.formatDate(p.createdAt)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Text(
                          p.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(p.status),
                          ),
                        ),
                      ),
                    )),
            ],
          );
        },
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Colors.green;
      case PaymentStatus.pending:
        return Colors.orange;
      case PaymentStatus.failed:
      case PaymentStatus.cancelled:
      case PaymentStatus.expired:
        return Colors.red;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.account_balance_wallet, color: color, size: 20),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
