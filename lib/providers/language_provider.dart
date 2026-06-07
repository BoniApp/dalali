import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  static const String _prefsKey = 'app_language_code';

  Locale get locale => _locale;
  String get languageCode => _locale.languageCode;

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('sw'),
  ];

  LanguageProvider() {
    _loadFromLocal();
  }

  Future<void> _loadFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && _isSupported(saved)) {
        _locale = Locale(saved);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('LanguageProvider: local load failed: $e');
    }
  }

  Future<void> setLocale(String languageCode, {String? userId}) async {
    if (!_isSupported(languageCode)) return;
    if (_locale.languageCode == languageCode) return;

    _locale = Locale(languageCode);
    notifyListeners();

    // Persist in background so IO/network never blocks UI updates
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, languageCode);
    } catch (e) {
      debugPrint('LanguageProvider: SharedPreferences save failed: $e');
    }

    if (userId != null) {
      await _syncToFirestore(userId, languageCode);
    }
  }

  Future<void> loadFromFirestore(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final data = doc.data()?['preferences'] as Map<String, dynamic>?;
      if (data != null && data['language'] != null) {
        final lang = data['language'] as String;
        if (_isSupported(lang)) {
          await setLocale(lang);
        }
      }
    } catch (e) {
      debugPrint('LanguageProvider: Firestore load failed: $e');
    }
  }

  Future<void> _syncToFirestore(String userId, String languageCode) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'preferences.language': languageCode});
    } catch (e) {
      debugPrint('LanguageProvider: Firestore sync failed: $e');
    }
  }

  bool _isSupported(String code) {
    return supportedLocales.any((l) => l.languageCode == code);
  }

  String getLanguageName(String code) => switch (code) {
    'en' => 'English',
    'sw' => 'Kiswahili',
    _ => 'English',
  };
}
