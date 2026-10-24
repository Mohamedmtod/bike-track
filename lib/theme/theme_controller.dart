import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeController extends ChangeNotifier {
  static const String _prefThemeKey = 'selected_theme';

  AppThemeTokens _currentTheme = AppTheme.galaxyRl600h;

  AppThemeTokens get currentTheme => _currentTheme;
  AppThemeMode get currentMode => _currentTheme.mode;

  ThemeController({bool autoLoad = true}) {
    if (autoLoad) {
      init();
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_prefThemeKey);
      _currentTheme = AppTheme.fromString(savedKey);
      notifyListeners();
    } catch (_) {
      // Default to galaxyRl600h if SharedPreferences fails
      _currentTheme = AppTheme.galaxyRl600h;
    }
  }

  Future<void> setTheme(AppThemeMode mode) async {
    if (_currentTheme.mode == mode) return;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    _currentTheme = AppTheme.fromMode(mode);
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefThemeKey, AppTheme.toKey(mode));
    } catch (_) {}
  }
}
