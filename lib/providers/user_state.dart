import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/influencer/influencer_model.dart';
import 'package:dalali/services/data_service.dart';
import 'package:dalali/services/auth_service.dart';
import 'package:dalali/services/fcm_service.dart';
import 'package:dalali/services/influencer/influencer_service.dart';

/// Who-am-I state: the signed-in user (or guest), their influencer
/// profile, and auth lifecycle. Other domain providers (PropertyState,
/// TenancyState, etc.) watch this via ChangeNotifierProxyProvider and
/// (re)subscribe their own per-user data when [currentUser] or
/// [isGuestMode] actually changes — see main.dart's MultiProvider.
class UserState extends ChangeNotifier {
  UserModel? currentUser;
  InfluencerModel? influencerProfile;

  final AuthService _authService = AuthService();
  final DataService _data = DataService();
  final List<StreamSubscription> _subscriptions = [];

  // Guest-first browsing: set by RoleSelectionScreen's "Continue as
  // Guest" entry point. Lets an unauthenticated visitor see the public
  // property feed before ever signing up; every mutating method across
  // every provider still no-ops without currentUser, so this is a UX
  // signal only, not a security gate.
  bool _isGuestMode = false;
  bool get isGuestMode => _isGuestMode;

  void enterGuestMode() {
    if (_isGuestMode || currentUser != null) return;
    _isGuestMode = true;
    notifyListeners();
  }

  UserState() {
    _authService.authStateChanges.listen((AuthState state) async {
      final user = state.session?.user;
      if (user == null) {
        // Server-side sign-out (logout, token revocation/expiry,
        // account deletion): drop all local session state so the app
        // returns to the logged-out UI instead of running queries
        // with a dead session.
        if (currentUser != null || influencerProfile != null || _isGuestMode) {
          _unsubscribeInfluencerProfile();
          currentUser = null;
          influencerProfile = null;
          _isGuestMode = false;
          notifyListeners();
        }
        return;
      }
      final userDoc = await _data.getUserById(user.id);
      if (userDoc != null) {
        currentUser = userDoc;
      } else {
        currentUser = UserModel(
          id: user.id,
          fullName: user.userMetadata?['full_name'] ?? 'User',
          email: user.email ?? '',
          phone: user.phone ?? '',
          role: UserRole.seeker,
          createdAt: DateTime.now(),
        );
      }
      _isGuestMode = false;
      try {
        influencerProfile = await InfluencerService().getInfluencerProfile(currentUser!.id);
      } catch (e) {
        debugPrint('getInfluencerProfile error: $e');
        influencerProfile = null;
      }
      _subscribeInfluencerProfile();
      notifyListeners();
    });
  }

  void _subscribeInfluencerProfile() {
    _unsubscribeInfluencerProfile();
    if (currentUser == null) return;
    if (currentUser!.role == UserRole.influencer || influencerProfile != null) {
      _subscriptions.add(InfluencerService().watchInfluencerProfile(currentUser!.id).listen((profile) {
        influencerProfile = profile;
        notifyListeners();
      }));
    }
  }

  void _unsubscribeInfluencerProfile() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  /// Persists a new profile picture URL and refreshes the local user.
  Future<void> updateProfileImage(String imageUrl) async {
    final user = currentUser;
    if (user == null) return;
    await _data.updateUserProfileImage(user.id, imageUrl);
    currentUser = user.copyWith(profileImage: imageUrl);
    notifyListeners();
  }

  /// Re-fetches the current user row — e.g. after the server updates
  /// verification_status during KYC completion.
  Future<void> refreshCurrentUser() async {
    final user = currentUser;
    if (user == null) return;
    final fresh = await _data.getUserById(user.id);
    if (fresh != null) {
      currentUser = fresh;
      notifyListeners();
    }
  }

  /// Called by MoveState when starting/advancing/ending a move — the
  /// move lifecycle also mirrors a mode flag onto the user profile.
  void applyMoveMode(MoveMode mode, {String? activeMoveListingId}) {
    final user = currentUser;
    if (user == null) return;
    currentUser = user.copyWith(moveMode: mode, activeMoveListingId: activeMoveListingId);
    notifyListeners();
  }

  /// Called by RewardState when a reward is earned by the current user.
  void addRewardPoints(String userId, int points) {
    final user = currentUser;
    if (user == null || user.id != userId) return;
    currentUser = user.copyWith(totalRewardPoints: user.totalRewardPoints + points);
    notifyListeners();
  }

  Future<void> logout() async {
    // Clear the device push token BEFORE sign-out, while the JWT is
    // still valid — after signOut the users update is rejected and
    // this device would keep receiving the previous user's pushes.
    await FcmService.clearToken();
    await _authService.signOut();
    _unsubscribeInfluencerProfile();
    currentUser = null;
    influencerProfile = null;
    _isGuestMode = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _unsubscribeInfluencerProfile();
    super.dispose();
  }
}
