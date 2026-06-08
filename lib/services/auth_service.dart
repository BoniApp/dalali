import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/services/supabase_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// AUTH SERVICE — Supabase Auth wrapper
///
/// Replaces FirebaseAuthService. Handles sign-in, registration,
/// password reset, and user profile fetching.
/// ═══════════════════════════════════════════════════════════════
class AuthService {
  static final _auth = SupabaseService.client.auth;
  static final _db = SupabaseService.client;

  User? get currentUser => _auth.currentUser;
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  // ─── Sign In ────────────────────────────────────────────────

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        return await _getUserData(result.user!.id);
      }
    } on AuthException catch (e) {
      throw _handleAuthError(e);
    }
    return null;
  }

  // ─── Registration ───────────────────────────────────────────

  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final result = await _auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': role.name},
      );

      if (result.user != null) {
        // Trigger auto-created the user row; update it with full data
        await _db.from('users').update({
          'full_name': fullName,
          'phone': phone,
          'role': role.name,
        }).eq('id', result.user!.id);

        return UserModel(
          id: result.user!.id,
          fullName: fullName,
          email: email,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
        );
      }
    } on AuthException catch (e) {
      throw _handleAuthError(e);
    }
    return null;
  }

  // ─── Sign Out ───────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Password Reset ─────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.resetPasswordForEmail(email);
  }

  // ─── Profile Updates ────────────────────────────────────────

  Future<void> updatePhoneVerification(bool verified) async {
    final uid = SupabaseService.currentUserId;
    if (uid != null) {
      await _db.from('users')
          .update({'is_phone_verified': verified})
          .eq('id', uid);
    }
  }

  Future<void> submitVerification({
    required String nationalId,
    String? agentLicense,
  }) async {
    final uid = SupabaseService.currentUserId;
    if (uid != null) {
      await _db.from('users').update({
        'national_id': nationalId,
        'agent_license': agentLicense,
        'verification_status': 'pending',
      }).eq('id', uid);
    }
  }

  // ─── User Data Fetching ─────────────────────────────────────

  Future<UserModel?> _getUserData(String uid) async {
    final response = await _db
        .from('users')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (response != null) {
      return _userFromJson(response, uid);
    }
    return null;
  }

  // ─── Error Handling ─────────────────────────────────────────

  String _handleAuthError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'Invalid email or password.';
    }
    if (msg.contains('user not found')) {
      return 'No user found with this email.';
    }
    if (msg.contains('email already registered') ||
        msg.contains('user already registered')) {
      return 'An account already exists with this email.';
    }
    if (msg.contains('password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('invalid email')) {
      return 'Invalid email address.';
    }
    return e.message;
  }

  // ─── Serialization ──────────────────────────────────────────

  Map<String, dynamic> _userToJson(UserModel user) {
    return {
      'id': user.id,
      'full_name': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.name,
      'verification_status': user.verificationStatus.name,
      'is_phone_verified': user.isPhoneVerified,
      'profile_image': user.profileImage,
      'created_at': user.createdAt.toIso8601String(),
      'national_id': user.nationalId,
      'agent_license': user.agentLicense,
      'subscription_tier': user.subscriptionTier,
      'is_verified_landlord': user.isVerifiedLandlord,
      'saved_searches': user.savedSearches,
      'preferred_locations': user.preferredLocations,
      'move_mode': user.moveMode.name,
      'active_move_listing_id': user.activeMoveListingId,
      'total_reward_points': user.totalRewardPoints,
    };
  }

  UserModel _userFromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      id: uid,
      fullName: json['full_name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.seeker,
      ),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verification_status'],
        orElse: () => VerificationStatus.unverified,
      ),
      isPhoneVerified: json['is_phone_verified'] ?? false,
      profileImage: json['profile_image'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      nationalId: json['national_id'],
      agentLicense: json['agent_license'],
      subscriptionTier: json['subscription_tier'] ?? 0,
      isVerifiedLandlord: json['is_verified_landlord'] ?? false,
      lastActive: json['last_active'] != null
          ? DateTime.tryParse(json['last_active'])
          : null,
      savedSearches: List<String>.from(json['saved_searches'] ?? []),
      preferredLocations: List<String>.from(json['preferred_locations'] ?? []),
      moveMode: MoveMode.values.firstWhere(
        (e) => e.name == json['move_mode'],
        orElse: () => MoveMode.none,
      ),
      activeMoveListingId: json['active_move_listing_id'],
      totalRewardPoints: json['total_reward_points'] ?? 0,
    );
  }
}
