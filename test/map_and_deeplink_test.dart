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
  final List<RideModel> insertedRides = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    insertedRides.add(ride);
  }

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

      // Verify OpenStreetMap tile configuration (free, no API key)
      final tileLayerFinder = find.byType(TileLayer);
      expect(tileLayerFinder, findsOneWidget);
      final tileLayer = tester.widget<TileLayer>(tileLayerFinder);
      expect(
        tileLayer.urlTemplate,
        'https://tile.openstreetmap.org/{z}/{x}/{y}.png?v=probike2',
      );
      // No subdomains for OSM
      expect(tileLayer.subdomains, isEmpty);
      // No API key in URL
      expect(tileLayer.urlTemplate!.contains('apikey'), isFalse);
      expect(tileLayer.urlTemplate!.contains('cartocdn'), isFalse);

      // Verify OSM attribution is present in widget tree
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      // No CARTO attribution
      expect(find.textContaining('CARTO'), findsNothing);

      // Verify dark filter is applied via ColorFiltered
      expect(find.byType(ColorFiltered), findsOneWidget);

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

  group('Offline-First Tests', () {
    test('3. Ride saved locally even when Supabase fails', () async {
      SharedPreferences.setMockInitialValues({});

      final failingService = _FailingSupabaseService();
      final controller = RideController(
        supabaseService: failingService,
        notificationService: FakeNotificationService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 5.0));
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0));

      await controller.stopRide();

      // Ride should appear in history despite Supabase failure
      expect(controller.ridesHistory.length, 1);
      expect(controller.ridesHistory.first.distanceMeters, greaterThan(100.0));
      expect(controller.ridesHistory.first.syncStatus, SyncStatus.pending);

      // Verify ride was stored in SharedPreferences pending queue
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('pending_sync_rides');
      expect(raw, isNotNull);
      expect(raw!.contains(controller.ridesHistory.first.clientId), isTrue);

      controller.dispose();
    });

    test('4. Manual ride entry works and appears in history', () async {
      SharedPreferences.setMockInitialValues({});

      final mockService = MockSupabaseService();
      final controller = RideController(
        supabaseService: mockService,
        notificationService: FakeNotificationService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.addManualRide(
        startTime: DateTime(2026, 10, 24, 14, 0),
        durationSeconds: 960, // 16 minutes
        distanceMeters: 5000.0, // 5 km
      );

      expect(controller.ridesHistory.length, 1);
      expect(controller.ridesHistory.first.isManual, isTrue);
      expect(controller.ridesHistory.first.durationSeconds, 960);
      expect(controller.ridesHistory.first.distanceMeters, 5000.0);

      // Avg speed should be calculated correctly: 5km / (960s/3600) = 18.75 km/h
      expect(controller.ridesHistory.first.avgSpeedKmh,
          closeTo(18.75, 0.01));

      // Manual rides have 0.0 for max/min (unknown)
      expect(controller.ridesHistory.first.maxSpeedKmh, 0.0);
      expect(controller.ridesHistory.first.minSpeedKmh, 0.0);

      controller.dispose();
    });

    test('5. client_id prevents duplicate rides on upsert retry', () async {
      SharedPreferences.setMockInitialValues({});

      final ride1 = RideModel(
        startTime: DateTime(2026, 10, 24, 10, 0),
        durationSeconds: 600,
        distanceMeters: 3000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 10.0,
      );

      // Same clientId ride should have same identity
      final ride2 = RideModel(
        clientId: ride1.clientId,
        startTime: ride1.startTime,
        durationSeconds: ride1.durationSeconds,
        distanceMeters: ride1.distanceMeters,
        avgSpeedKmh: ride1.avgSpeedKmh,
        maxSpeedKmh: ride1.maxSpeedKmh,
        minSpeedKmh: ride1.minSpeedKmh,
      );

      expect(ride1 == ride2, isTrue);
      expect(ride1.hashCode, ride2.hashCode);
      expect(ride1.clientId, ride2.clientId);

      // Different rides have different clientIds
      final ride3 = RideModel(
        startTime: DateTime(2026, 10, 24, 11, 0),
        durationSeconds: 600,
        distanceMeters: 3000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 10.0,
      );

      expect(ride1 == ride3, isFalse);
      expect(ride1.clientId != ride3.clientId, isTrue);
    });

    test('6. RideModel serialization roundtrip preserves all fields', () {
      final original = RideModel(
        startTime: DateTime(2026, 10, 24, 14, 30),
        durationSeconds: 1200,
        distanceMeters: 7500.0,
        avgSpeedKmh: 22.5,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 12.0,
        isManual: true,
        syncStatus: SyncStatus.pending,
      );

      // toLocalJson -> fromLocalJson roundtrip
      final json = original.toLocalJson();
      final restored = RideModel.fromLocalJson(json);

      expect(restored.clientId, original.clientId);
      expect(restored.startTime, original.startTime);
      expect(restored.durationSeconds, original.durationSeconds);
      expect(restored.distanceMeters, original.distanceMeters);
      expect(restored.avgSpeedKmh, original.avgSpeedKmh);
      expect(restored.maxSpeedKmh, original.maxSpeedKmh);
      expect(restored.minSpeedKmh, original.minSpeedKmh);
      expect(restored.isManual, isTrue);
      expect(restored.syncStatus, SyncStatus.pending);
    });
  });
}

/// A SupabaseService that always throws to simulate network failure.
class _FailingSupabaseService extends Fake implements SupabaseService {
  @override
  Future<void> insertRide(RideModel ride) async {
    throw Exception('Network unavailable');
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    throw Exception('Network unavailable');
  }
}
