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

  void onUserChanged(UserModel? user) {
    if (user?.id == _lastUserId) return;
    _lastUserId = user?.id;
    _unsubscribe();
    if (user == null) {
      _moveListings = [];
      notifyListeners();
      return;
    }
    _subscriptions.add(_data.getMoveListingsByUser(user.id).listen((list) {
      _moveListings = list.cast<MoveListingModel>();
      notifyListeners();
    }));
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
