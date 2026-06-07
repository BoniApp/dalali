import 'package:dalali/models/user_preferences_model.dart';

enum UserRole { seeker, landlord, agent }
enum VerificationStatus { unverified, pending, verified }
enum MoveMode { none, planning, active }

class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final UserRole role;
  final VerificationStatus verificationStatus;
  final bool isPhoneVerified;
  final String? profileImage;
  final DateTime createdAt;
  final String? nationalId;
  final String? agentLicense;
  final int? subscriptionTier; // 0 = Basic, 1 = Premium

  // ═══ Scaling fields ════════════════════════════════════════
  final bool isVerifiedLandlord;
  final DateTime? lastActive;
  final List<String> savedSearches;
  final List<String> preferredLocations;

  // ═══ HTN Move Mode ════════════════════════════════════════
  final MoveMode moveMode;
  final String? activeMoveListingId;
  final int totalRewardPoints;
  final UserPreferencesModel preferences;

  UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    this.verificationStatus = VerificationStatus.unverified,
    this.isPhoneVerified = false,
    this.profileImage,
    required this.createdAt,
    this.nationalId,
    this.agentLicense,
    this.subscriptionTier = 0,
    this.isVerifiedLandlord = false,
    this.lastActive,
    this.savedSearches = const [],
    this.preferredLocations = const [],
    this.moveMode = MoveMode.none,
    this.activeMoveListingId,
    this.totalRewardPoints = 0,
    this.preferences = const UserPreferencesModel(),
  });

  bool get isMoving => moveMode != MoveMode.none;
  bool get canListDuringMove => moveMode == MoveMode.active || moveMode == MoveMode.planning;

  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    UserRole? role,
    VerificationStatus? verificationStatus,
    bool? isPhoneVerified,
    String? profileImage,
    DateTime? createdAt,
    String? nationalId,
    String? agentLicense,
    int? subscriptionTier,
    bool? isVerifiedLandlord,
    DateTime? lastActive,
    List<String>? savedSearches,
    List<String>? preferredLocations,
    MoveMode? moveMode,
    String? activeMoveListingId,
    int? totalRewardPoints,
    UserPreferencesModel? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      isPhoneVerified: isPhoneVerified ?? this.isPhoneVerified,
      profileImage: profileImage ?? this.profileImage,
      createdAt: createdAt ?? this.createdAt,
      nationalId: nationalId ?? this.nationalId,
      agentLicense: agentLicense ?? this.agentLicense,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      isVerifiedLandlord: isVerifiedLandlord ?? this.isVerifiedLandlord,
      lastActive: lastActive ?? this.lastActive,
      savedSearches: savedSearches ?? this.savedSearches,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      moveMode: moveMode ?? this.moveMode,
      activeMoveListingId: activeMoveListingId ?? this.activeMoveListingId,
      totalRewardPoints: totalRewardPoints ?? this.totalRewardPoints,
      preferences: preferences ?? this.preferences,
    );
  }
}
