import 'package:flutter/material.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:dalali/models/user_model.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:provider/provider.dart';

import 'package:dalali/screens/seeker/seeker_home_screen.dart';
import 'package:dalali/screens/seeker/favorites_screen.dart';
import 'package:dalali/screens/seeker/appointments_screen.dart';
import 'package:dalali/screens/landlord/landlord_dashboard_screen.dart';
import 'package:dalali/screens/landlord/add_property_screen.dart';
import 'package:dalali/screens/landlord/inquiries_screen.dart';
import 'package:dalali/screens/agent/agent_dashboard_screen.dart';
import 'package:dalali/screens/shared/profile_screen.dart';
import 'package:dalali/screens/move/move_dashboard_screen.dart';
import 'package:dalali/screens/shared/messages_screen.dart';
import 'package:dalali/screens/auth/login_screen.dart';

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
          MoveDashboardScreen(),
          FavoritesScreen(),
          AppointmentsScreen(),
          ProfileScreen(),
        ];
      case UserRole.landlord:
        return const [
          LandlordDashboardScreen(),
          AddPropertyScreen(),
          InquiriesScreen(),
          MessagesScreen(),
          ProfileScreen(),
        ];
      case UserRole.agent:
        return const [
          AgentDashboardScreen(),
          AddPropertyScreen(),
          InquiriesScreen(),
          MessagesScreen(),
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
          NavigationDestination(icon: const Icon(Icons.local_shipping), label: l10n.myMove),
          NavigationDestination(icon: const Icon(Icons.favorite), label: l10n.saved),
          NavigationDestination(icon: const Icon(Icons.calendar_today), label: l10n.visits),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.landlord:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          NavigationDestination(icon: const Icon(Icons.notifications), label: l10n.inquiries),
          NavigationDestination(icon: const Icon(Icons.message), label: l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
      case UserRole.agent:
        return [
          NavigationDestination(icon: const Icon(Icons.dashboard), label: l10n.dashboard),
          NavigationDestination(icon: const Icon(Icons.add_home), label: l10n.add),
          NavigationDestination(icon: const Icon(Icons.notifications), label: l10n.inquiries),
          NavigationDestination(icon: const Icon(Icons.message), label: l10n.messages),
          NavigationDestination(icon: const Icon(Icons.person), label: l10n.profile),
        ];
    }
  }
}
