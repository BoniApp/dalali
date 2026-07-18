enum CampaignStatus { draft, active, paused, ended }
enum CampaignParticipantStatus { joined, removed }

/// ═══════════════════════════════════════════════════════════════
/// CAMPAIGN MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// An admin-run marketing campaign that influencers can join.
///
class CampaignModel {
  final String id;
  final String name;
  final String description;
  final double budget;
  final DateTime? startDate;
  final DateTime? endDate;
  final String targetAudience;
  final Map<String, dynamic>? commissionRules;
  final CampaignStatus status;
  final String? createdBy;
  final DateTime createdAt;

  const CampaignModel({
    required this.id,
    required this.name,
    this.description = '',
    this.budget = 0,
    this.startDate,
    this.endDate,
    this.targetAudience = '',
    this.commissionRules,
    this.status = CampaignStatus.draft,
    this.createdBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'budget': budget,
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'target_audience': targetAudience,
        'commission_rules': commissionRules,
        'status': status.name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
      };

  factory CampaignModel.fromJson(Map<String, dynamic> json) {
    return CampaignModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'])
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'])
          : null,
      targetAudience: json['target_audience'] ?? '',
      commissionRules: json['commission_rules'] != null
          ? Map<String, dynamic>.from(json['commission_rules'])
          : null,
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CampaignStatus.draft,
      ),
      createdBy: json['created_by'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════
/// CAMPAIGN PARTICIPANT MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Join row between a campaign and an influencer.
///
class CampaignParticipantModel {
  final String campaignId;
  final String influencerId;
  final CampaignParticipantStatus status;
  final DateTime joinedAt;

  const CampaignParticipantModel({
    required this.campaignId,
    required this.influencerId,
    this.status = CampaignParticipantStatus.joined,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'campaign_id': campaignId,
        'influencer_id': influencerId,
        'status': status.name,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory CampaignParticipantModel.fromJson(Map<String, dynamic> json) {
    return CampaignParticipantModel(
      campaignId: json['campaign_id'] ?? '',
      influencerId: json['influencer_id'] ?? '',
      status: CampaignParticipantStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => CampaignParticipantStatus.joined,
      ),
      joinedAt: DateTime.tryParse(json['joined_at'] ?? '') ?? DateTime.now(),
    );
  }
}
