import 'dart:developer' show log;
import 'package:dalali/models/neighbourhood_report_model.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Handles report submission with anti-spam / rate-limiting logic.
class ReportService {
  final _db = SupabaseService.client;

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

    // 3. Write to database
    final data = await _db.from('neighbourhood_reports').insert({
      'reporter_id': report.reporterId,
      'reporter_name': report.reporterName,
      'reporter_verified': report.reporterVerified,
      'reporter_trust_score': report.reporterTrustScore,
      'type': report.type.name,
      'severity': report.severity.name,
      'location': report.location,
      'latitude': report.latitude,
      'longitude': report.longitude,
      'description': report.description,
      'reported_at': report.reportedAt.toIso8601String(),
      'resolved': false,
    }).select('id').single();

    final id = data['id'] as String;
    log('🚨 Report submitted: $id by ${user.id}');
    return id;
  }

  /// Mark a report as resolved (agents/admins only in production).
  Future<void> resolveReport(String reportId, String resolverId) async {
    await _db.from('neighbourhood_reports').update({
      'resolved': true,
      'resolved_at': DateTime.now().toIso8601String(),
      'resolved_by': resolverId,
    }).eq('id', reportId);
    log('✅ Report resolved: $reportId by $resolverId');
  }

  // ─── Rate Limiting ──────────────────────────────────────────

  Future<void> _enforceRateLimit(String userId) async {
    final now = DateTime.now();
    final dayAgo = now.subtract(const Duration(days: 1)).toIso8601String();

    final recent = await _db
        .from('neighbourhood_reports')
        .select()
        .eq('reporter_id', userId)
        .gte('reported_at', dayAgo);

    if (recent.length >= _maxDailyReports) {
      throw Exception('Daily report limit reached ($_maxDailyReports/day).');
    }

    // Check cooldown
    if (recent.isNotEmpty) {
      final latestStr = recent.first['reported_at'] as String?;
      if (latestStr != null) {
        final latest = DateTime.parse(latestStr);
        final minutesSince = now.difference(latest).inMinutes;
        if (minutesSince < _cooldownMinutes) {
          throw Exception(
            'Please wait ${_cooldownMinutes - minutesSince} minutes before reporting again.',
          );
        }
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
