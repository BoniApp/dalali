import 'dart:math' show exp;
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/property_model.dart';

/// Computes neighbourhood safety scores with time-decay and trust weighting.
///
/// Algorithm:
/// 1. Gather all reports near the property (within radiusKm).
/// 2. For each report: weight = severityWeight × trustFactor × timeDecay.
/// 3. Sum weights → total negative impact.
/// 4. Map to a 0-100 safety score using sigmoid.
/// 5. Recent critical reports from trusted users hurt the score most.
class SafetyEngine {
  /// Radius in km to consider reports near a property.
  static const double defaultRadiusKm = 1.5;

  /// Half-life in days for time decay. After this many days, impact is 50%.
  static const double decayHalfLifeDays = 30;

  /// Reports older than this are effectively ignored.
  static const double maxReportAgeDays = 90;

  /// Max negative impact before score bottoms out at 0.
  static const double maxImpact = 50;

  /// Computes safety score (0-100) for a single property.
  double computeSafetyScore({
    required PropertyModel property,
    required List<NeighbourhoodReportModel> nearbyReports,
  }) {
    if (nearbyReports.isEmpty) return 80.0; // default safe baseline

    double totalImpact = 0;
    for (final report in nearbyReports) {
      if (report.resolved) continue;
      if (report.daysSinceReported > maxReportAgeDays) continue;

      final trustFactor = _trustFactor(report.reporterTrustScore, report.reporterVerified);
      final timeDecay = _timeDecay(report.daysSinceReported);
      final impact = report.severityWeight * trustFactor * timeDecay;

      totalImpact += impact;
    }

    // Sigmoid mapping: score = 100 / (1 + exp(totalImpact / 10))
    // As impact → ∞, score → 0. As impact → 0, score → 100.
    final score = 100.0 / (1 + exp(totalImpact / 10));
    return score.clamp(0, 100);
  }

  /// Number of active (unresolved, recent) incidents near a property.
  int countActiveIncidents({
    required PropertyModel property,
    required List<NeighbourhoodReportModel> nearbyReports,
  }) {
    return nearbyReports.where((r) {
      return !r.resolved && r.daysSinceReported <= maxReportAgeDays;
    }).length;
  }

  /// Filters reports that are within radiusKm of the given lat/lng.
  List<NeighbourhoodReportModel> filterNearby({
    required double latitude,
    required double longitude,
    required List<NeighbourhoodReportModel> allReports,
    double radiusKm = defaultRadiusKm,
  }) {
    return allReports.where((r) {
      final d = _haversine(latitude, longitude, r.latitude, r.longitude);
      return d <= radiusKm;
    }).toList();
  }

  // ─── Helpers ────────────────────────────────────────────────

  double _trustFactor(int trustScore, bool verified) {
    // Base trust 0.3-1.0 based on score; verified users get +0.2
    double factor = 0.3 + (trustScore / 100) * 0.7;
    if (verified) factor += 0.2;
    return factor.clamp(0.3, 1.5);
  }

  double _timeDecay(double days) {
    // Exponential decay: impact halves every decayHalfLifeDays
    return exp(-0.693 * days / decayHalfLifeDays);
  }

  /// Haversine distance in km between two lat/lng points.
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        (dLat / 2).sin() * (dLat / 2).sin() +
        _toRadians(lat1).cos() * _toRadians(lat2).cos() * (dLng / 2).sin() * (dLng / 2).sin();
    final c = 2 * a.sqrt().atan2((1 - a).sqrt());
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;
}

extension _MathExt on double {
  double sin() => _sin(this);
  double cos() => _cos(this);
  double sqrt() => _sqrt(this);
  double atan2(double other) => _atan2(this, other);
}

double _sin(double x) {
  // Taylor series approximation for sin(x)
  double result = x;
  double term = x;
  for (int n = 1; n <= 7; n++) {
    term *= -x * x / ((2 * n) * (2 * n + 1));
    result += term;
  }
  return result;
}

double _cos(double x) {
  double result = 1;
  double term = 1;
  for (int n = 1; n <= 7; n++) {
    term *= -x * x / ((2 * n - 1) * (2 * n));
    result += term;
  }
  return result;
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  double guess = x;
  for (int i = 0; i < 20; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

double _atan2(double y, double x) {
  // Approximation of atan2
  if (x == 0) return y > 0 ? 1.57079632679 : -1.57079632679;
  double angle = y / x;
  if (angle.abs() <= 1) {
    double result = angle / (1 + 0.28 * angle * angle);
    if (x < 0) result += (y >= 0 ? 3.14159265359 : -3.14159265359);
    return result;
  } else {
    double result = 1.57079632679 - angle / (angle * angle + 0.28);
    if (y < 0) result = -1.57079632679 - angle / (angle * angle + 0.28);
    if (x < 0) result += 3.14159265359;
    return result;
  }
}
