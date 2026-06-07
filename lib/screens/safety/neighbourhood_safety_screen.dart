import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/screens/safety/report_incident_screen.dart';



class NeighbourhoodSafetyScreen extends StatefulWidget {
  const NeighbourhoodSafetyScreen({super.key});

  @override
  State<NeighbourhoodSafetyScreen> createState() => _NeighbourhoodSafetyScreenState();
}

class _NeighbourhoodSafetyScreenState extends State<NeighbourhoodSafetyScreen> {
  bool _showMap = false;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final reports = appState.neighbourhoodReports;
    final unresolved = reports.where((r) => !r.resolved).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Neighbourhood Safety'),
        actions: [
          IconButton(
            icon: Icon(_showMap ? Icons.list : Icons.map),
            onPressed: () => setState(() => _showMap = !_showMap),
          ),
        ],
      ),
      body: _showMap
          ? _SafetyMap(reports: unresolved)
          : _SafetyList(reports: unresolved, theme: theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ReportIncidentScreen()),
        ),
        icon: const Icon(Icons.report),
        label: const Text('Report'),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }
}

class _SafetyList extends StatelessWidget {
  final List<NeighbourhoodReportModel> reports;
  final ThemeData theme;

  const _SafetyList({required this.reports, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const _EmptySafetyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (_, i) => _ReportCard(report: reports[i]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final NeighbourhoodReportModel report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final (typeColor, typeIcon) = _typeStyle(report.type);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(typeIcon, size: 18, color: typeColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _typeLabel(report.type),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        report.location,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _SeverityChip(severity: report.severity),
              ],
            ),
            if (report.description != null && report.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(report.description!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(report.reporterName[0].toUpperCase(), style: const TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 8),
                Text(report.reporterName, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                if (report.reporterVerified) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified, size: 14, color: Colors.green),
                ],
                const Spacer(),
                Text(
                  DateFormat('MMM d').format(report.reportedAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final IncidentSeverity severity;

  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (severity) {
      IncidentSeverity.low => (Colors.green.shade700, 'Low'),
      IncidentSeverity.medium => (Colors.orange.shade700, 'Medium'),
      IncidentSeverity.high => (Colors.deepOrange.shade700, 'High'),
      IncidentSeverity.critical => (Colors.red.shade700, 'Critical'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _SafetyMap extends StatelessWidget {
  final List<NeighbourhoodReportModel> reports;

  const _SafetyMap({required this.reports});

  @override
  Widget build(BuildContext context) {
    // Default center: Dar es Salaam
    const center = LatLng(-6.7924, 39.2083);

    return FlutterMap(
      options: const MapOptions(
        initialCenter: center,
        initialZoom: 12,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.dalali.app',
          tileProvider: CancellableNetworkTileProvider(),
        ),
        MarkerLayer(
          markers: reports.map((r) {
            final color = _severityColor(r.severity);
            return Marker(
              point: LatLng(r.latitude, r.longitude),
              width: 40,
              height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
                child: Center(
                  child: Icon(
                    _typeIcon(r.type),
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _EmptySafetyState extends StatelessWidget {
  const _EmptySafetyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text('No Active Incidents', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'The neighbourhood looks safe. Stay vigilant and report anything suspicious.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────

(Color color, IconData icon) _typeStyle(IncidentType t) => switch (t) {
  IncidentType.theft => (Colors.orange, Icons.shopping_bag),
  IncidentType.noise => (Colors.blue, Icons.volume_up),
  IncidentType.scam => (Colors.purple, Icons.warning),
  IncidentType.hazard => (Colors.brown, Icons.construction),
  IncidentType.assault => (Colors.red, Icons.person_off),
  IncidentType.vandalism => (Colors.deepOrange, Icons.format_paint),
  IncidentType.other => (Colors.grey, Icons.help_outline),
};

String _typeLabel(IncidentType t) => switch (t) {
  IncidentType.theft => 'Theft',
  IncidentType.noise => 'Noise Complaint',
  IncidentType.scam => 'Scam / Fraud',
  IncidentType.hazard => 'Physical Hazard',
  IncidentType.assault => 'Assault',
  IncidentType.vandalism => 'Vandalism',
  IncidentType.other => 'Other',
};

IconData _typeIcon(IncidentType t) => switch (t) {
  IncidentType.theft => Icons.shopping_bag,
  IncidentType.noise => Icons.volume_up,
  IncidentType.scam => Icons.warning,
  IncidentType.hazard => Icons.construction,
  IncidentType.assault => Icons.person_off,
  IncidentType.vandalism => Icons.format_paint,
  IncidentType.other => Icons.help_outline,
};

Color _severityColor(IncidentSeverity s) => switch (s) {
  IncidentSeverity.low => Colors.green,
  IncidentSeverity.medium => Colors.orange,
  IncidentSeverity.high => Colors.deepOrange,
  IncidentSeverity.critical => Colors.red,
};
