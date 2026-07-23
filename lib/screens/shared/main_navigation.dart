import 'package:flutter/material.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:provider/provider.dart';

import 'package:dalali/screens/seeker/seeker_home_screen.dart';
import 'package:dalali/screens/landlord/landlord_dashboard_screen.dart';
import 'package:dalali/screens/landlord/add_property_screen.dart';
import 'package:dalali/screens/agent/agent_dashboard_screen.dart';
import 'package:dalali/screens/shared/profile_screen.dart';
import 'package:dalali/screens/move/move_dashboard_screen.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/earnings/earnings_screen.dart';
import 'package:dalali/screens/influencer/influencer_dashboard_screen.dart';
import 'package:dalali/screens/influencer/referral_link_screen.dart';
import 'package:dalali/screens/influencer/influencer_campaigns_screen.dart';
import 'package:dalali/screens/shared/conversations_screen.dart';
import 'package:dalali/services/chat_service.dart';
import 'package:dalali/services/deep_link_service.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Cold-start deep link: a ?listing=<id> captured before login is
    // stashed in DeepLinkService — open it once we land in the app.
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingListing());
  }

  void _openPendingListing() {
    final listingId = DeepLinkService.instance.pendingListingId;
    if (listingId == null || !mounted) return;
    DeepLinkService.instance.pendingListingId = null;
    DeepLinkService.instance.openListingById(listingId);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    final screens = _getScreens(user.role, user.id);
    final items = _getNavItems(context, user.role, user.id);

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: items,
      ),
    );
  }

  List<Widget> _getScreens(UserRole role, String userId) {
    switch (role) {
      case UserRole.seeker:
        return [
          const SeekerHomeScreen(),
          const EarningsScreen(),
          const MoveDashboardScreen(),
          ConversationsScreen(userId: userId),
          const ProfileScreen(),
        ];
      case UserRole.landlord:
        // No Earnings tab: landlords list for free and have no in-app
        // earnings (the platform keeps 100% of the agency fee).
        return [
          const LandlordDashboardScreen(),
          const AddPropertyScreen(),
          ConversationsScreen(userId: userId),
          const ProfileScreen(),
        ];
      case UserRole.agent:
        return [
          const AgentDashboardScreen(),
          const AddPropertyScreen(),
          const EarningsScreen(),
          ConversationsScreen(userId: userId),
          const ProfileScreen(),
        ];
      case UserRole.influencer:
        return [
          const InfluencerDashboardScreen(),
          const ReferralLinkScreen(),
          const InfluencerCampaignsScreen(),
          const EarningsScreen(),
          ConversationsScreen(userId: userId),
          const ProfileScreen(),
        ];
    }
  }

  /// Messages tab icon with a live unread-count badge.
  NavigationDestination _messagesDestination(String userId, String label) {
    return NavigationDestination(
      icon: StreamBuilder<int>(
        stream: ChatService().watchTotalUnread(userId),
        builder: (context, snapshot) {
          final count = snapshot.data ?? 0;
          return Badge(
            isLabelVisible: count > 0,
            label: Text('$count'),
            child: const Icon(Icons.chat_bubble_outline),
          );
        },
      ),
      label: label,
    );
  }

  List<NavigationDestination> _getNavItems(BuildContext context, UserRole role, String userId) {
    final l10n = AppLocalizations.of(context)!;
    switch (role) {
      case UserRole.seeker:
        return [
          NavigationDestination(icon: const Icon(Icons.home), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          NavigationDestination(icon: const Icon(Icons.local_shipping), label: l10n.myMove),
          _messagesDestination(userId, l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.landlord:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          _messagesDestination(userId, l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.agent:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          _messagesDestination(userId, l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.influencer:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.link), label: l10n.referral),
          NavigationDestination(icon: const Icon(Icons.campaign), label: l10n.campaigns),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          _messagesDestination(userId, l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
    }
  }
}
