import 'dart:math';
import 'package:dalali/models/kyc/verification_result_model.dart';

/// ═══════════════════════════════════════════════════════════════
/// AML SCREENING SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Local sanctions / PEP list screening with fuzzy name matching.
/// In production, maintain a nightly-synced SQLite database of:
///   • UN Tanzania Consolidated Sanctions
///   • BoT Terrorism List
///   • FIU Advisory Notices
///
class AmlScreeningService {
  static final List<String> _localSanctionsList = [
    // Placeholder: loaded from nightly sync
    // 'SOME SANCTIONED INDIVIDUAL',
  ];

  /// Screen a name against local sanctions lists.
  Future<VerificationResultModel> screenName({
    required String fullName,
    required String? dateOfBirth,
    required String sessionId,
  }) async {
    final normalized = fullName.toUpperCase().trim();
    final flags = <String>[];
    RiskLevel risk = RiskLevel.low;

    // Exact match check
    for (final entry in _localSanctionsList) {
      if (entry.toUpperCase() == normalized) {
        flags.add('SANCTIONS_EXACT_MATCH');
        risk = RiskLevel.critical;
        break;
      }
    }

    // Fuzzy match (Levenshtein distance <= 2 for names > 5 chars)
    if (risk != RiskLevel.critical) {
      for (final entry in _localSanctionsList) {
        if (_levenshtein(normalized, entry.toUpperCase()) <= 2 && normalized.length > 5) {
          flags.add('SANCTIONS_FUZZY_MATCH');
          risk = RiskLevel.high;
          break;
        }
      }
    }

    // Device / geo anomaly (stub)
    // In production: check if IP is from high-risk jurisdiction,
    // if device is emulated, if location is inconsistent with TZ

    return VerificationResultModel(
      resultId: 'aml_${DateTime.now().millisecondsSinceEpoch}',
      sessionId: sessionId,
      source: 'sanctions_list',
      outcome: flags.isEmpty ? VerificationOutcome.match : VerificationOutcome.mismatch,
      assessedRisk: risk,
      flags: flags,
      checkedAt: DateTime.now(),
    );
  }

  /// Compute overall risk score from multiple results.
  RiskLevel aggregateRisk(List<VerificationResultModel> results) {
    RiskLevel maxRisk = RiskLevel.low;
    for (final r in results) {
      if (r.assessedRisk != null && r.assessedRisk!.index > maxRisk.index) {
        maxRisk = r.assessedRisk!;
      }
    }
    return maxRisk;
  }

  int _levenshtein(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    final v0 = List<int>.filled(t.length + 1, 0);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i <= t.length; i++) {
      v0[i] = i;
    }

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = (s[i] == t[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= t.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[t.length];
  }
}
