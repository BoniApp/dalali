import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
/// DalaliApp design system — semantic colors, typography scale,
/// and component states per the UI Component Specification.
///
///   primary        #0D9488  Deep Teal (headers, primary elements)
///   action         #F97316  Bright Orange (CTAs, highlights, errors)
///   textPrimary    #1F2937  Dark Gray body text
///   border         #E5E7EB  Light Gray dividers / input borders
///   darkBackground #0F172A  Dark-mode background (orange stays accent)
///
/// Spacing follows the 8pt grid: 8 / 16 / 24 / 32 / 48.
/// ═══════════════════════════════════════════════════════════════
class AppTheme {
  AppTheme._();

  // ─── Semantic colors ──────────────────────────────────────
  static const Color primary = Color(0xFF0D9488);
  static const Color action = Color(0xFFF97316);
  static const Color actionHover = Color(0xFFEA580C);
  static const Color actionPressed = Color(0xFFC2410C);
  static const Color actionDisabled = Color(0xFFFDBA74);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color backgroundNeutral = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  // Darker teal for depth (replaces Colors.teal.shade700+ usages).
  static const Color primaryDark = Color(0xFF0F766E);
  // Teal readable on the dark background.
  static const Color primaryOnDark = Color(0xFF2DD4BF);

  // ─── Spacing (8pt grid) ───────────────────────────────────
  static const double spacingXs = 8;
  static const double spacingSm = 16;
  static const double spacingMd = 24;
  static const double spacingLg = 32;
  static const double spacingXl = 48;

  // ─── Typography scale ─────────────────────────────────────
  static TextTheme _textTheme(Color color) => TextTheme(
        displayLarge: TextStyle(fontSize: 32, height: 40 / 32, fontWeight: FontWeight.bold, color: color),
        headlineMedium: TextStyle(fontSize: 24, height: 32 / 24, fontWeight: FontWeight.bold, color: color),
        titleLarge: TextStyle(fontSize: 18, height: 24 / 18, fontWeight: FontWeight.w600, color: color),
        bodyLarge: TextStyle(fontSize: 16, height: 24 / 16, color: color),
        bodyMedium: TextStyle(fontSize: 14, height: 20 / 14, color: color),
        labelLarge: TextStyle(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w600, color: color),
      );

  // ─── Primary button states (orange CTA) ───────────────────
  static final ElevatedButtonThemeData _elevatedButtons = ElevatedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) return actionDisabled;
        if (states.contains(WidgetState.pressed)) return actionPressed;
        if (states.contains(WidgetState.hovered)) return actionHover;
        return action;
      }),
      foregroundColor: WidgetStateProperty.all(textOnPrimary),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 16, height: 20 / 16, fontWeight: FontWeight.w600),
      ),
    ),
  );

  // ─── Input fields ─────────────────────────────────────────
  static InputDecorationTheme _inputs({
    required Color borderColor,
    required Color fillColor,
    required Color focusColor,
  }) {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      border: b(borderColor),
      enabledBorder: b(borderColor),
      focusedBorder: b(focusColor, 2),
      errorBorder: b(action, 2),
      focusedErrorBorder: b(action, 2),
      errorStyle: const TextStyle(color: action),
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: primary,
      onPrimary: textOnPrimary,
      secondary: action,
      onSecondary: textOnPrimary,
      error: action,
      onError: textOnPrimary,
      surface: backgroundNeutral,
      onSurface: textPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundNeutral,
      textTheme: _textTheme(textPrimary),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: primary,
        foregroundColor: textOnPrimary,
      ),
      elevatedButtonTheme: _elevatedButtons,
      inputDecorationTheme: _inputs(
        borderColor: border,
        fillColor: backgroundNeutral,
        focusColor: primary,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: action,
        foregroundColor: textOnPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: border),
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: primaryOnDark,
      onPrimary: darkBackground,
      secondary: action,
      onSecondary: textOnPrimary,
      error: action,
      onError: textOnPrimary,
      surface: darkSurface,
      onSurface: Color(0xFFF1F5F9),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: darkBackground,
      textTheme: _textTheme(const Color(0xFFF1F5F9)),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: darkBackground,
        foregroundColor: textOnPrimary,
      ),
      elevatedButtonTheme: _elevatedButtons,
      inputDecorationTheme: _inputs(
        borderColor: darkBorder,
        fillColor: darkSurface,
        focusColor: primaryOnDark,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: action,
        foregroundColor: textOnPrimary,
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        color: darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder),
    );
  }
}
