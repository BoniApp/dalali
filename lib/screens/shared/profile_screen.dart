import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/services/storage_service.dart';
import 'package:dalali/widgets/verification_badge.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/move/move_dashboard_screen.dart';
import 'package:dalali/screens/wallet/wallet_screen.dart';
import 'package:dalali/screens/shared/settings_screen.dart';
import 'package:dalali/screens/tenancy/my_tenancies_screen.dart';
import 'package:dalali/screens/tenancy/reservation_requests_screen.dart';
import 'package:dalali/screens/influencer/influencer_application_screen.dart';
import 'package:dalali/screens/influencer/influencer_dashboard_screen.dart';
import 'package:dalali/screens/kyc/kyc_gate_screen.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final influencerProfile = context.watch<AppState>().influencerProfile;
    final l10n = AppLocalizations.of(context)!;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.profile),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(l10n.notLoggedIn, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(l10n.signIn),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profile),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _changeProfilePicture(context),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.primary.withAlpha(26),
                    backgroundImage:
                        user.profileImage != null && user.profileImage!.isNotEmpty
                            ? NetworkImage(user.profileImage!)
                            : null,
                    child: user.profileImage == null || user.profileImage!.isEmpty
                        ? Text(
                            user.fullName.isNotEmpty ? user.fullName.substring(0, 1) : '?',
                            style: const TextStyle(fontSize: 36, color: AppTheme.primary),
                          )
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(user.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                VerificationBadge(status: user.verificationStatus),
                const SizedBox(width: 8),
                Text(
                  user.verificationStatus == VerificationStatus.verified
                      ? l10n.verifiedAccount
                      : user.verificationStatus == VerificationStatus.pending
                          ? l10n.verificationPending
                          : l10n.unverifiedAccount,
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                if (user.isVerifiedLandlord)
                  _TrustBadge(icon: Icons.verified_user, label: l10n.trustBadgeVerifiedLandlord, color: Colors.green),
                if (user.isVerifiedAgent)
                  _TrustBadge(icon: Icons.support_agent, label: l10n.trustBadgeVerifiedAgent, color: Colors.purple),
                if (user.isVerifiedProperty)
                  _TrustBadge(icon: Icons.home_work, label: l10n.trustBadgeVerifiedProperty, color: Colors.blue),
                if (user.isVerifiedListingCreator)
                  _TrustBadge(icon: Icons.add_home, label: l10n.trustBadgeVerifiedCreator, color: AppTheme.primary),
              ],
            ),
            const SizedBox(height: 16),
            // Wallet Card
            Card(
              color: AppTheme.primary.withAlpha(13),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppTheme.primary.withAlpha(26), shape: BoxShape.circle),
                  child: Icon(Icons.account_balance_wallet, color: AppTheme.primaryDark),
                ),
                title: const Text('My Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Balance, transactions & withdrawals'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const WalletScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Influencer Program Card
            Card(
              color: Colors.pink.shade50,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.pink.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.star, color: Colors.pink.shade800),
                ),
                title: Text(l10n.influencerProgram, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  influencerProfile == null
                      ? l10n.applyToEarnCommissions
                      : influencerProfile.isActive
                          ? '${l10n.yourReferralCode}: ${influencerProfile.referralCode}'
                          : l10n.applicationUnderReview,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => influencerProfile != null && influencerProfile.isActive
                        ? const InfluencerDashboardScreen()
                        : const InfluencerApplicationScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Settings Card
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                  child: Icon(Icons.settings, color: Colors.grey.shade800),
                ),
                title: Text(l10n.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.settingsSubtitle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Tenancy Card
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.indigo.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.home_work, color: Colors.indigo.shade800),
                ),
                title: const Text('My Tenancies', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Active leases & agreements'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyTenanciesScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.purple.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.assignment, color: Colors.purple.shade800),
                ),
                title: const Text('Reservations', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  user.role == UserRole.seeker
                      ? 'Applications you\'ve sent'
                      : 'Requests awaiting your approval',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReservationRequestsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // HTN Rewards Card
            Card(
              color: Colors.amber.shade50,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.amber.shade100, shape: BoxShape.circle),
                  child: Icon(Icons.emoji_events, color: Colors.amber.shade800),
                ),
                title: Text(l10n.rewardPoints, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(l10n.pointsEarned(user.totalRewardPoints)),
                trailing: Chip(
                  label: Text(l10n.pendingCount(context.watch<AppState>().myRewards.where((r) => !r.claimed).length)),
                  backgroundColor: Colors.amber.shade100,
                  labelStyle: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  _ProfileTile(icon: Icons.email, label: l10n.email, value: user.email),
                  const Divider(height: 1),
                  _ProfileTile(icon: Icons.phone, label: l10n.phone, value: user.phone),
                  const Divider(height: 1),
                  _ProfileTile(
                    icon: Icons.person_outline,
                    label: l10n.role,
                    value: user.role.name[0].toUpperCase() + user.role.name.substring(1),
                  ),
                  if (user.nationalId != null) ...[
                    const Divider(height: 1),
                    _ProfileTile(icon: Icons.badge, label: l10n.nationalId, value: user.nationalId!),
                  ],
                  if (user.agentLicense != null) ...[
                    const Divider(height: 1),
                    _ProfileTile(icon: Icons.card_membership, label: l10n.agentLicense, value: user.agentLicense!),
                  ],
                  if (user.isMoving) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(Icons.local_shipping, color: Colors.orange.shade700),
                      title: Text(l10n.moveStatus, style: const TextStyle(fontSize: 13, color: Colors.grey)),
                      subtitle: Text(
                        user.moveMode == MoveMode.planning ? l10n.planning : l10n.active,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.orange.shade800),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MoveDashboardScreen()),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (user.verificationStatus != VerificationStatus.verified)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showVerificationDialog(context, user.id),
                  icon: const Icon(Icons.verified_user),
                  label: Text(l10n.verifyMyAccount),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<AppState>().logout();
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVerificationDialog(BuildContext context, String userId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.accountVerification),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.verifyAccountDescription),
            const SizedBox(height: 8),
            Text('\u2022 ${l10n.nidaRequired}'),
            Text('\u2022 ${l10n.phoneVerificationRequired}'),
            const SizedBox(height: 8),
            Text(l10n.verifiedUsersBenefit),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.later)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => KycGateScreen(userId: userId)),
              );
            },
            child: Text(l10n.startVerification),
          ),
        ],
      ),
    );
  }

  /// Gallery/camera → upload to the avatars bucket → save the URL on
  /// the user row (via AppState, which also refreshes the UI).
  Future<void> _changeProfilePicture(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.gallery),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(l10n.camera),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      imageQuality: 80,
    );
    if (picked == null || !context.mounted) return;

    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final url = await StorageService()
          .uploadProfileImage(File(picked.path), appState.currentUser!.id);
      await appState.updateProfileImage(url);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.photoUploadFailed), backgroundColor: Colors.red),
      );
    } finally {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TrustBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      backgroundColor: color.withAlpha(30),
      side: BorderSide(color: color.withAlpha(60)),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primary),
      title: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      subtitle: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
    );
  }
}
