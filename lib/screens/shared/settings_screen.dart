import 'package:flutter/material.dart';
import 'package:dalali/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:dalali/models/user_preferences_model.dart';
import 'package:dalali/providers/theme_provider.dart';
import 'package:dalali/providers/language_provider.dart';
import 'package:dalali/providers/app_state.dart';

void _showFeedback(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final languageProvider = context.watch<LanguageProvider>();
    final appState = context.read<AppState>();
    final user = appState.currentUser;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ─── Appearance ─────────────────────────────────────────
          Text(
            l10n.appearance,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _ThemeOptionTile(
                  icon: Icons.brightness_auto,
                  title: l10n.themeSystem,
                  selected: themeProvider.isSystemMode,
                  onTap: () {
                    themeProvider.setThemeMode(AppThemeMode.system, userId: user?.id);
                    _showFeedback(context, l10n.themeSystem);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _ThemeOptionTile(
                  icon: Icons.light_mode,
                  title: l10n.themeLight,
                  selected: themeProvider.isLightMode,
                  onTap: () {
                    themeProvider.setThemeMode(AppThemeMode.light, userId: user?.id);
                    _showFeedback(context, l10n.themeLight);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _ThemeOptionTile(
                  icon: Icons.dark_mode,
                  title: l10n.themeDark,
                  selected: themeProvider.isDarkMode,
                  onTap: () {
                    themeProvider.setThemeMode(AppThemeMode.dark, userId: user?.id);
                    _showFeedback(context, l10n.themeDark);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Language ───────────────────────────────────────────
          Text(
            l10n.language,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _LanguageOptionTile(
                  flag: '🇬🇧',
                  title: l10n.english,
                  subtitle: 'English',
                  selected: languageProvider.languageCode == 'en',
                  onTap: () {
                    languageProvider.setLocale('en', userId: user?.id);
                    _showFeedback(context, l10n.english);
                  },
                ),
                const Divider(height: 1, indent: 56),
                _LanguageOptionTile(
                  flag: '🇹🇿',
                  title: l10n.kiswahili,
                  subtitle: 'Kiswahili',
                  selected: languageProvider.languageCode == 'sw',
                  onTap: () {
                    languageProvider.setLocale('sw', userId: user?.id);
                    _showFeedback(context, l10n.kiswahili);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ─── Preview ────────────────────────────────────────────
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.welcome),
                  Text(l10n.searchHint),
                  Text(l10n.settings),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  final String flag;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageOptionTile({
    required this.flag,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
          : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
