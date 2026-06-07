import 'dart:developer' show log;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/user_model.dart';

/// Handles report submission with anti-spam / rate-limiting logic.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _reports => _db.collection('neighbourhood_reports');

  /// Max reports per user per day to prevent spam.
  static const int _maxDailyReports = 5;

  /// Cooldown in minutes between reports from the same user.
  static const int _cooldownMinutes = 10;

  /// Submit a new report. Returns the created doc ID or throws on failure.
  Future<String> submitReport({
    required UserModel user,
    required IncidentType type,
    required IncidentSeverity severity,
    required String location,
    required double latitude,
    required double longitude,
    String? description,
  }) async {
    // 1. Rate limit check
    await _enforceRateLimit(user.id);

    // 2. Build report
    final report = NeighbourhoodReportModel(
      id: '',
      reporterId: user.id,
      reporterName: user.fullName,
      reporterVerified: user.verificationStatus == VerificationStatus.verified,
      reporterTrustScore: _computeTrustScore(user),
      type: type,
      severity: severity,
      location: location,
      latitude: latitude,
      longitude: longitude,
      description: description,
      reportedAt: DateTime.now(),
    );

    // 3. Write to Firestore
    final ref = await _reports.add({
      'reporterId': report.reporterId,
      'reporterName': report.reporterName,
      'reporterVerified': report.reporterVerified,
      'reporterTrustScore': report.reporterTrustScore,
      'type': report.type.name,
      'severity': report.severity.name,
      'location': report.location,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'description': report.description,
      'reportedAt': Timestamp.fromDate(report.reportedAt),
      'resolved': false,
      'resolvedAt': null,
      'resolvedBy': null,
    });

    log('🚨 Report submitted: ${ref.id} by ${user.id}');
    return ref.id;
  }

  /// Mark a report as resolved (agents/admins only in production).
  Future<void> resolveReport(String reportId, String resolverId) async {
    await _reports.doc(reportId).update({
      'resolved': true,
      'resolvedAt': FieldValue.serverTimestamp(),
      'resolvedBy': resolverId,
    });
    log('✅ Report resolved: $reportId by $resolverId');
  }

  // ─── Rate Limiting ──────────────────────────────────────────

  Future<void> _enforceRateLimit(String userId) async {
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(days: 1));

    final recent = await _reports
        .where('reporterId', isEqualTo: userId)
        .where('reportedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayAgo))
        .get();

    if (recent.docs.length >= _maxDailyReports) {
      throw Exception('Daily report limit reached ($_maxDailyReports/day).');
    }

    // Check cooldown
    final latest = recent.docs.isNotEmpty
        ? (recent.docs.first.data() as Map<String, dynamic>)['reportedAt'] as Timestamp?
        : null;
    if (latest != null) {
      final minutesSince = now.difference(latest.toDate()).inMinutes;
      if (minutesSince < _cooldownMinutes) {
        throw Exception(
          'Please wait ${_cooldownMinutes - minutesSince} minutes before reporting again.',
        );
      }
    }
  }

  // ─── Trust Score ────────────────────────────────────────────

  int _computeTrustScore(UserModel user) {
    int score = 50; // baseline
    if (user.verificationStatus == VerificationStatus.verified) score += 25;
    if (user.isPhoneVerified) score += 10;
    if (user.isVerifiedLandlord) score += 10;
    if (user.role == UserRole.agent) score += 5;
    return score.clamp(0, 100);
  }
}
