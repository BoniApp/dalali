import 'package:flutter/foundation.dart';
import 'package:dalali/models/influencer/influencer_model.dart';
import 'package:dalali/models/influencer/influencer_application_model.dart';
import 'package:dalali/models/influencer/referral_link_model.dart';
import 'package:dalali/models/influencer/referral_conversion_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// INFLUENCER SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Client-side access to the Influencer Partnership system:
/// applications, influencer profile, referral links, conversions,
/// and referral-code attribution at registration.
///
/// ⚠️ Counters (clicks/registrations/conversions/earnings), status
/// and referral codes are server-managed — this service never
/// writes them. Commissions are credited server-side via Edge
/// Functions into `wallets` / `earnings`.
///
class InfluencerService {
  late final _db = SupabaseService.client;

  // ─── APPLICATIONS ───────────────────────────────────────────

  /// Submit a new influencer program application (status: pending).
  Future<void> submitApplication(InfluencerApplicationModel app) async {
    await _db.from('influencer_applications').insert(app.toJson());
  }

  /// Watch the current user's application (null when none exists).
  Stream<InfluencerApplicationModel?> watchMyApplication(String userId) {
    return _db
        .from('influencer_applications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) =>
            rows.isEmpty ? null : InfluencerApplicationModel.fromJson(rows.first));
  }

  /// Fetch the current user's application once (null when none exists).
  Future<InfluencerApplicationModel?> getMyApplication(String userId) async {
    final data = await _db
        .from('influencer_applications')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return InfluencerApplicationModel.fromJson(data);
  }

  // ─── INFLUENCER PROFILE ─────────────────────────────────────

  /// Watch the influencer profile for [userId] (null when not an influencer).
  Stream<InfluencerModel?> watchInfluencerProfile(String userId) {
    return _db
        .from('influencers')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) => rows.isEmpty ? null : InfluencerModel.fromJson(rows.first));
  }

  /// Fetch the influencer profile for [userId] once.
  Future<InfluencerModel?> getInfluencerProfile(String userId) async {
    final data = await _db
        .from('influencers')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return InfluencerModel.fromJson(data);
  }

  // ─── CONVERSIONS & LINKS ────────────────────────────────────

  /// Conversions attributed to this influencer, newest first.
  Stream<List<ReferralConversionModel>> getMyConversions(String userId) {
    return _db
        .from('referral_conversions')
        .stream(primaryKey: ['id'])
        .eq('influencer_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(ReferralConversionModel.fromJson).toList());
  }

  /// Referral links owned by this influencer.
  Stream<List<ReferralLinkModel>> getMyLinks(String userId) {
    return _db
        .from('referral_links')
        .stream(primaryKey: ['id'])
        .eq('influencer_id', userId)
        .map((rows) => rows.map(ReferralLinkModel.fromJson).toList());
  }

  // ─── REFERRAL ATTRIBUTION ───────────────────────────────────

  /// Attribute a newly registered user to a referral code.
  ///
  /// Records a referral click and a zero-amount 'registration'
  /// conversion. Idempotent: a duplicate attribution still returns
  /// true. Never throws — returns false on unexpected errors so the
  /// registration flow is never blocked.
  Future<bool> applyReferralCode({
    required String code,
    required String userId,
  }) async {
    try {
      final normalized = code.trim().toUpperCase();
      if (normalized.isEmpty) return false;

      final data = await _db
          .from('referral_links')
          .select()
          .eq('code', normalized)
          .eq('is_active', true)
          .maybeSingle();
      if (data == null) return false;
      final link = ReferralLinkModel.fromJson(data);

      await _db.from('referral_clicks').insert({
        'link_id': link.id,
        'code': normalized,
        'source': 'registration',
        'referred_user_id': userId,
      });

      await _db.from('referral_conversions').insert({
        'influencer_id': link.influencerId,
        'link_id': link.id,
        'referred_user_id': userId,
        'conversion_type': 'registration',
        'commission_amount': 0,
        'status': 'pending',
      });

      return true;
    } catch (e) {
      // Duplicate/conflict (already attributed) — treat as success.
      final msg = e.toString();
      if (msg.contains('duplicate') || msg.contains('23505') || msg.contains('409')) {
        return true;
      }
      debugPrint('applyReferralCode error: $e');
      return false;
    }
  }

  /// Full shareable URL for a referral code.
  String buildReferralUrl(String code) => 'https://dalaliapp.com/ref/$code';
}
