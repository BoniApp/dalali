import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/reward_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/providers/user_state.dart';

/// Reward points. Mirrors earned points onto the signed-in user's
/// profile via [UserState.addRewardPoints] — pass the same UserState
/// instance in via [attachUserState] (wired in main.dart).
class RewardState extends ChangeNotifier {
  List<RewardModel> _rewards = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;
  UserModel? _currentUser;
  UserState? _userState;

  void attachUserState(UserState userState) {
    _userState = userState;
  }

  List<RewardModel> get rewards => _rewards;

  List<RewardModel> myRewardsFor(String? userId) {
    if (userId == null) return [];
    return _rewards.where((r) => r.userId == userId).toList();
  }

  int myTotalPointsFor(String? userId) {
    if (userId == null) return 0;
    return _rewards.where((r) => r.userId == userId && r.claimed).fold(0, (sum, r) => sum + r.points);
  }

  void addReward(RewardModel reward) {
    _rewards.add(reward);
    _userState?.addRewardPoints(reward.userId, reward.points);
    notifyListeners();
  }

  void claimReward(String rewardId) {
    final idx = _rewards.indexWhere((r) => r.id == rewardId);
    if (idx >= 0 && !_rewards[idx].claimed) {
      _rewards[idx] = _rewards[idx].copyWith(claimed: true, claimedAt: DateTime.now());
      notifyListeners();
    }
  }

  void _unsubscribe() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  void _subscribe(UserModel user) {
    _subscriptions.add(_data.getRewardsForUser(user.id).listen((list) {
      _rewards = list.cast<RewardModel>();
      notifyListeners();
    }));
  }

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _currentUser = user;
    _unsubscribe();
    if (user == null) {
      _rewards = [];
      notifyListeners();
      return;
    }
    _subscribe(user);
  }

  /// Re-fetch by re-subscribing (pull-to-refresh). Completes once fresh
  /// data has been delivered (5s timeout fallback so the spinner never
  /// hangs); a no-op when no user is signed in.
  Future<void> refreshData() async {
    final user = _currentUser;
    if (user == null) return;
    final delivered = Completer<void>();
    final probe = _data.getRewardsForUser(user.id).listen((_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onError: (_) {
      if (!delivered.isCompleted) delivered.complete();
    }, onDone: () {
      if (!delivered.isCompleted) delivered.complete();
    });
    _unsubscribe();
    _subscribe(user);
    await delivered.future.timeout(const Duration(seconds: 5), onTimeout: () {});
    await probe.cancel();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
