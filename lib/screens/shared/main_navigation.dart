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
import 'package:dalali/screens/opportunity/opportunity_feed_screen.dart';
import 'package:dalali/screens/influencer/influencer_dashboard_screen.dart';
import 'package:dalali/screens/influencer/referral_link_screen.dart';
import 'package:dalali/screens/influencer/influencer_campaigns_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;

    if (user == null) {
      return const LoginScreen();
    }

    final screens = _getScreens(user.role);
    final items = _getNavItems(context, user.role);

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: items,
      ),
    );
  }

  List<Widget> _getScreens(UserRole role) {
    switch (role) {
      case UserRole.seeker:
        return const [
          SeekerHomeScreen(),
          OpportunityFeedScreen(),
          EarningsScreen(),
          MoveDashboardScreen(),
          ProfileScreen(),
        ];
      case UserRole.landlord:
        return const [
          LandlordDashboardScreen(),
          AddPropertyScreen(),
          OpportunityFeedScreen(),
          EarningsScreen(),
          ProfileScreen(),
        ];
      case UserRole.agent:
        return const [
          AgentDashboardScreen(),
          AddPropertyScreen(),
          OpportunityFeedScreen(),
          EarningsScreen(),
          ProfileScreen(),
        ];
      case UserRole.influencer:
        return const [
          InfluencerDashboardScreen(),
          ReferralLinkScreen(),
          InfluencerCampaignsScreen(),
          EarningsScreen(),
          ProfileScreen(),
        ];
    }
  }

  List<NavigationDestination> _getNavItems(BuildContext context, UserRole role) {
    final l10n = AppLocalizations.of(context)!;
    switch (role) {
      case UserRole.seeker:
        return [
          NavigationDestination(icon: const Icon(Icons.home), label: l10n.home),
          NavigationDestination(icon: const Icon(Icons.trending_up), label: l10n.opportunities),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          NavigationDestination(icon: const Icon(Icons.local_shipping), label: l10n.myMove),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.landlord:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          NavigationDestination(icon: const Icon(Icons.trending_up), label: l10n.opportunities),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.agent:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          NavigationDestination(icon: const Icon(Icons.trending_up), label: l10n.opportunities),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.influencer:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.link), label: l10n.referral),
          NavigationDestination(icon: const Icon(Icons.campaign), label: l10n.campaigns),
          NavigationDestination(icon: const Icon(Icons.account_balance_wallet), label: l10n.earnings),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
    }
  }
}
