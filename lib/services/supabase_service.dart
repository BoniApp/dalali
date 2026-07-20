import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dalali/config/supabase_config.dart';

/// ═══════════════════════════════════════════════════════════════
/// SUPABASE SERVICE — Singleton wrapper
///
/// Central access point for all Supabase operations:
///   • Auth     → SupabaseService.client.auth
///   • Database → SupabaseService.client.from('table')
///   • Storage  → SupabaseService.client.storage
///   • Realtime → SupabaseService.client.channel('name')
/// ═══════════════════════════════════════════════════════════════
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
  }

  /// Current authenticated user (or null)
  static User? get currentUser => client.auth.currentUser;

  /// Current user's UUID (or null)
  static String? get currentUserId => currentUser?.id;

  /// Stream of auth state changes
  static Stream<AuthState> get onAuthStateChange =>
      client.auth.onAuthStateChange;
}
