import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/live_ride_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';

const List<int> kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
];

class MockSupabaseService extends Fake implements SupabaseService {
  @override
  Future<void> insertRide(RideModel ride) async {}

  @override
  Future<List<RideModel>> getAllRides() async => [];
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

void configureIPhone14Pro(WidgetTester tester) {
  tester.view.physicalSize = const Size(1179, 2556);
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
    SharedPreferences.setMockInitialValues({});
  });

  group('iPhone 14 Pro Viewport & UX Layout Tests', () {
    testWidgets(
        '1. DashboardScreen renders extreme values without RenderFlex overflow',
        (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );

      // Populate extreme metrics (e.g. 999.99 km, 99:59:59 duration)
      controller.ridesHistory = [
        RideModel(
          id: 1,
          startTime: DateTime.now(),
          durationSeconds: 359999, // 99 hours 59 mins 59 secs
          distanceMeters: 999990.0, // ~999.99 km
          avgSpeedKmh: 88.8,
          maxSpeedKmh: 125.4,
          minSpeedKmh: 12.0,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no yellow/black overflow error occurred
      expect(tester.takeException(), isNull);
      const strings = AppStrings(AppLanguage.arabicEgyptian);
      expect(find.text(strings.appName), findsOneWidget);
      expect(find.text(strings.appSubtitle), findsOneWidget);

      controller.dispose();
    });

    testWidgets('2. Tap [+ 5] and [- 5] updates reminder interval live',
        (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('30 دقيقة'), findsOneWidget);

      final strings = const AppStrings(AppLanguage.arabicEgyptian);

      // Scroll until buttons are visible above the bottom action bar
      await tester.scrollUntilVisible(find.text(strings.reminderIncrease), 200);
      await tester.tap(find.text(strings.reminderIncrease));
      await tester.pumpAndSettle();
      expect(find.textContaining('35 دقيقة'), findsOneWidget);

      await tester.scrollUntilVisible(find.text(strings.reminderDecrease), 200);
      await tester.tap(find.text(strings.reminderDecrease));
      await tester.pumpAndSettle();
      expect(find.textContaining('30 دقيقة'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('3. Tap Start Ride navigates to LiveRideScreen', (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      final strings = const AppStrings(AppLanguage.arabicEgyptian);

      // Find Start Ride Button
      final startButton = find.text(strings.startRideButtonIdle);
      expect(startButton, findsOneWidget);

      await tester.tap(startButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // LiveRideScreen should now be in tree
      expect(find.byType(LiveRideScreen), findsOneWidget);
      expect(find.textContaining(strings.liveGpsLocked), findsOneWidget);

      controller.dispose();
    });

    testWidgets(
        '4. LiveRideScreen cockpit metrics & Stop Ride button returns to Dashboard',
        (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        autoFetchHistory: false,
      );
      await controller.startRide();

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final strings = const AppStrings(AppLanguage.arabicEgyptian);

      await tester.tap(find.textContaining(strings.startRideButtonRiding));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LiveRideScreen), findsOneWidget);
      expect(find.text(strings.liveDistanceCrushed), findsOneWidget);
      expect(find.text(strings.liveCurrentSpeed), findsOneWidget);
      expect(find.text(strings.liveMaxSpeed), findsOneWidget);
      expect(find.text(strings.liveMinSpeed), findsOneWidget);

      // Verify Pause button exists
      final pauseButton = find.text(strings.livePauseButton);
      expect(pauseButton, findsOneWidget);

      final stopButton = find.text(strings.liveFinishButton);
      expect(stopButton, findsOneWidget);

      // Quick tap does NOT stop (Hold-to-stop protection)
      await tester.tap(stopButton);
      await tester.pumpAndSettle();
      expect(controller.isRiding, true);

      // Hold for 950ms triggers hold-to-stop
      final gesture = await tester.startGesture(tester.getCenter(stopButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 950));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(controller.isRiding, false);
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LiveRideScreen), findsNothing);

      controller.dispose();
    });
  });
}
