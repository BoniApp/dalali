enum InfluencerApplicationStatus { pending, approved, rejected }

/// ═══════════════════════════════════════════════════════════════
/// INFLUENCER APPLICATION MODEL
/// ═══════════════════════════════════════════════════════════════
///
/// A user's application to join the influencer program. Insert-only
/// for clients (one per user); review happens admin-side.
///
class InfluencerApplicationModel {
  final String id;
  final String userId;
  final String fullName;
  final String phone;
  final String email;
  final String? tiktokUrl;
  final String? instagramUrl;
  final String? youtubeUrl;
  final int followersCount;
  final String? contentNiche;
  final String? audienceLocation;
  final InfluencerApplicationStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;
  final DateTime createdAt;

  const InfluencerApplicationModel({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.phone,
    required this.email,
    this.tiktokUrl,
    this.instagramUrl,
    this.youtubeUrl,
    this.followersCount = 0,
    this.contentNiche,
    this.audienceLocation,
    this.status = InfluencerApplicationStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'tiktok_url': tiktokUrl,
        'instagram_url': instagramUrl,
        'youtube_url': youtubeUrl,
        'followers_count': followersCount,
        'content_niche': contentNiche,
        'audience_location': audienceLocation,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };

  factory InfluencerApplicationModel.fromJson(Map<String, dynamic> json) {
    return InfluencerApplicationModel(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      tiktokUrl: json['tiktok_url'],
      instagramUrl: json['instagram_url'],
      youtubeUrl: json['youtube_url'],
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      contentNiche: json['content_niche'],
      audienceLocation: json['audience_location'],
      status: InfluencerApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => InfluencerApplicationStatus.pending,
      ),
      reviewedBy: json['reviewed_by'],
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'])
          : null,
      rejectionReason: json['rejection_reason'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}
