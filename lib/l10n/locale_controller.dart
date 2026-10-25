import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_strings.dart';

class LocaleController extends ChangeNotifier {
  static const String _prefLocaleKey = 'selected_language';

  AppLanguage _currentLanguage = AppLanguage.arabicEgyptian;

  AppLanguage get currentLanguage => _currentLanguage;
  AppStrings get strings => AppStrings(_currentLanguage);
  bool get isArabic => _currentLanguage == AppLanguage.arabicEgyptian;
  bool get isRtl => isArabic;
  TextDirection get textDirection =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;

  Locale get flutterLocale =>
      _currentLanguage == AppLanguage.arabicEgyptian ? const Locale('ar') : const Locale('en');

  LocaleController({bool autoLoad = true}) {
    if (autoLoad) {
      init();
    }
  }

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_prefLocaleKey);
      if (savedCode == 'en') {
        _currentLanguage = AppLanguage.english;
      } else {
        _currentLanguage = AppLanguage.arabicEgyptian;
      }
      notifyListeners();
    } catch (_) {
      _currentLanguage = AppLanguage.arabicEgyptian;
    }
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_currentLanguage == language) return;

    try {
      HapticFeedback.selectionClick();
    } catch (_) {}

    _currentLanguage = language;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefLocaleKey,
        language == AppLanguage.english ? 'en' : 'ar',
      );
    } catch (_) {}
  }

  void toggleLanguage() {
    setLanguage(
      _currentLanguage == AppLanguage.arabicEgyptian
          ? AppLanguage.english
          : AppLanguage.arabicEgyptian,
    );
  }
}
