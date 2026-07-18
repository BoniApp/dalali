enum InfluencerStatus { pending, active, suspended }

/// ═══════════════════════════════════════════════════════════════
/// INFLUENCER MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// Profile + denormalized stats for an approved influencer.
/// Counters and status are server-managed (anti-tamper trigger);
/// the client only reads them.
///
class InfluencerModel {
  final String userId;
  final String referralCode;
  final InfluencerStatus status;
  final String? tiktokUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final int followersCount;
  final String? contentNiche;
  final String? audienceLocation;
  final int totalClicks;
  final int totalRegistrations;
  final int totalConversions;
  final double totalEarnings;
  final DateTime createdAt;
  final DateTime? activatedAt;

  const InfluencerModel({
    required this.userId,
    required this.referralCode,
    this.status = InfluencerStatus.pending,
    this.tiktokUrl,
    this.instagramUrl,
    this.youtubeUrl,
    this.followersCount = 0,
    this.contentNiche,
    this.audienceLocation,
    this.totalClicks = 0,
    this.totalRegistrations = 0,
    this.totalConversions = 0,
    this.totalEarnings = 0,
    required this.createdAt,
    this.activatedAt,
  });

  bool get isActive => status == InfluencerStatus.active;
  bool get isPending => status == InfluencerStatus.pending;
  bool get isSuspended => status == InfluencerStatus.suspended;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'referral_code': referralCode,
        'status': status.name,
        'tiktok_url': tiktokUrl,
        'instagram_url': instagramUrl,
        'youtube_url': youtubeUrl,
        'followers_count': followersCount,
        'content_niche': contentNiche,
        'audience_location': audienceLocation,
        'total_clicks': totalClicks,
        'total_registrations': totalRegistrations,
        'total_conversions': totalConversions,
        'total_earnings': totalEarnings,
        'created_at': createdAt.toIso8601String(),
        'activated_at': activatedAt?.toIso8601String(),
      };

  factory InfluencerModel.fromJson(Map<String, dynamic> json) {
    return InfluencerModel(
      userId: json['user_id'] ?? '',
      referralCode: json['referral_code'] ?? '',
      status: InfluencerStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InfluencerStatus.pending,
      ),
      tiktokUrl: json['tiktok_url'],
      instagramUrl: json['instagram_url'],
      youtubeUrl: json['youtube_url'],
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      contentNiche: json['content_niche'],
      audienceLocation: json['audience_location'],
      totalClicks: (json['total_clicks'] as num?)?.toInt() ?? 0,
      totalRegistrations: (json['total_registrations'] as num?)?.toInt() ?? 0,
      totalConversions: (json['total_conversions'] as num?)?.toInt() ?? 0,
      totalEarnings: (json['total_earnings'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      activatedAt: json['activated_at'] != null
          ? DateTime.tryParse(json['activated_at'])
          : null,
    );
  }

  InfluencerModel copyWith({
    String? tiktokUrl,
    String? instagramUrl,
    String? youtubeUrl,
    int? followersCount,
    String? contentNiche,
    String? audienceLocation,
  }) {
    return InfluencerModel(
      userId: userId,
      referralCode: referralCode,
      status: status,
      tiktokUrl: tiktokUrl ?? this.tiktokUrl,
      instagramUrl: instagramUrl ?? this.instagramUrl,
      youtubeUrl: youtubeUrl ?? this.youtubeUrl,
      followersCount: followersCount ?? this.followersCount,
      contentNiche: contentNiche ?? this.contentNiche,
      audienceLocation: audienceLocation ?? this.audienceLocation,
      totalClicks: totalClicks,
      totalRegistrations: totalRegistrations,
      totalConversions: totalConversions,
      totalEarnings: totalEarnings,
      createdAt: createdAt,
      activatedAt: activatedAt,
    );
  }
}
