import 'dart:io' show SocketException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';

class MockSupabaseService implements SupabaseService {
  bool isOffline = false;
  final List<RideModel> cloudDatabase = [];
  final List<String> deletedClientIds = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    if (isOffline) {
      throw const SocketException('Offline simulated');
    }
    final existing = cloudDatabase.indexWhere((r) => r.clientId == ride.clientId);
    if (existing >= 0) {
      cloudDatabase[existing] = ride;
    } else {
      cloudDatabase.add(ride);
    }
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    if (isOffline) {
      throw const SocketException('Offline simulated');
    }
    return List<RideModel>.from(cloudDatabase);
  }

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
    if (isOffline) {
      throw const SocketException('Offline simulated');
    }
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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RideModel & RoutePoints Serialization Tests', () {
    test('RideModel serializes and deserializes routePoints cleanly', () {
      final points = [
        const LatLng(30.0444, 31.2357),
        const LatLng(30.0450, 31.2360),
        const LatLng(30.0460, 31.2370),
      ];

      final ride = RideModel(
        clientId: 'route_test_1',
        startTime: DateTime(2026, 10, 24, 10, 0),
        durationSeconds: 1200,
        distanceMeters: 5400.0,
        avgSpeedKmh: 16.2,
        maxSpeedKmh: 24.5,
        minSpeedKmh: 8.0,
        routePoints: points,
      );

      final json = ride.toJson();
      expect(json['route_points'], isA<List>());
      expect((json['route_points'] as List).length, 3);
      expect((json['route_points'] as List)[0], [30.0444, 31.2357]);

      // Test fromJson
      final restoredFromJson = RideModel.fromJson(json);
      expect(restoredFromJson.routePoints.length, 3);
      expect(restoredFromJson.routePoints.first.latitude, 30.0444);
      expect(restoredFromJson.routePoints.first.longitude, 31.2357);

      // Test toLocalJson and fromLocalJson
      final localJson = ride.toLocalJson();
      final restoredFromLocal = RideModel.fromLocalJson(localJson);
      expect(restoredFromLocal.routePoints.length, 3);
      expect(restoredFromLocal.routePoints.last.latitude, 30.0460);
    });

    test('RideModel handles missing or null route_points safely', () {
      final json = {
        'client_id': 'legacy_1',
        'start_time': '2026-10-24T10:00:00.000Z',
        'duration_seconds': 600,
        'distance_meters': 2000.0,
        'avg_speed_kmh': 12.0,
        'max_speed_kmh': 18.0,
        'min_speed_kmh': 6.0,
      };

      final ride = RideModel.fromJson(json);
      expect(ride.routePoints, isEmpty);

      final localRide = RideModel.fromLocalJson(json);
      expect(localRide.routePoints, isEmpty);
    });
  });

  group('RideController Deletion Tests', () {
    test('deleteRide removes ride locally and from remote Supabase', () async {
      final mockSupabase = MockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = FakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Add a ride
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 900,
        distanceMeters: 3000.0,
      );

      expect(controller.ridesHistory.length, 1);
      final rideId = controller.ridesHistory.first.clientId;

      // Delete the ride
      await controller.deleteRide(rideId);

      expect(controller.ridesHistory, isEmpty);
      expect(mockSupabase.deletedClientIds.contains(rideId), isTrue);

      controller.dispose();
    });

    test('deleteRide while offline queues deletion and removes on sync', () async {
      final mockSupabase = MockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = FakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      mockSupabase.isOffline = true;

      // Add a ride while offline
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 900,
        distanceMeters: 3000.0,
      );
      expect(controller.ridesHistory.length, 1);
      final rideId = controller.ridesHistory.first.clientId;

      // Delete while offline
      await controller.deleteRide(rideId);
      expect(controller.ridesHistory, isEmpty);
      expect(controller.pendingSyncCount, 0);

      // Verify queued deletion is stored
      final prefs = await SharedPreferences.getInstance();
      final queued = prefs.getStringList('pending_delete_rides');
      expect(queued, contains(rideId));

      // Restore network and sync
      mockSupabase.isOffline = false;
      await controller.syncPendingRides();

      expect(mockSupabase.deletedClientIds, contains(rideId));
      expect(prefs.getStringList('pending_delete_rides'), isNull);

      controller.dispose();
    });
  });

  group('UI Flow & Widget Tests', () {
    testWidgets('Tapping ride card opens RideDetailsScreen with route polyline and cockpit', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSupabase = MockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = FakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Insert test ride with route points
      final testRide = RideModel(
        clientId: 'tap_details_test_1',
        startTime: DateTime(2026, 10, 24, 15, 30),
        durationSeconds: 1800, // 30 mins
        distanceMeters: 9000.0, // 9.00 km
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 28.5,
        minSpeedKmh: 10.0,
        routePoints: [
          const LatLng(30.0444, 31.2357),
          const LatLng(30.0500, 31.2400),
        ],
      );
      controller.ridesHistory.add(testRide);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to make ride card visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Tap the ride card
      await tester.tap(find.byKey(const Key('ride_tap_details_test_1')));
      await tester.pumpAndSettle();

      // Verify RideDetailsScreen is opened
      expect(find.byType(RideDetailsScreen), findsOneWidget);
      expect(find.text('تفاصيل الرحلة'), findsOneWidget);
      expect(find.text('إجمالي المسافة'), findsOneWidget);
      expect(find.text('18.0 كم/س'), findsOneWidget);
      expect(find.text('28.5 كم/س'), findsOneWidget);
      expect(find.text('10.0 كم/س'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(RideDetailsScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);

      controller.dispose();
    });

    testWidgets('Swipe ride card shows Arabic dialog: Cancel retains, Confirm deletes', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockSupabase = MockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = FakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      final testRide = RideModel(
        clientId: 'swipe_delete_test_1',
        startTime: DateTime(2026, 10, 24, 16, 0),
        durationSeconds: 600,
        distanceMeters: 2500.0,
        avgSpeedKmh: 15.0,
        maxSpeedKmh: 20.0,
        minSpeedKmh: 10.0,
      );
      controller.ridesHistory.add(testRide);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to make ride card visible
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -600));
      await tester.pumpAndSettle();

      // 1. Swipe left to trigger dismissal
      await tester.drag(
        find.byKey(const Key('ride_swipe_delete_test_1')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      // Verify Arabic confirmation dialog appears
      expect(find.text('حذف الرحلة'), findsOneWidget);
      expect(
        find.text(
          'هل أنت متأكد من رغبتك في حذف هذه الرحلة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        findsOneWidget,
      );

      // Tap Cancel ("إلغاء")
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();

      // Ride should STILL be present
      expect(controller.ridesHistory.length, 1);
      expect(find.byKey(const Key('ride_swipe_delete_test_1')), findsOneWidget);

      // 2. Swipe again and tap Delete ("حذف")
      await tester.drag(
        find.byKey(const Key('ride_swipe_delete_test_1')),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('حذف الرحلة'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'حذف'));
      await tester.pumpAndSettle();

      // Ride should now be deleted
      expect(controller.ridesHistory, isEmpty);
      expect(find.text('تم حذف الرحلة بنجاح'), findsOneWidget);

      controller.dispose();
    });
  });
}
