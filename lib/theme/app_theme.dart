import 'package:flutter/material.dart';

enum AppThemeMode {
  galaxyRl600h,
  classicNeon,
  editorialAubergine,
}

class AppThemeTokens {
  final AppThemeMode mode;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color cardBorder;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color error;
  final bool isDark;
  final ColorFilter mapColorFilter;
  final Color polylineCore;
  final Color polylineGlow;

  const AppThemeTokens({
    required this.mode,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.cardBorder,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.error,
    required this.isDark,
    required this.mapColorFilter,
    required this.polylineCore,
    required this.polylineGlow,
  });

  ThemeData toThemeData() {
    final brightness = isDark ? Brightness.dark : Brightness.light;
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      cardColor: surface,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: onPrimary,
        secondary: secondary,
        onSecondary: textPrimary,
        error: error,
        onError: Colors.white,
        surface: surface,
        onSurface: textPrimary,
      ),
      useMaterial3: true,
    );
  }
}

class AppTheme {
  // Dark OLED Map Filter
  static const ColorFilter darkOledMapFilter = ColorFilter.matrix(<double>[
    -0.85,  0.0,   0.0,   0.0, 215.0,
     0.0,  -0.85,  0.0,   0.0, 220.0,
     0.0,   0.0,  -0.80,  0.0, 235.0,
     0.0,   0.0,   0.0,   1.0,   0.0,
  ]);

  // Warm Ivory Map Filter for Editorial Aubergine
  static const ColorFilter warmIvoryMapFilter = ColorFilter.matrix(<double>[
    0.95,  0.0,   0.0,   0.0, 10.0,
    0.0,   0.92,  0.0,   0.0, 8.0,
    0.0,   0.0,   0.85,  0.0, 5.0,
    0.0,   0.0,   0.0,   1.0, 0.0,
  ]);

  /// 1. Galaxy RL600H - Titanium Sport (DEFAULT)
  /// Inspired by the user's hybrid bike: gunmetal titanium frame, cobalt blue lock knob, silver typography
  static const AppThemeTokens galaxyRl600h = AppThemeTokens(
    mode: AppThemeMode.galaxyRl600h,
    background: Color(0xFF121418),
    surface: Color(0xFF1A1E24),
    surfaceContainer: Color(0xFF222730),
    cardBorder: Color(0xFF2D333F),
    primary: Color(0xFF0EA5E9), // Electric Cobalt Blue from Suspension Lock Knob
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFF64748B),
    tertiary: Color(0xFF38BDF8),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    success: Color(0xFF22C55E),
    error: Color(0xFFEF4444),
    isDark: true,
    mapColorFilter: darkOledMapFilter,
    polylineCore: Color(0xFF0EA5E9),
    polylineGlow: Color(0x660EA5E9),
  );

  /// 2. ProBike Classic - Neon Lime Cyber
  static const AppThemeTokens classicNeon = AppThemeTokens(
    mode: AppThemeMode.classicNeon,
    background: Color(0xFF090A0F),
    surface: Color(0xFF14161F),
    surfaceContainer: Color(0xFF1C1F2B),
    cardBorder: Color(0x1FFFFFFF),
    primary: Color(0xFFCCFF00), // Neon Lime
    onPrimary: Color(0xFF090A0F),
    secondary: Color(0xFF8E95A5),
    tertiary: Color(0xFFE5FF7F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0x8AFFFFFF),
    success: Color(0xFF00E676),
    error: Color(0xFFFF2D55),
    isDark: true,
    mapColorFilter: darkOledMapFilter,
    polylineCore: Color(0xFFCCFF00),
    polylineGlow: Color(0x66CCFF00),
  );

  /// 3. Editorial Aubergine - التصميم الراقي الهادئ
  static const AppThemeTokens editorialAubergine = AppThemeTokens(
    mode: AppThemeMode.editorialAubergine,
    background: Color(0xFFF6F1E9), // Warm Ivory
    surface: Color(0xFFFFFFFF),    // Soft White Card
    surfaceContainer: Color(0xFFEFE8DD),
    cardBorder: Color(0xFFE2D9CC),
    primary: Color(0xFF51283F),    // Deep Aubergine
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFB58E9F),  // Warm Mauve
    tertiary: Color(0xFF381329),
    textPrimary: Color(0xFF302A2D),// Deep Charcoal-Plum
    textSecondary: Color(0xFF766D71),
    success: Color(0xFF55765E),
    error: Color(0xFFA64D4D),
    isDark: false,
    mapColorFilter: warmIvoryMapFilter,
    polylineCore: Color(0xFF51283F),
    polylineGlow: Color(0x4451283F),
  );

  static const List<AppThemeTokens> allThemes = [
    galaxyRl600h,
    classicNeon,
    editorialAubergine,
  ];

  static AppThemeTokens fromMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.galaxyRl600h:
        return galaxyRl600h;
      case AppThemeMode.classicNeon:
        return classicNeon;
      case AppThemeMode.editorialAubergine:
        return editorialAubergine;
    }
  }

  static AppThemeTokens fromString(String? key) {
    switch (key) {
      case 'classic_neon':
        return classicNeon;
      case 'editorial_aubergine':
        return editorialAubergine;
      case 'galaxy_rl600h':
      default:
        return galaxyRl600h; // DEFAULT
    }
  }

  static String toKey(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.galaxyRl600h:
        return 'galaxy_rl600h';
      case AppThemeMode.classicNeon:
        return 'classic_neon';
      case AppThemeMode.editorialAubergine:
        return 'editorial_aubergine';
    }
  }
}
