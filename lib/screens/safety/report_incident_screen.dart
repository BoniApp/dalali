import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';

class ReportIncidentScreen extends StatefulWidget {
  final String? initialLocation;
  final double? initialLatitude;
  final double? initialLongitude;

  const ReportIncidentScreen({
    super.key,
    this.initialLocation,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  IncidentType _type = IncidentType.other;
  IncidentSeverity _severity = IncidentSeverity.medium;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _locationController.text = widget.initialLocation!;
    }
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final appState = context.read<AppState>();
    final user = appState.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    final report = NeighbourhoodReportModel(
      id: 'nr_${DateTime.now().millisecondsSinceEpoch}',
      reporterId: user.id,
      reporterName: user.fullName,
      reporterVerified: user.verificationStatus == VerificationStatus.verified,
      type: _type,
      severity: _severity,
      location: _locationController.text.trim(),
      latitude: widget.initialLatitude ?? -6.75,
      longitude: widget.initialLongitude ?? 39.27,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      reportedAt: DateTime.now(),
    );

    appState.addNeighbourhoodReport(report);

    setState(() => _isLoading = false);

    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incident reported. Thank you for keeping the community safe.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Report Incident')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '🚨 Report a Safety Incident',
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Your report helps others make informed decisions about where to live.',
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Incident type
              Text('Incident Type', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: IncidentType.values.map((t) {
                  final selected = _type == t;
                  return ChoiceChip(
                    label: Text(_typeLabel(t)),
                    selected: selected,
                    onSelected: (_) => setState(() => _type = t),
                    selectedColor: theme.colorScheme.primaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Severity
              Text('Severity', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<IncidentSeverity>(
                segments: IncidentSeverity.values.map((s) {
                  return ButtonSegment(
                    value: s,
                    label: Text(_severityLabel(s)),
                  );
                }).toList(),
                selected: {_severity},
                onSelectionChanged: (set) => setState(() => _severity = set.first),
              ),
              const SizedBox(height: 20),

              // Location
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'e.g. Near Masaki Plaza, Dar es Salaam',
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Please enter a location' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What happened? Any details that could help others.',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Important',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Only report incidents you have witnessed or verified\n'
                      '• False reports will lower your trust score\n'
                      '• In emergencies, contact local authorities first',
                      style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.report),
                label: Text(_isLoading ? 'Submitting...' : 'Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(IncidentType t) => switch (t) {
    IncidentType.theft => 'Theft',
    IncidentType.noise => 'Noise',
    IncidentType.scam => 'Scam',
    IncidentType.hazard => 'Hazard',
    IncidentType.assault => 'Assault',
    IncidentType.vandalism => 'Vandalism',
    IncidentType.other => 'Other',
  };

  String _severityLabel(IncidentSeverity s) => switch (s) {
    IncidentSeverity.low => 'Low',
    IncidentSeverity.medium => 'Medium',
    IncidentSeverity.high => 'High',
    IncidentSeverity.critical => 'Critical',
  };
}
