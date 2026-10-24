import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/live_ride_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:flutter_map/flutter_map.dart';

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

class FakeNotificationService implements INotificationService {
  final List<String> log = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showNotification(int id, String title, String body) async {
    log.add('show:$id');
  }

  @override
  Future<void> periodicallyShowWithDuration(
    int id,
    String title,
    String body,
    Duration repeatDuration,
  ) async {
    log.add('periodicallyShow:$id:${repeatDuration.inMinutes}');
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel:$id');
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

Position createTestPosition(double lat, double lng, double speedMps) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 3.0,
    altitude: 15.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speedMps,
    speedAccuracy: 0.5,
  );
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

  setUp(() {
    HttpOverrides.global = _MockHttpOverrides();
    SharedPreferences.setMockInitialValues({});
  });

  group('Map Hardening, Cockpit Live Updates & Attribution Tests', () {
    testWidgets(
        '1. GPS update before & after onMapReady, 4 cockpit metrics update, OSM attribution',
        (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        notificationService: FakeNotificationService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // 1. Send first GPS update BEFORE map is pumped
      await controller.startRide();
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 5.0)); // 18.0 km/h

      await tester.pumpWidget(
        MaterialApp(
          home: LiveRideScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify cockpit metrics rendered accurately
      expect(find.text('السرعة الآن'), findsOneWidget);
      expect(find.text('18.0'), findsWidgets); // Speed 18.0 km/h
      expect(find.text('المسافة'), findsOneWidget);
      expect(find.text('أقصى سرعة'), findsOneWidget);
      expect(find.text('أدنى سرعة'), findsOneWidget);

      // Verify CartoDB Dark Matter tile configuration (free non-retina endpoint)
      final tileLayerFinder = find.byType(TileLayer);
      expect(tileLayerFinder, findsOneWidget);
      final tileLayer = tester.widget<TileLayer>(tileLayerFinder);
      expect(
        tileLayer.urlTemplate,
        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
      );
      expect(tileLayer.subdomains, ['a', 'b', 'c', 'd']);

      // Verify CARTO & OSM attribution is present in widget tree
      expect(find.textContaining('CARTO'), findsOneWidget);
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);

      // Only 1 point: PolylineLayer must NOT be rendered yet (requires >= 2 points)
      expect(find.byType(PolylineLayer), findsNothing);

      // Verify markers on MarkerLayer: 12x12 start dot and 42x42 compact puck
      final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
      expect(
        markerLayer.markers.any((m) => m.width == 12 && m.height == 12),
        isTrue,
        reason: '12x12 start dot marker should be present',
      );
      expect(
        markerLayer.markers.any((m) => m.width == 42 && m.height == 42),
        isTrue,
        reason: '42x42 live position navigation puck should be present',
      );

      // 2. Send second GPS update AFTER map is ready
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 8.0)); // 28.8 km/h
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('28.8'), findsWidgets);

      // 2 points now: PolylineLayer must be rendered with 2-layer neon styling
      expect(find.byType(PolylineLayer), findsOneWidget);
      final polylineLayer =
          tester.widget<PolylineLayer>(find.byType(PolylineLayer));
      expect(polylineLayer.polylines.length, 2);
      expect(
        polylineLayer.polylines[0].color,
        const Color(0xFFCCFF00).withValues(alpha: 0.35),
      );
      expect(polylineLayer.polylines[1].color, const Color(0xFFCCFF00));

      // 3. Tap Glass Recenter Button
      final recenterFinder = find.byIcon(Icons.my_location_rounded);
      expect(recenterFinder, findsOneWidget);
      await tester.tap(recenterFinder);
      await tester.pump();

      controller.dispose();
    });

    testWidgets('2. Deep link workflow simulation: Start ride and Stop ride navigation',
        (tester) async {
      configureIPhone14Pro(tester);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
      });

      final controller = RideController(
        supabaseService: MockSupabaseService(),
        notificationService: FakeNotificationService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      final navKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LiveRideScreen), findsNothing);

      // Simulate cycletrack://start
      final started = await controller.startRide();
      expect(started, isTrue);

      navKey.currentState!.push(
        MaterialPageRoute(
          builder: (_) => LiveRideScreen(controller: controller),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LiveRideScreen), findsOneWidget);

      // Duplicate tap protection: startRide returns true immediately without resetting state
      final duplicateStart = await controller.startRide();
      expect(duplicateStart, isTrue);
      expect(controller.isRiding, isTrue);

      // Simulate cycletrack://stop
      await controller.stopRide();
      expect(controller.isRiding, isFalse);
      navKey.currentState!.popUntil((route) => route.isFirst);
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(LiveRideScreen), findsNothing);

      controller.dispose();
    });
  });
}
