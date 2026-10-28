import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/overall_stats_screen.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/screens/settings_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:bike_track/theme/theme_selector_sheet.dart';

class MockSupabaseService implements SupabaseService {
  final List<RideModel> cloudDatabase = [];
  final List<String> deletedClientIds = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    final existing = cloudDatabase.indexWhere((r) => r.clientId == ride.clientId);
    if (existing >= 0) {
      cloudDatabase[existing] = ride;
    } else {
      cloudDatabase.add(ride);
    }
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    return List<RideModel>.from(cloudDatabase);
  }

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
    deletedClientIds.add(clientId);
    cloudDatabase.removeWhere((r) => r.clientId == clientId || (id != null && r.id == id));
  }
}

class FakeNotificationService implements INotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<void> showNotification(int id, String title, String body) async {}
  @override
  Future<void> periodicallyShowWithDuration(
      int id, String title, String body, Duration repeatDuration) async {}
  @override
  Future<void> cancel(int id) async {}
}

class FakeTelemetryService implements ITelemetryService {
  @override
  String? get currentSessionId => 'test_session';
  @override
  int get bufferSize => 0;
  @override
  void startSession(String id) {}
  @override
  void logEvent({
    required String eventType,
    double? latitude,
    double? longitude,
    double? speedMps,
    double? accuracy,
    String? reason,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {}
  @override
  Future<void> flush() async {}
  @override
  Future<void> cleanOldLogs([int days = 14]) async {}
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Customization - Unit Tests', () {
    test('Default theme must be Galaxy RL600H (User bike)', () {
      final controller = ThemeController(autoLoad: false);
      expect(controller.currentMode, equals(AppThemeMode.galaxyRl600h));
      expect(
        const AppStrings(AppLanguage.arabicEgyptian)
            .themeName(controller.currentMode),
        equals('Galaxy RL600H'),
      );
      expect(controller.currentTheme.primary, equals(const Color(0xFF0EA5E9)));
      expect(controller.currentTheme.isDark, isTrue);
    });

    test('ThemeController persists selection to SharedPreferences and reloads', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = ThemeController(autoLoad: false);

      // Change to Editorial Aubergine
      await controller.setTheme(AppThemeMode.editorialAubergine);
      expect(controller.currentMode, equals(AppThemeMode.editorialAubergine));
      expect(
        const AppStrings(AppLanguage.english).themeName(controller.currentMode),
        equals('Editorial Aubergine'),
      );
      expect(controller.currentTheme.isDark, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_theme'), equals('editorial_aubergine'));

      // New controller instance loading saved theme
      final newController = ThemeController(autoLoad: false);
      await newController.init();
      expect(newController.currentMode, equals(AppThemeMode.editorialAubergine));
    });

    test('ThemeController safely falls back to Galaxy RL600H on invalid/corrupted pref', () async {
      SharedPreferences.setMockInitialValues({'selected_theme': 'unknown_theme_xyz'});
      final controller = ThemeController(autoLoad: false);
      await controller.init();
      expect(controller.currentMode, equals(AppThemeMode.galaxyRl600h));
    });

    test('Theme presets provide distinct color tokens and polyline styling', () {
      final galaxy = AppTheme.galaxyRl600h;
      final classic = AppTheme.classicNeon;
      final editorial = AppTheme.editorialAubergine;

      // Primary accent colors
      expect(galaxy.primary, equals(const Color(0xFF0EA5E9))); // Electric Cobalt
      expect(classic.primary, equals(const Color(0xFFCCFF00))); // Neon Lime
      expect(editorial.primary, equals(const Color(0xFF51283F))); // Aubergine

      // Core polylines
      expect(galaxy.polylineCore, equals(const Color(0xFF0EA5E9)));
      expect(classic.polylineCore, equals(const Color(0xFFCCFF00)));
      expect(editorial.polylineCore, equals(const Color(0xFF51283F)));
    });
  });

  group('Theme Customization - Widget Tests', () {
    late RideController rideController;
    late ThemeController themeController;
    late MockSupabaseService mockSupabase;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockSupabase = MockSupabaseService();
      rideController = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      themeController = ThemeController(autoLoad: false);
    });

    testWidgets('Dashboard header displays stats button and Settings opens ThemeSelectorSheet',
        (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: rideController,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find stats button in header
      final statsBtn = find.byKey(const Key('stats_button'));
      expect(statsBtn, findsOneWidget);

      // Tap stats button
      await tester.tap(statsBtn);
      await tester.pumpAndSettle();
      expect(find.byType(OverallStatsScreen), findsOneWidget);

      // Pop back to dashboard
      final backBtn = find.byKey(const Key('overall_stats_back_button'));
      await tester.tap(backBtn);
      await tester.pumpAndSettle();

      // Open Settings and tap theme selector tile
      final settingsBtn = find.byKey(const Key('settings_button'));
      await tester.tap(settingsBtn);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);

      final themeTile = find.byKey(const Key('theme_palette_tile'));
      expect(themeTile, findsOneWidget);
      await tester.tap(themeTile);
      await tester.pumpAndSettle();

      // Verify ThemeSelectorSheet is opened
      final strings = const AppStrings(AppLanguage.arabicEgyptian);
      expect(find.byType(ThemeSelectorSheet), findsOneWidget);
      expect(find.textContaining('مظهر التطبيق'), findsWidgets);
      expect(
        find.descendant(
          of: find.byType(ThemeSelectorSheet),
          matching: find.text(strings.themeName(AppThemeMode.galaxyRl600h)),
        ),
        findsOneWidget,
      );
      expect(find.text(strings.themeName(AppThemeMode.classicNeon)), findsOneWidget);
      expect(find.text(strings.themeName(AppThemeMode.editorialAubergine)), findsOneWidget);

      // Select Classic Neon
      await tester.tap(find.text(strings.themeName(AppThemeMode.classicNeon)));
      await tester.pumpAndSettle();

      // Verify theme controller updated
      expect(themeController.currentMode, equals(AppThemeMode.classicNeon));
    });

    testWidgets('RideDetailsScreen respects active ThemeController styling', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testRide = RideModel(
        id: 101,
        clientId: 'theme_test_ride_1',
        startTime: DateTime.now().subtract(const Duration(minutes: 20)),
        durationSeconds: 1200,
        distanceMeters: 4500,
        avgSpeedKmh: 13.5,
        maxSpeedKmh: 24.2,
        minSpeedKmh: 3.1,
        syncStatus: SyncStatus.synced,
        routePoints: const [
          LatLng(30.0444, 31.2357),
          LatLng(30.0450, 31.2365),
        ],
      );

      // Set theme to Editorial Aubergine
      await themeController.setTheme(AppThemeMode.editorialAubergine);

      await tester.pumpWidget(
        MaterialApp(
          home: RideDetailsScreen(
            ride: testRide,
            themeController: themeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify RideDetailsScreen rendered
      expect(find.byType(RideDetailsScreen), findsOneWidget);
      expect(find.text('تفاصيل الرحلة'), findsOneWidget);
      expect(find.text('4.50'), findsOneWidget);
    });
  });
}
