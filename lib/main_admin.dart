import 'package:flutter/material.dart';
import 'package:dalali/config/app_theme.dart';
import 'package:dalali/services/supabase_service.dart';
import 'package:dalali/screens/admin/login_admin_screen.dart';

/// ═══════════════════════════════════════════════════════════════
/// DALALI ADMIN DASHBOARD - Entry Point
///
/// Run with:
///   flutter run -t lib/main_admin.dart -d chrome
///
/// Build for web:
///   flutter build web -t lib/main_admin.dart
/// ═══════════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.initialize();
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dalali Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const LoginAdminScreen(),
      routes: {
        '/admin/login': (context) => const LoginAdminScreen(),
      },
    );
  }
}
