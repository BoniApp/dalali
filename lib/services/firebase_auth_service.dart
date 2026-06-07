import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/models/user_preferences_model.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (result.user != null) {
        return await _getUserData(result.user!.uid);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
    return null;
  }

  Future<UserModel?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required UserRole role,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await result.user!.updateDisplayName(fullName);

        final userModel = UserModel(
          id: result.user!.uid,
          fullName: fullName,
          email: email,
          phone: phone,
          role: role,
          createdAt: DateTime.now(),
        );

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(_userToJson(userModel));

        return userModel;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
    return null;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> updatePhoneVerification(bool verified) async {
    final user = currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'isPhoneVerified': verified,
      });
    }
  }

  Future<void> submitVerification({
    required String nationalId,
    String? agentLicense,
  }) async {
    final user = currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'nationalId': nationalId,
        'agentLicense': agentLicense,
        'verificationStatus': 'pending',
      });
    }
  }

  Future<UserModel?> _getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return _userFromJson(doc.data()!, uid);
    }
    return null;
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Wrong password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }

  Map<String, dynamic> _userToJson(UserModel user) {
    return {
      'fullName': user.fullName,
      'email': user.email,
      'phone': user.phone,
      'role': user.role.name,
      'verificationStatus': user.verificationStatus.name,
      'isPhoneVerified': user.isPhoneVerified,
      'profileImage': user.profileImage,
      'createdAt': Timestamp.fromDate(user.createdAt),
      'nationalId': user.nationalId,
      'agentLicense': user.agentLicense,
      'subscriptionTier': user.subscriptionTier,
      'preferences': user.preferences.toJson(),
    };
  }

  UserModel _userFromJson(Map<String, dynamic> json, String uid) {
    return UserModel(
      id: uid,
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => UserRole.seeker,
      ),
      verificationStatus: VerificationStatus.values.firstWhere(
        (e) => e.name == json['verificationStatus'],
        orElse: () => VerificationStatus.unverified,
      ),
      isPhoneVerified: json['isPhoneVerified'] ?? false,
      profileImage: json['profileImage'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      nationalId: json['nationalId'],
      agentLicense: json['agentLicense'],
      subscriptionTier: json['subscriptionTier'] ?? 0,
      preferences: json['preferences'] != null
          ? UserPreferencesModel.fromJson(json['preferences'] as Map<String, dynamic>)
          : const UserPreferencesModel(),
    );
  }
}
