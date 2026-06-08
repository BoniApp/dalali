import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dalali/models/user_preferences_model.dart';
import 'package:dalali/services/supabase_service.dart';

extension AppThemeModeX on AppThemeMode {
  ThemeMode get flutterThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.light;
  static const String _prefsKey = 'app_theme_mode';
  static const String _firestoreField = 'preferences.theme';

  AppThemeMode get themeMode => _themeMode;
  ThemeMode get flutterThemeMode => _themeMode.flutterThemeMode;

  bool get isDarkMode => _themeMode == AppThemeMode.dark;
  bool get isLightMode => _themeMode == AppThemeMode.light;
  bool get isSystemMode => _themeMode == AppThemeMode.system;

  ThemeProvider() {
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null) {
        _themeMode = AppThemeMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => AppThemeMode.system,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ThemeProvider: local load failed: $e');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode, {String? userId}) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();

    // Persist in background so IO/network never blocks UI updates
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (e) {
      debugPrint('ThemeProvider: SharedPreferences save failed: $e');
    }

    if (userId != null) {
      await _syncToDatabase(userId, mode);
    }
  }

  Future<void> loadFromDatabase(String userId) async {
    try {
      final data = await SupabaseService.client
          .from('users')
          .select('preferences_theme')
          .eq('id', userId)
          .maybeSingle();
      if (data != null && data['preferences_theme'] != null) {
        final mode = AppThemeMode.values.firstWhere(
          (e) => e.name == data['preferences_theme'],
          orElse: () => AppThemeMode.system,
        );
        await setThemeMode(mode);
      }
    } catch (e) {
      debugPrint('ThemeProvider: database load failed: $e');
    }
  }

  Future<void> _syncToDatabase(String userId, AppThemeMode mode) async {
    try {
      await SupabaseService.client
          .from('users')
          .update({'preferences_theme': mode.name})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ThemeProvider: database sync failed: $e');
    }
  }

  ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  ThemeData getDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
