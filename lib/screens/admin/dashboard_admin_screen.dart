import 'package:flutter/material.dart';
import 'package:dalali/services/admin/admin_service.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardAdminScreen extends StatelessWidget {
  const DashboardAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final adminService = AdminService();

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Real-time platform metrics', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),

            // ─── Metrics Cards ──────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _MetricCard(
                  label: 'Total Users',
                  stream: adminService.getTotalUsersCount(),
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _MetricCard(
                  label: 'Active Today',
                  stream: adminService.getActiveUsersToday(),
                  icon: Icons.trending_up,
                  color: Colors.green,
                ),
                _MetricCard(
                  label: 'Active Listings',
                  stream: adminService.getActiveListingsCount(),
                  icon: Icons.home_work,
                  color: Colors.teal,
                ),
                _MetricCard(
                  label: 'Pending Listings',
                  stream: adminService.getPendingListingsCount(),
                  icon: Icons.pending_actions,
                  color: Colors.orange,
                ),
                _MetricCard(
                  label: 'Completed Deals',
                  stream: adminService.getCompletedTransactionsCount(),
                  icon: Icons.check_circle,
                  color: Colors.purple,
                ),
                _MetricCard(
                  label: 'Pending Withdrawals',
                  stream: adminService.getPendingWithdrawalsCount(),
                  icon: Icons.account_balance,
                  color: Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Revenue Card ───────────────────────────────────────
            _RevenueCard(),
            const SizedBox(height: 24),

            // ─── Charts Row ─────────────────────────────────────────
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _ChartCard(title: 'Daily Transactions', child: _DailyTransactionsChart()),
                _ChartCard(title: 'Revenue Trend', child: _RevenueTrendChart()),
              ],
            ),
            const SizedBox(height: 24),

            // ─── Fraud Alerts Preview ───────────────────────────────
            _FraudAlertsPreview(),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final Stream<int> stream;
  final IconData icon;
  final Color color;

  const _MetricCard({required this.label, required this.stream, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: StreamBuilder<int>(
            stream: stream,
            builder: (context, snapshot) {
              final value = snapshot.data ?? 0;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$value',
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Revenue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(16)),
                  child: Text('Live', style: TextStyle(fontSize: 12, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('transactions')
                  .where('status', isEqualTo: 'completed')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final totalRevenue = docs.fold<double>(0, (total, d) {
                  final data = d.data() as Map<String, dynamic>;
                  return total + ((data['amount'] as num?)?.toDouble() ?? 0);
                });
                final platformShare = totalRevenue * 0.40;
                final agentShare = totalRevenue * 0.60;

                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(Helpers.formatPrice(totalRevenue), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Platform (40%): ${Helpers.formatPrice(platformShare)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                          Text('Agents (60%): ${Helpers.formatPrice(agentShare)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              value: 40,
                              title: '40%',
                              color: Colors.teal,
                              radius: 30,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            PieChartSectionData(
                              value: 60,
                              title: '60%',
                              color: Colors.amber,
                              radius: 30,
                              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500,
      height: 300,
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyTransactionsChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value < 0 || value >= days.length) return const SizedBox.shrink();
                return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(7, (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: [12, 19, 8, 15, 22, 18, 25][i].toDouble(),
              color: Colors.teal,
              width: 20,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
          ],
        )),
      ),
    );
  }
}

class _RevenueTrendChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                if (value < 0 || value >= days.length) return const SizedBox.shrink();
                return Text(days[value.toInt()], style: const TextStyle(fontSize: 10));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 240000),
              FlSpot(1, 380000),
              FlSpot(2, 160000),
              FlSpot(3, 300000),
              FlSpot(4, 440000),
              FlSpot(5, 360000),
              FlSpot(6, 500000),
            ],
            isCurved: true,
            color: Colors.teal,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.teal.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}

class _FraudAlertsPreview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fraud Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                StreamBuilder<int>(
                  stream: AdminService().getUnresolvedFraudCount(),
                  builder: (context, snapshot) {
                    final count = snapshot.data ?? 0;
                    if (count == 0) return const SizedBox.shrink();
                    return Badge(
                      label: Text('$count'),
                      child: const Icon(Icons.warning_amber, color: Colors.red),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder(
              stream: AdminService().getAllFraudReports(limit: 5),
              builder: (context, snapshot) {
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No unresolved fraud alerts', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return Column(
                  children: reports.map((r) => ListTile(
                    leading: Icon(Icons.warning, color: _severityColor(r.severity)),
                    title: Text(r.reason, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    subtitle: Text('Severity: ${r.severity}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    trailing: Chip(
                      label: Text(r.severity.toUpperCase(), style: const TextStyle(fontSize: 10)),
                      backgroundColor: _severityColor(r.severity).withValues(alpha: 0.1),
                      labelStyle: TextStyle(fontSize: 10, color: _severityColor(r.severity), fontWeight: FontWeight.bold),
                    ),
                  )).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(String s) {
    return switch (s.toLowerCase()) {
      'critical' => Colors.red,
      'high' => Colors.orange,
      'medium' => Colors.amber,
      _ => Colors.blue,
    };
  }
}
