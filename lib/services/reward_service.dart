import 'dart:developer' show log;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/reward_model.dart';

/// Awards HTN reward points for user actions.
class RewardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _rewards => _db.collection('rewards');
  CollectionReference get _users => _db.collection('users');

  Future<void> awardListingBonus(String userId) async {
    await _createReward(
      userId: userId,
      type: RewardType.listingBonus,
      points: 100,
      description: 'Listed your home during a move',
    );
  }

  Future<void> awardMoveComplete(String userId) async {
    await _createReward(
      userId: userId,
      type: RewardType.moveComplete,
      points: 250,
      description: 'Completed your housing transition',
    );
  }

  Future<void> awardReviewSubmitted(String userId) async {
    await _createReward(
      userId: userId,
      type: RewardType.reviewSubmitted,
      points: 50,
      description: 'Submitted a verified review',
    );
  }

  Future<void> awardReferral(String userId, {String? referredUserName}) async {
    await _createReward(
      userId: userId,
      type: RewardType.referral,
      points: 200,
      description: referredUserName != null
          ? 'Referred $referredUserName to HTN'
          : 'Referred a new user to HTN',
    );
  }

  Future<void> _createReward({
    required String userId,
    required RewardType type,
    required int points,
    required String description,
  }) async {
    final reward = RewardModel(
      id: '',
      userId: userId,
      type: type,
      points: points,
      description: description,
      createdAt: DateTime.now(),
    );

    final ref = await _rewards.add({
      'userId': reward.userId,
      'type': reward.type.name,
      'points': reward.points,
      'description': reward.description,
      'createdAt': Timestamp.fromDate(reward.createdAt),
      'claimed': false,
      'claimedAt': null,
    });

    // Increment user's total points
    await _users.doc(userId).update({
      'totalRewardPoints': FieldValue.increment(points),
    });

    log('🏆 Reward created: ${type.name} +$points pts → $userId (doc: ${ref.id})');
  }
}
