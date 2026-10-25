import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/main.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/live_ride_screen.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/screens/settings_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:bike_track/theme/theme_selector_sheet.dart';

class _FakeSupabaseService extends Fake implements SupabaseService {
  final List<RideModel> rides = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    rides.add(ride);
  }

  @override
  Future<List<RideModel>> getAllRides() async => rides;

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
    rides.removeWhere((r) => r.clientId == clientId);
  }
}

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
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 0;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return const Stream<List<int>>.empty().listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = _MockHttpOverrides();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RTL Layout & Directionality Quality Assurance Tests', () {
    testWidgets('1. BikeTrackApp root MaterialApp establishes RTL direction in Arabic mode',
        (tester) async {
      final rideController = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      expect(localeController.isRtl, isTrue);
      expect(localeController.textDirection, TextDirection.rtl);

      await tester.pumpWidget(
        BikeTrackApp(
          rideController: rideController,
          themeController: themeController,
          localeController: localeController,
        ),
      );
      await tester.pumpAndSettle();

      // Verify Directionality in widget tree is strictly RTL
      final dashboardFinder = find.byType(DashboardScreen);
      expect(dashboardFinder, findsOneWidget);
      final directionality = Directionality.of(tester.element(dashboardFinder));
      expect(directionality, TextDirection.rtl);

      rideController.dispose();
    });

    testWidgets('2. DashboardScreen header places Start items on the Right in RTL',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final rideController = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DashboardScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In RTL:
      // The bike icon is at the start (Right side of screen).
      // The settings button is at the end (Left side of screen).
      final bikeIconRect = tester.getRect(find.byIcon(Icons.directions_bike));
      final settingsBtnRect = tester.getRect(find.byKey(const Key('settings_button')));

      // In RTL, the start element's dx is greater than the end element's dx
      expect(bikeIconRect.center.dx, greaterThan(settingsBtnRect.center.dx),
          reason: 'In RTL, the bike icon must be on the right side of settings button');

      rideController.dispose();
    });

    testWidgets('3. Switching to English dynamically flips Directionality to LTR',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final rideController = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        BikeTrackApp(
          rideController: rideController,
          themeController: themeController,
          localeController: localeController,
        ),
      );
      await tester.pumpAndSettle();

      // Initially RTL
      expect(Directionality.of(tester.element(find.byType(DashboardScreen))), TextDirection.rtl);

      // Switch to English
      await localeController.setLanguage(AppLanguage.english);
      await tester.pumpAndSettle();

      // Now LTR
      expect(Directionality.of(tester.element(find.byType(DashboardScreen))), TextDirection.ltr);

      // In LTR: bike icon is on the Left (smaller dx) than settings button
      final bikeIconRect = tester.getRect(find.byIcon(Icons.directions_bike));
      final settingsBtnRect = tester.getRect(find.byKey(const Key('settings_button')));
      expect(bikeIconRect.center.dx, lessThan(settingsBtnRect.center.dx),
          reason: 'In LTR, the bike icon must be on the left side of settings button');

      rideController.dispose();
    });

    testWidgets('4. LiveRideScreen has RTL Directionality and flipped back arrow',
        (tester) async {
      final controller = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          locale: localeController.flutterLocale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: LiveRideScreen(
            controller: controller,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Directionality is RTL
      final innerScaffold = find.descendant(
        of: find.byType(LiveRideScreen),
        matching: find.byType(Scaffold),
      );
      expect(Directionality.of(tester.element(innerScaffold)), TextDirection.rtl);

      // Verify back button is present and wrapped with Transform.flip (flipX: true)
      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      final transformFinder = find.ancestor(of: backButton, matching: find.byType(Transform));
      expect(transformFinder, findsOneWidget);

      final transform = tester.widget<Transform>(transformFinder);
      // flipX corresponds to matrix transform with m11 == -1.0
      expect(transform.transform.storage[0], equals(-1.0));

      controller.dispose();
    });

    testWidgets('5. SettingsScreen has RTL Directionality and mirrored back arrow in Arabic',
        (tester) async {
      final controller = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          locale: localeController.flutterLocale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: SettingsScreen(
            controller: controller,
            themeController: ThemeController(autoLoad: false),
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final innerScaffold = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scaffold),
      );
      expect(Directionality.of(tester.element(innerScaffold)), TextDirection.rtl);

      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      final transformFinder = find.ancestor(of: backButton, matching: find.byType(Transform));
      expect(transformFinder, findsOneWidget);
      final transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.storage[0], equals(-1.0));

      controller.dispose();
    });

    testWidgets('6. RideDetailsScreen has RTL Directionality and mirrored back arrow in Arabic',
        (tester) async {
      final testRide = RideModel(
        clientId: 'rtl_details_test_1',
        startTime: DateTime(2026, 10, 25, 10, 0),
        durationSeconds: 1200,
        distanceMeters: 5000.0,
        avgSpeedKmh: 15.0,
        maxSpeedKmh: 22.0,
        minSpeedKmh: 8.0,
        routePoints: const [LatLng(30.0444, 31.2357)],
      );
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          locale: localeController.flutterLocale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RideDetailsScreen(
            ride: testRide,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final innerScaffold = find.descendant(
        of: find.byType(RideDetailsScreen),
        matching: find.byType(Scaffold),
      );
      expect(Directionality.of(tester.element(innerScaffold)), TextDirection.rtl);

      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      expect(backButton, findsOneWidget);
      final transformFinder = find.ancestor(of: backButton, matching: find.byType(Transform));
      expect(transformFinder, findsOneWidget);
      final transform = tester.widget<Transform>(transformFinder);
      expect(transform.transform.storage[0], equals(-1.0));
    });

    testWidgets('7. ThemeSelectorSheet renders with RTL Directionality in Arabic mode',
        (tester) async {
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        MaterialApp(
          locale: localeController.flutterLocale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: ThemeSelectorSheet(
              themeController: themeController,
              localeController: localeController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final innerContainer = find.descendant(
        of: find.byType(ThemeSelectorSheet),
        matching: find.byType(ClipRRect),
      );
      expect(Directionality.of(tester.element(innerContainer)), TextDirection.rtl);
    });

    testWidgets('8. Dismissible ride card uses AlignmentDirectional for start & end backgrounds',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final controller = RideController(
        supabaseService: _FakeSupabaseService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final localeController = LocaleController(autoLoad: false);

      final testRide = RideModel(
        clientId: 'rtl_dismiss_test_1',
        startTime: DateTime(2026, 10, 25, 12, 0),
        durationSeconds: 900,
        distanceMeters: 3000.0,
        avgSpeedKmh: 12.0,
        maxSpeedKmh: 18.0,
        minSpeedKmh: 6.0,
      );
      controller.ridesHistory.add(testRide);

      await tester.pumpWidget(
        MaterialApp(
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DashboardScreen(
            controller: controller,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to ride card
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsOneWidget);
      final dismissible = tester.widget<Dismissible>(dismissibleFinder);

      // Verify alignment of background and secondaryBackground are directional
      final bg = dismissible.background as Container;
      final secBg = dismissible.secondaryBackground as Container;
      expect(bg.alignment, AlignmentDirectional.centerStart);
      expect(secBg.alignment, AlignmentDirectional.centerEnd);

      controller.dispose();
    });
  });
}
