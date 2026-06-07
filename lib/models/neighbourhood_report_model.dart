enum IncidentType { theft, noise, scam, hazard, assault, vandalism, other }
enum IncidentSeverity { low, medium, high, critical }

/// A neighbourhood safety report submitted by a user.
class NeighbourhoodReportModel {
  final String id;
  final String reporterId;
  final String reporterName;

  // Anti-spam / trust
  final bool reporterVerified;
  final int reporterTrustScore; // 0-100; higher = more trusted

  final IncidentType type;
  final IncidentSeverity severity;
  final String location; // text address
  final double latitude;
  final double longitude;
  final String? description;
  final DateTime reportedAt;

  // Resolution
  final bool resolved;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  NeighbourhoodReportModel({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    this.reporterVerified = false,
    this.reporterTrustScore = 50,
    required this.type,
    required this.severity,
    required this.location,
    required this.latitude,
    required this.longitude,
    this.description,
    required this.reportedAt,
    this.resolved = false,
    this.resolvedAt,
    this.resolvedBy,
  });

  /// Weighted severity score for algorithm calculations.
  int get severityWeight => switch (severity) {
    IncidentSeverity.low => 1,
    IncidentSeverity.medium => 3,
    IncidentSeverity.high => 6,
    IncidentSeverity.critical => 10,
  };

  /// How many days ago this was reported.
  double get daysSinceReported {
    return DateTime.now().difference(reportedAt).inHours / 24;
  }

  NeighbourhoodReportModel copyWith({
    String? id,
    String? reporterId,
    String? reporterName,
    bool? reporterVerified,
    int? reporterTrustScore,
    IncidentType? type,
    IncidentSeverity? severity,
    String? location,
    double? latitude,
    double? longitude,
    String? description,
    DateTime? reportedAt,
    bool? resolved,
    DateTime? resolvedAt,
    String? resolvedBy,
  }) {
    return NeighbourhoodReportModel(
      id: id ?? this.id,
      reporterId: reporterId ?? this.reporterId,
      reporterName: reporterName ?? this.reporterName,
      reporterVerified: reporterVerified ?? this.reporterVerified,
      reporterTrustScore: reporterTrustScore ?? this.reporterTrustScore,
      type: type ?? this.type,
      severity: severity ?? this.severity,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      description: description ?? this.description,
      reportedAt: reportedAt ?? this.reportedAt,
      resolved: resolved ?? this.resolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      resolvedBy: resolvedBy ?? this.resolvedBy,
    );
  }
}
