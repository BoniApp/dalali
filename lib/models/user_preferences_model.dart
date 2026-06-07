enum AppThemeMode { system, light, dark }

class UserPreferencesModel {
  final AppThemeMode themeMode;
  final String languageCode;

  const UserPreferencesModel({
    this.themeMode = AppThemeMode.system,
    this.languageCode = 'en',
  });

  Map<String, dynamic> toJson() => {
    'theme': themeMode.name,
    'language': languageCode,
  };

  factory UserPreferencesModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserPreferencesModel();
    return UserPreferencesModel(
      themeMode: AppThemeMode.values.firstWhere(
        (e) => e.name == json['theme'],
        orElse: () => AppThemeMode.system,
      ),
      languageCode: json['language'] ?? 'en',
    );
  }

  UserPreferencesModel copyWith({
    AppThemeMode? themeMode,
    String? languageCode,
  }) {
    return UserPreferencesModel(
      themeMode: themeMode ?? this.themeMode,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
