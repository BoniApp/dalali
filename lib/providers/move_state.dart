import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/move_listing_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/providers/user_state.dart';

/// The move engine: a user's move listing (their current home, while
/// they search) and its lifecycle. Also mirrors moveMode onto the
/// signed-in user's profile via [UserState.applyMoveMode] — pass the
/// same UserState instance in via [attachUserState] (wired in
/// main.dart's ChangeNotifierProxyProvider).
class MoveState extends ChangeNotifier {
  List<MoveListingModel> _moveListings = [];

  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];
  String? _lastUserId;
  UserModel? _currentUser;
  UserState? _userState;

  void attachUserState(UserState userState) {
    _userState = userState;
  }

  List<MoveListingModel> get moveListings => _moveListings;

  List<MoveListingModel> get activeMoveListings =>
      _moveListings.where((m) => m.status == MoveStatus.planning || m.status == MoveStatus.active).toList();

  List<MoveListingModel> myMoveListingsFor(String? userId) {
    if (userId == null) return [];
    return _moveListings.where((m) => m.userId == userId).toList();
  }

  void startMove(MoveListingModel move) {
    _moveListings.add(move);
    _userState?.applyMoveMode(MoveMode.planning, activeMoveListingId: move.id);
    notifyListeners();
  }

  void activateMove(String moveId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(status: MoveStatus.active);
      _userState?.applyMoveMode(MoveMode.active);
      notifyListeners();
    }
  }

  void completeMove(String moveId, String newPropertyId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(status: MoveStatus.completed, newPropertyId: newPropertyId);
      _userState?.applyMoveMode(MoveMode.none, activeMoveListingId: null);
      notifyListeners();
    }
  }

  void cancelMove(String moveId) {
    final idx = _moveListings.indexWhere((m) => m.id == moveId);
    if (idx >= 0) {
      _moveListings[idx] = _moveListings[idx].copyWith(status: MoveStatus.cancelled);
      _userState?.applyMoveMode(MoveMode.none, activeMoveListingId: null);
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
    _subscriptions.add(_data.getMoveListingsByUser(user.id).listen((list) {
      _moveListings = list.cast<MoveListingModel>();
      notifyListeners();
    }));
  }

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _currentUser = user;
    _unsubscribe();
    if (user == null) {
      _moveListings = [];
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
    final probe = _data.getMoveListingsByUser(user.id).listen((_) {
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
