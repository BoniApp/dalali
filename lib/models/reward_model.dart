enum RewardType { listingBonus, referral, moveComplete, reviewSubmitted }

class RewardModel {
  final String id;
  final String userId;
  final RewardType type;
  final int points;
  final String description;
  final DateTime createdAt;
  final bool claimed;
  final DateTime? claimedAt;

  RewardModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.points,
    required this.description,
    required this.createdAt,
    this.claimed = false,
    this.claimedAt,
  });

  RewardModel copyWith({
    String? id,
    String? userId,
    RewardType? type,
    int? points,
    String? description,
    DateTime? createdAt,
    bool? claimed,
    DateTime? claimedAt,
  }) {
    return RewardModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      points: points ?? this.points,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      claimed: claimed ?? this.claimed,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }
}
