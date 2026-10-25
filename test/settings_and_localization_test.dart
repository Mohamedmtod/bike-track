import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/settings_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/shortcuts_service.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';

import 'package:bike_track/models/ride_model.dart';

class MockSupabaseService extends Fake implements SupabaseService {
  @override
  Future<void> insertRide(RideModel ride) async {}
  @override
  Future<List<RideModel>> getAllRides() async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LocaleController & AppStrings Localization Tests', () {
    test('Defaults to Arabic standard language', () {
      final controller = LocaleController(autoLoad: false);
      expect(controller.currentLanguage, AppLanguage.arabicEgyptian);
      expect(controller.isArabic, isTrue);
      expect(controller.isRtl, isTrue);
      expect(controller.textDirection, TextDirection.rtl);
      expect(controller.flutterLocale, const Locale('ar'));
      expect(controller.strings.headerGreeting, contains('أهلاً بك'));
    });

    test('Switches to English and persists in SharedPreferences', () async {
      final controller = LocaleController(autoLoad: false);
      await controller.setLanguage(AppLanguage.english);

      expect(controller.currentLanguage, AppLanguage.english);
      expect(controller.isArabic, isFalse);
      expect(controller.isRtl, isFalse);
      expect(controller.textDirection, TextDirection.ltr);
      expect(controller.flutterLocale, const Locale('en'));
      expect(controller.strings.headerGreeting, contains('Welcome back'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_language'), 'en');

      // Toggling switches back to Arabic
      controller.toggleLanguage();
      expect(controller.currentLanguage, AppLanguage.arabicEgyptian);
      expect(controller.isArabic, isTrue);
      expect(controller.isRtl, isTrue);
      expect(controller.textDirection, TextDirection.rtl);
    });

    test('Loads saved English locale from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'selected_language': 'en'});
      final controller = LocaleController(autoLoad: true);
      await controller.init();

      expect(controller.currentLanguage, AppLanguage.english);
      expect(controller.isArabic, isFalse);
    });
  });

  group('ThemeController & 3 Themes Customization Tests', () {
    test('Defaults to Galaxy RL600H Titanium Sport theme', () {
      final controller = ThemeController(autoLoad: false);
      expect(controller.currentMode, AppThemeMode.galaxyRl600h);
      expect(
        const AppStrings(AppLanguage.arabicEgyptian)
            .themeName(controller.currentMode),
        contains('Galaxy RL600H'),
      );
      expect(controller.currentTheme.primary, const Color(0xFF0EA5E9)); // Cobalt Blue
    });

    test('Can switch to Classic Neon and Editorial Aubergine and persists', () async {
      final controller = ThemeController(autoLoad: false);

      await controller.setTheme(AppThemeMode.classicNeon);
      expect(controller.currentMode, AppThemeMode.classicNeon);
      expect(controller.currentTheme.primary, const Color(0xFFCCFF00)); // Neon Lime

      await controller.setTheme(AppThemeMode.editorialAubergine);
      expect(controller.currentMode, AppThemeMode.editorialAubergine);
      expect(controller.currentTheme.primary, const Color(0xFF51283F)); // Deep Aubergine

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_theme'), 'editorial_aubergine');
    });
  });

  group('ShortcutsService iOS Scheme Tests', () {
    test('Builds valid shortcuts:// import URLs', () {
      final uri = ShortcutsService.buildImportShortcutUri(
        fileUrl: 'https://example.com/test.shortcut',
        name: 'ProBike Start',
      );
      expect(uri.scheme, 'shortcuts');
      expect(uri.host, 'import-shortcut');
      expect(uri.queryParameters['name'], 'ProBike Start');
      expect(uri.queryParameters['url'], 'https://example.com/test.shortcut');
    });

    test('Deep link constants match app configuration', () {
      expect(ShortcutsService.schemeStart, 'probike://start');
      expect(ShortcutsService.schemeStop, 'probike://stop');
      expect(ShortcutsService.legacySchemeStart, 'cycletrack://start');
      expect(ShortcutsService.legacySchemeStop, 'cycletrack://stop');
      expect(ShortcutsService.startShortcutCloudUrl, contains('ProBike_Start.shortcut'));
      expect(ShortcutsService.stopShortcutCloudUrl, contains('ProBike_Stop.shortcut'));
    });

    testWidgets('copySchemeToClipboard writes scheme to Clipboard', (tester) async {
      String? clipboardData;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            clipboardData = (methodCall.arguments as Map)['text'];
            return null;
          } else if (methodCall.method == 'Clipboard.getData') {
            return {'text': clipboardData};
          }
          return null;
        },
      );

      await ShortcutsService.copySchemeToClipboard(ShortcutsService.schemeStart);
      expect(clipboardData, ShortcutsService.schemeStart);

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, ShortcutsService.schemeStart);

      await ShortcutsService.copySchemeToClipboard(ShortcutsService.schemeStop);
      expect(clipboardData, ShortcutsService.schemeStop);

      final dataStop = await Clipboard.getData(Clipboard.kTextPlain);
      expect(dataStop?.text, ShortcutsService.schemeStop);
    });
  });

  group('SettingsScreen UI & Integration Flow Tests', () {
    testWidgets('Dashboard header has settings button and opens SettingsScreen', (tester) async {
      final rideController = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Settings gear icon in header
      expect(find.byKey(const Key('settings_button')), findsOneWidget);

      // Tap settings button
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();

      // Verify SettingsScreen opened
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text(localeController.strings.settingsTitle), findsOneWidget);
      expect(find.text(localeController.strings.settingsThemeSection), findsOneWidget);
      expect(find.text(localeController.strings.settingsLanguageSection), findsOneWidget);

      rideController.dispose();
    });

    testWidgets('SettingsScreen live toggles language and theme', (tester) async {
      final rideController = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch language to English
      await tester.tap(find.text(localeController.strings.langEnglishModern));
      await tester.pumpAndSettle();
      expect(localeController.currentLanguage, AppLanguage.english);

      // Open theme selector sheet and switch to Classic Neon
      await tester.tap(find.text(localeController.strings.changeThemeButton));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ProBike Classic'));
      await tester.pumpAndSettle();
      expect(themeController.currentMode, AppThemeMode.classicNeon);

      rideController.dispose();
    });
  });
}
