import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/settings_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';

const List<int> kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
];

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> postUrl(Uri url) async => _FakeHttpClientRequest();
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();
  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();
  @override
  void add(List<int> data) {}
  @override
  void write(Object? obj) {}
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => kTransparentPng.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return Stream<List<int>>.fromIterable([kTransparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _MockSupabaseService extends Fake implements SupabaseService {
  @override
  Future<void> insertRide(RideModel ride) async {}

  @override
  Future<List<RideModel>> getAllRides() async => [];
}

void configureIPhone14Pro(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556); // 393 x 852 pt
  tester.view.devicePixelRatio = 3.0;
  tester.view.padding = const FakeViewPadding(
    top: 177, // 59pt Dynamic Island * 3.0
    bottom: 102, // 34pt Home Indicator * 3.0
    left: 0,
    right: 0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();

  setUp(() {
    HttpOverrides.global = _MockHttpOverrides();
    SharedPreferences.setMockInitialValues({
      'probike_active_theme': 'editorialAubergine',
    });
  });

  tearDown(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Editorial Aubergine & UI/UX Quality Assurance Tests', () {
    testWidgets(
      '1. DashboardScreen in Editorial Aubergine has visible distances and zero neon lime bleed',
      (tester) async {
        configureIPhone14Pro(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
        });

        final themeController = ThemeController();
        await themeController.setTheme(AppThemeMode.editorialAubergine);

        final controller = RideController(
          supabaseService: _MockSupabaseService(),
          autoFetchHistory: false,
        );

        controller.ridesHistory = [
          RideModel(
            id: 1,
            clientId: 'ride_aubergine_1',
            startTime: DateTime.now(),
            durationSeconds: 1800, // 30 mins
            distanceMeters: 14500.0, // 14.50 km
            avgSpeedKmh: 29.0,
            maxSpeedKmh: 38.5,
            minSpeedKmh: 15.2,
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(
            home: DashboardScreen(
              controller: controller,
              themeController: themeController,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No Flutter render overflow errors
        expect(tester.takeException(), isNull);

        // Verify distance numbers are rendered and visible (styled with textPrimary in both Hero Card and Ride Card)
        final distanceWidgets = tester.widgetList<Text>(find.text('14.50'));
        expect(distanceWidgets.length, equals(2));
        for (final textWidget in distanceWidgets) {
          expect(
            textWidget.style?.color,
            equals(AppTheme.editorialAubergine.textPrimary),
            reason: 'Distance digits must be deep charcoal-plum for contrast on white cards',
          );
        }

        // Verify km unit uses primary aubergine, NOT neon lime (0xFFCCFF00)
        final allTexts = tester.widgetList<Text>(find.byType(Text));
        for (final t in allTexts) {
          final color = t.style?.color;
          if (color != null) {
            expect(
              color.toARGB32(),
              isNot(equals(0xFFCCFF00)),
              reason: 'No neon lime bleed allowed in Editorial Aubergine theme: "${t.data}"',
            );
          }
        }

        // Verify floating action button ("بدء الرحلة") uses onPrimary white text on aubergine
        final startBtnText = find.textContaining('بدء الرحلة');
        expect(startBtnText, findsOneWidget);
        final startWidget = tester.widget<Text>(startBtnText);
        expect(startWidget.style?.color, equals(Colors.white));

        controller.dispose();
      },
    );

    testWidgets(
      '2. SettingsScreen "Change Theme" button does NOT overflow on iPhone 14 Pro (393pt)',
      (tester) async {
        configureIPhone14Pro(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
        });

        final themeController = ThemeController();
        await themeController.setTheme(AppThemeMode.editorialAubergine);
        final localeController = LocaleController(autoLoad: false);

        final rideController = RideController(
          supabaseService: _MockSupabaseService(),
          autoFetchHistory: false,
        );

        // Test in English
        await localeController.setLanguage(AppLanguage.english);

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

        // Must NOT throw RenderFlex overflow
        expect(tester.takeException(), isNull);

        // Verify "Change Theme" button is present and not clipped
        final changeThemeFinder = find.text('Change Theme');
        expect(changeThemeFinder, findsOneWidget);

        // Test in Arabic
        await localeController.setLanguage(AppLanguage.arabicEgyptian);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final changeThemeArFinder = find.text('تغيير السمة');
        expect(changeThemeArFinder, findsOneWidget);

        rideController.dispose();
      },
    );

    testWidgets(
      '3. Reminder Card notification title does not duplicate the bell icon',
      (tester) async {
        final stringsAr = const AppStrings(AppLanguage.arabicEgyptian);
        final stringsEn = const AppStrings(AppLanguage.english);

        // Ensure title strings do not contain the bell emoji which caused the double-bell defect
        expect(stringsAr.reminderNotificationCardTitle(30).contains('🔔'), isFalse);
        expect(stringsEn.reminderNotificationCardTitle(30).contains('🔔'), isFalse);
      },
    );

    testWidgets(
      '4. Shortcuts setup button has high contrast white text in Editorial Aubergine',
      (tester) async {
        configureIPhone14Pro(tester);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetPadding();
        });

        final themeController = ThemeController();
        await themeController.setTheme(AppThemeMode.editorialAubergine);
        final localeController = LocaleController(autoLoad: false);
        final rideController = RideController(
          supabaseService: _MockSupabaseService(),
          autoFetchHistory: false,
        );

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

        // Find shortcut setup elevated buttons specifically
        final shortcutButtons = tester.widgetList<ElevatedButton>(
          find.widgetWithText(ElevatedButton, localeController.strings.installShortcutBtn),
        );
        expect(shortcutButtons.length, equals(2));
        for (final btn in shortcutButtons) {
          final fg = btn.style?.foregroundColor?.resolve({});
          expect(
            fg,
            equals(Colors.white),
            reason: 'Shortcut setup buttons on deep aubergine/plum must have high-contrast white text',
          );
        }

        // Change Theme button should use theme.primary text
        final changeThemeBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, localeController.strings.changeThemeButton),
        );
        expect(
          changeThemeBtn.style?.foregroundColor?.resolve({}),
          equals(AppTheme.editorialAubergine.primary),
        );

        rideController.dispose();
      },
    );

    test(
      '5. Language labels are clean ("العربية" and "English") with zero slang or gimmicks',
      () {
        const stringsAr = AppStrings(AppLanguage.arabicEgyptian);
        const stringsEn = AppStrings(AppLanguage.english);

        // Professional, clean language names
        expect(stringsAr.langArabic, equals('العربية'));
        expect(stringsEn.langEnglish, equals('English'));
        expect(stringsAr.langArabic, isNot(contains('روش')));
        expect(stringsAr.langArabic, isNot(contains('دارج')));
        expect(stringsEn.langEnglish, isNot(contains('Modern Cycling')));
      },
    );

    test(
      '6. Zero language mixing in Arabic mode (No English words or titles in Arabic UI)',
      () {
        const stringsAr = AppStrings(AppLanguage.arabicEgyptian);

        // Titles and buttons must be pure Arabic without English intrusions
        expect(stringsAr.todayHeroTitle, equals('نشاط اليوم'));
        expect(stringsAr.todayHeroTitle, isNot(contains('TODAY')));
        expect(stringsAr.todayHeroTitle, isNot(contains('HERO')));

        expect(stringsAr.startRideButtonIdle, equals('بدء الرحلة'));
        expect(stringsAr.startRideButtonIdle, isNot(contains('Start')));
        expect(stringsAr.startRideButtonIdle, isNot(contains('رايد')));

        expect(stringsAr.liveFinishButton, equals('إنهاء الرحلة'));
        expect(stringsAr.liveFinishButton, isNot(contains('STOP')));

        expect(stringsAr.settingsLanguageSection, equals('لغة التطبيق'));
        expect(stringsAr.settingsLanguageSection, isNot(contains('Language')));

        // Localized Date & Weekday formatting
        final testDate = DateTime(2026, 10, 25, 14, 30); // Sunday
        expect(stringsAr.formatTodayHeroDate(testDate), equals('الأحد، 25 أكتوبر'));
        expect(stringsAr.formatWeekdayShort(testDate), equals('أح'));
        expect(stringsAr.formatDateTime(testDate), contains('م')); // PM in Arabic
        expect(stringsAr.formatDateTime(testDate), isNot(contains('PM')));
        expect(stringsAr.formatDateTime(testDate), isNot(contains('AM')));
      },
    );
  });
}

