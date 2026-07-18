/// ═══════════════════════════════════════════════════════════════
/// REFERRAL LINK MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// A shareable referral code owned by an influencer, optionally
/// tied to a campaign.
///
class ReferralLinkModel {
  final String id;
  final String influencerId;
  final String? campaignId;
  final String code;
  final bool isActive;
  final DateTime createdAt;

  const ReferralLinkModel({
    required this.id,
    required this.influencerId,
    this.campaignId,
    required this.code,
    this.isActive = true,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'influencer_id': influencerId,
        'campaign_id': campaignId,
        'code': code,
        'is_active': isActive,
        'created_at': createdAt.toIso8601String(),
      };

  factory ReferralLinkModel.fromJson(Map<String, dynamic> json) {
    return ReferralLinkModel(
      id: json['id'] ?? '',
      influencerId: json['influencer_id'] ?? '',
      campaignId: json['campaign_id'],
      code: json['code'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
