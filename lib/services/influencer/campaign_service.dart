import 'package:dalali/models/influencer/campaign_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// CAMPAIGN SERVICE
/// ═══════════════════════════════════════════════════════════════
///
/// Influencer-facing access to marketing campaigns: browse active
/// campaigns, join them, and track own participations.
/// Campaign creation/management is admin-only.
///
class CampaignService {
  late final _db = SupabaseService.client;

  /// Active campaigns (RLS restricts reads to status = 'active').
  Stream<List<CampaignModel>> getActiveCampaigns() {
    return _db
        .from('campaigns')
        .stream(primaryKey: ['id'])
        .eq('status', 'active')
        .map((rows) => rows.map(CampaignModel.fromJson).toList());
  }

  /// Campaign participations of the given influencer.
  Stream<List<CampaignParticipantModel>> getMyParticipations(String userId) {
    return _db
        .from('campaign_participants')
        .stream(primaryKey: ['campaign_id', 'influencer_id'])
        .eq('influencer_id', userId)
        .map((rows) => rows.map(CampaignParticipantModel.fromJson).toList());
  }

  /// Join an active campaign as the given influencer.
  Future<void> joinCampaign({
    required String campaignId,
    required String userId,
  }) async {
    await _db.from('campaign_participants').insert({
      'campaign_id': campaignId,
      'influencer_id': userId,
      'status': 'joined',
    });
  }
}
