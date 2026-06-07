import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/providers/app_state.dart';
import 'package:dalali/providers/theme_provider.dart';
import 'package:dalali/providers/language_provider.dart';
import 'package:dalali/screens/auth/login_screen.dart';
import 'package:dalali/screens/shared/main_navigation.dart';
import 'package:dalali/screens/shared/role_selection_screen.dart';
import 'package:dalali/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
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
    final appState = context.watch<AppState>();

    return StreamBuilder<AuthState>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && appState.currentUser == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;

        // Logged in via Supabase OR demo mode
        if ((session != null && session.user != null) || appState.currentUser != null) {
          return const MainNavigation();
        }

        // Otherwise show role selection (demo mode) which has login option
        return const RoleSelectionScreen();
      },
    );
  }
}
