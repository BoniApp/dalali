import 'package:flutter_test/flutter_test.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/property_model.dart';
import 'package:dalali/services/safety_engine.dart';

PropertyModel _property({double latitude = -6.7924, double longitude = 39.2083}) {
  return PropertyModel(
    id: 'p1',
    title: 'Property',
    description: 'desc',
    location: 'Masaki',
    latitude: latitude,
    longitude: longitude,
    rentPrice: 200000,
    bedrooms: 2,
    bathrooms: 1,
    propertyType: PropertyType.apartment,
    isFurnished: false,
    hasWater: true,
    hasParking: false,
    hasSecurity: false,
    images: const ['https://example.com/a.jpg'],
    landlordId: 'landlord1',
    landlordName: 'Landlord',
    landlordPhone: '+255700000000',
    createdAt: DateTime.now(),
  );
}

NeighbourhoodReportModel _report({
  IncidentSeverity severity = IncidentSeverity.medium,
  bool resolved = false,
  DateTime? reportedAt,
  bool reporterVerified = false,
  int reporterTrustScore = 50,
  double latitude = -6.7924,
  double longitude = 39.2083,
}) {
  return NeighbourhoodReportModel(
    id: 'r1',
    reporterId: 'reporter1',
    reporterName: 'Reporter',
    reporterVerified: reporterVerified,
    reporterTrustScore: reporterTrustScore,
    type: IncidentType.theft,
    severity: severity,
    location: 'Nearby',
    latitude: latitude,
    longitude: longitude,
    reportedAt: reportedAt ?? DateTime.now(),
    resolved: resolved,
  );
}

void main() {
  final engine = SafetyEngine();

  group('SafetyEngine.computeSafetyScore', () {
    test('returns the safe baseline when there are no reports', () {
      expect(engine.computeSafetyScore(property: _property(), nearbyReports: const []), 80.0);
    });

    test('a critical unresolved recent report lowers the score below baseline', () {
      final score = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(severity: IncidentSeverity.critical)],
      );
      expect(score, lessThan(80.0));
    });

    test('resolved reports are ignored', () {
      final score = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(severity: IncidentSeverity.critical, resolved: true)],
      );
      expect(score, 80.0);
    });

    test('reports older than the max age are ignored', () {
      final score = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [
          _report(
            severity: IncidentSeverity.critical,
            reportedAt: DateTime.now().subtract(const Duration(days: 200)),
          ),
        ],
      );
      expect(score, 80.0);
    });

    test('a critical report hurts the score more than a low-severity one', () {
      final reportedAt = DateTime.now().subtract(const Duration(days: 5));
      final criticalScore = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(severity: IncidentSeverity.critical, reportedAt: reportedAt)],
      );
      final lowScore = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(severity: IncidentSeverity.low, reportedAt: reportedAt)],
      );
      expect(criticalScore, lessThan(lowScore));
    });

    test('an older report hurts the score less than a fresh one of the same severity', () {
      final freshScore = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(reportedAt: DateTime.now())],
      );
      final oldScore = engine.computeSafetyScore(
        property: _property(),
        nearbyReports: [_report(reportedAt: DateTime.now().subtract(const Duration(days: 60)))],
      );
      expect(oldScore, greaterThan(freshScore));
    });

    test('score is always clamped within [0, 100]', () {
      final manyReports = List.generate(
        20,
        (_) => _report(severity: IncidentSeverity.critical, reporterVerified: true, reporterTrustScore: 100),
      );
      final score = engine.computeSafetyScore(property: _property(), nearbyReports: manyReports);
      expect(score, inInclusiveRange(0.0, 100.0));
    });
  });

  group('SafetyEngine.countActiveIncidents', () {
    test('counts only unresolved, recent reports', () {
      final reports = [
        _report(resolved: false),
        _report(resolved: true),
        _report(reportedAt: DateTime.now().subtract(const Duration(days: 200))),
      ];
      expect(engine.countActiveIncidents(property: _property(), nearbyReports: reports), 1);
    });
  });

  group('SafetyEngine.filterNearby', () {
    test('a report at the same coordinates is included', () {
      final results = engine.filterNearby(
        latitude: -6.7924,
        longitude: 39.2083,
        allReports: [_report(latitude: -6.7924, longitude: 39.2083)],
      );
      expect(results, hasLength(1));
    });

    test('a report far outside the radius is excluded', () {
      // Dodoma is roughly 350km from Dar es Salaam — well outside any
      // reasonable neighbourhood radius.
      final results = engine.filterNearby(
        latitude: -6.7924,
        longitude: 39.2083,
        allReports: [_report(latitude: -6.1630, longitude: 35.7516)],
        radiusKm: 5,
      );
      expect(results, isEmpty);
    });
  });
}
