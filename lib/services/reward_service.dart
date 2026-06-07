import 'dart:developer' show log;
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// Awards HTN reward points for user actions.
class RewardService {
  final _db = SupabaseService.client;

  Future<void> awardListingBonus(String userId) async {
    await createReward(
      userId: userId,
      type: RewardType.listingBonus,
      points: 100,
      description: 'Listed your home during a move',
    );
  }

  Future<void> awardMoveComplete(String userId) async {
    await createReward(
      userId: userId,
      type: RewardType.moveComplete,
      points: 250,
      description: 'Completed your housing transition',
    );
  }

  Future<void> awardReviewSubmitted(String userId) async {
    await createReward(
      userId: userId,
      type: RewardType.reviewSubmitted,
      points: 50,
      description: 'Submitted a verified review',
    );
  }

  Future<void> awardReferral(String userId, {String? referredUserName}) async {
    await createReward(
      userId: userId,
      type: RewardType.referral,
      points: 200,
      description: referredUserName != null
          ? 'Referred $referredUserName to Dalali'
          : 'Referred a new user to Dalali',
    );
  }

  Future<void> createReward({
    required String userId,
    required RewardType type,
    required int points,
    required String description,
  }) async {
    await _db.from('rewards').insert({
      'user_id': userId,
      'type': type.name,
      'points': points,
      'description': description,
      'claimed': false,
      'created_at': DateTime.now().toIso8601String(),
    });

    // Increment user's total points
    final user = await _db.from('users').select('total_reward_points').eq('id', userId).maybeSingle();
    final currentPoints = (user?['total_reward_points'] as int?) ?? 0;
    await _db.from('users').update({
      'total_reward_points': currentPoints + points,
    }).eq('id', userId);

    log('🏆 Reward created: ${type.name} +$points pts → $userId');
  }
}
