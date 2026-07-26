import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dalali/config/firebase_options.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/providers/user_state.dart';
import 'package:dalali/providers/property_state.dart';
import 'package:dalali/providers/tenancy_state.dart';
import 'package:dalali/providers/move_state.dart';
import 'package:dalali/providers/appointment_state.dart';
import 'package:dalali/providers/reward_state.dart';
import 'package:dalali/providers/notification_state.dart';
import 'package:dalali/providers/earnings_state.dart';
import 'package:dalali/providers/theme_provider.dart';
import 'package:dalali/providers/language_provider.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/shared/main_navigation.dart';
import 'package:dalali/screens/shared/role_selection_screen.dart';
import 'package:dalali/services/auth_service.dart';
import 'package:dalali/services/deep_link_service.dart';
import 'package:dalali/services/fcm_service.dart';
import 'package:dalali/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase (FCM push) — manual options, no native config edits needed
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  // Initialize local notifications
  await NotificationService.initialize();

  // FCM push (permissions, token sync, message handlers)
  await FcmService.initialize();

  // Referral deep links (dalaliapp.com/ref/CODE?listing=<id>)
  await DeepLinkService.instance.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserState()),
        ChangeNotifierProxyProvider<UserState, PropertyState>(
          create: (_) => PropertyState(),
          update: (_, userState, propertyState) =>
              propertyState!..onUserChanged(userState.currentUser, userState.isGuestMode),
        ),
        ChangeNotifierProxyProvider<UserState, TenancyState>(
          create: (_) => TenancyState(),
          update: (_, userState, tenancyState) => tenancyState!..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProxyProvider<UserState, MoveState>(
          create: (_) => MoveState(),
          update: (_, userState, moveState) =>
              (moveState!..attachUserState(userState))..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProxyProvider2<UserState, PropertyState, AppointmentState>(
          create: (_) => AppointmentState(),
          update: (_, userState, propertyState, appointmentState) =>
              (appointmentState!..attachPropertyState(propertyState))..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProxyProvider<UserState, RewardState>(
          create: (_) => RewardState(),
          update: (_, userState, rewardState) =>
              (rewardState!..attachUserState(userState))..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProxyProvider<UserState, NotificationState>(
          create: (_) => NotificationState(),
          update: (_, userState, notificationState) => notificationState!..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProxyProvider<UserState, EarningsState>(
          create: (_) => EarningsState(),
          update: (_, userState, earningsState) => earningsState!..onUserChanged(userState.currentUser),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: const _AppBody(),
    );
  }
}

class _AppBody extends StatelessWidget {
  const _AppBody();

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();

    return MaterialApp(
      title: 'Dalali',
      debugShowCheckedModeBanner: false,

      // ─── Localization ───────────────────────────────────────
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: LanguageProvider.supportedLocales,
      locale: languageProvider.locale,

      // ─── Theming ────────────────────────────────────────────
      themeMode: themeProvider.flutterThemeMode,
      theme: themeProvider.getLightTheme(),
      darkTheme: themeProvider.getDarkTheme(),

      home: const AuthWrapper(),
      navigatorKey: DeepLinkService.instance.navigatorKey,
      routes: {
        '/home': (context) => const MainNavigation(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final userState = context.watch<UserState>();

    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && userState.currentUser == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/images/dalali_logo.png', width: 120, height: 120),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        final session = snapshot.data?.session;

        // Logged in via Supabase
        if (session != null || userState.currentUser != null) {
          return const MainNavigation();
        }

        // Otherwise show role selection screen
        return const RoleSelectionScreen();
      },
    );
  }
}
