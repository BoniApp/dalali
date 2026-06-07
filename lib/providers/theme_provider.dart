import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dalali/models/user_preferences_model.dart';

extension AppThemeModeX on AppThemeMode {
  ThemeMode get flutterThemeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

class ThemeProvider extends ChangeNotifier {
  AppThemeMode _themeMode = AppThemeMode.system;
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
      await _syncToFirestore(userId, mode);
    }
  }

  Future<void> loadFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data()?['preferences'] as Map<String, dynamic>?;
      if (data != null && data['theme'] != null) {
        final mode = AppThemeMode.values.firstWhere(
          (e) => e.name == data['theme'],
          orElse: () => AppThemeMode.system,
        );
        await setThemeMode(mode);
      }
    } catch (e) {
      debugPrint('ThemeProvider: Firestore load failed: $e');
    }
  }

  Future<void> _syncToFirestore(String userId, AppThemeMode mode) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({_firestoreField: mode.name});
    } catch (e) {
      debugPrint('ThemeProvider: Firestore sync failed: $e');
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
