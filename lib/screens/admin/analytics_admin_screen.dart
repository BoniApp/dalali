import 'package:flutter/material.dart';
import 'package:dalali/utils/helpers.dart';
import 'package:fl_chart/fl_chart.dart';

class AnalyticsAdminScreen extends StatelessWidget {
  const AnalyticsAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Platform performance metrics', style: TextStyle(fontSize: 14, color: Colors.grey[600])),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _AnalyticCard(title: 'User Growth', child: _UserGrowthChart()),
                _AnalyticCard(title: 'Top Locations', child: _TopLocationsChart()),
                _AnalyticCard(title: 'Conversion Funnel', child: _ConversionFunnel()),
                _AnalyticCard(title: 'Top Agents', child: _TopAgentsChart()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _AnalyticCard({required this.title, required this.child});

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

class _UserGrowthChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: const FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 120), FlSpot(1, 180), FlSpot(2, 250), FlSpot(3, 340),
              FlSpot(4, 420), FlSpot(5, 510), FlSpot(6, 620),
            ],
            isCurved: true, color: Colors.blue, barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
          ),
        ],
      ),
    );
  }
}

class _TopLocationsChart extends StatelessWidget {
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
                const labels = ['Masaki', 'Mikocheni', 'Oyster', 'Ubungo', 'City Ctr'];
                if (value < 0 || value >= labels.length) return const SizedBox.shrink();
                return Text(labels[value.toInt()], style: const TextStyle(fontSize: 9));
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(5, (i) => BarChartGroupData(
          x: i,
          barRods: [BarChartRodData(toY: [45, 38, 32, 28, 25][i].toDouble(), color: Colors.teal, width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))],
        )),
      ),
    );
  }
}

class _ConversionFunnel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FunnelRow(label: 'Property Views', value: 12450, max: 12450, color: Colors.blue),
        const SizedBox(height: 8),
        _FunnelRow(label: 'Inquiries', value: 3200, max: 12450, color: Colors.teal),
        const SizedBox(height: 8),
        _FunnelRow(label: 'Viewings Scheduled', value: 1800, max: 12450, color: Colors.amber),
        const SizedBox(height: 8),
        _FunnelRow(label: 'Payments Made', value: 620, max: 12450, color: Colors.green),
      ],
    );
  }
}

class _FunnelRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  const _FunnelRow({required this.label, required this.value, required this.max, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = value / max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12)),
            Text('$value (${(pct * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _TopAgentsChart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final agents = [
      ('Peter Kafumu', 18, 360000),
      ('John Mwakalinga', 15, 300000),
      ('Grace Mushi', 8, 160000),
    ];
    return Column(
      children: agents.map((a) => ListTile(
        leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: Text(a.$1[0], style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))),
        title: Text(a.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        subtitle: Text('${a.$2} deals', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        trailing: Text(Helpers.formatPrice(a.$3.toDouble()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      )).toList(),
    );
  }
}
