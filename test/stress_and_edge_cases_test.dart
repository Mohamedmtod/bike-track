import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';

class ChaosMockSupabaseService implements SupabaseService {
  bool isOffline = false;
  Exception? nextInsertError;
  int failAfterInserts = -1;
  int successfulInsertsCount = 0;
  final List<RideModel> cloudDatabase = [];
  int insertCallCount = 0;

  @override
  Future<void> insertRide(RideModel ride) async {
    insertCallCount++;
    if (failAfterInserts >= 0 && successfulInsertsCount >= failAfterInserts) {
      throw const SocketException('Simulated network drop in middle of batch');
    }
    if (nextInsertError != null) {
      throw nextInsertError!;
    }
    if (isOffline) {
      throw const SocketException('Simulated offline network blackout');
    }
    final existingIdx =
        cloudDatabase.indexWhere((r) => r.clientId == ride.clientId);
    if (existingIdx >= 0) {
      cloudDatabase[existingIdx] = ride;
    } else {
      cloudDatabase.add(ride);
    }
    successfulInsertsCount++;
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    if (isOffline) {
      throw const SocketException('Simulated offline network blackout');
    }
    return List<RideModel>.from(cloudDatabase);
  }
}

class FakeNotificationService implements INotificationService {
  final List<String> notifications = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showNotification(int id, String title, String body) async {
    notifications.add('show:$id:$title');
  }

  @override
  Future<void> periodicallyShowWithDuration(
    int id,
    String title,
    String body,
    Duration repeatDuration,
  ) async {
    notifications.add('periodic:$id:${repeatDuration.inMinutes}');
  }

  @override
  Future<void> cancel(int id) async {
    notifications.add('cancel:$id');
  }
}

class ChaosFakeTelemetryService implements ITelemetryService {
  String? sessionId;
  final List<Map<String, dynamic>> loggedEvents = [];
  int cleanCallCount = 0;
  int flushCallCount = 0;
  bool isDisposed = false;

  @override
  String? get currentSessionId => sessionId;

  @override
  int get bufferSize => loggedEvents.length;

  @override
  void startSession(String id) {
    sessionId = id;
  }

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
  }) {
    loggedEvents.add({
      'event_type': eventType,
      'latitude': latitude,
      'longitude': longitude,
      'speed_mps': speedMps,
      'accuracy': accuracy,
      'reason': reason,
      'metadata': metadata,
      'timestamp': timestamp ?? DateTime.now(),
    });
  }

  @override
  Future<void> flush() async {
    flushCallCount++;
  }

  @override
  Future<void> cleanOldLogs([int days = 14]) async {
    cleanCallCount++;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}

Position createPosition({
  required double latitude,
  required double longitude,
  required double speedMps,
  double accuracy = 3.0,
  DateTime? timestamp,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp ?? DateTime.now(),
    accuracy: accuracy,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speedMps,
    speedAccuracy: 0.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GROUP A: SIMPLEST EVERYDAY SCENARIOS', () {
    test(
        'Scenario 1 (Standard Short Ride - Happy Path): '
        '3 mins at 18 km/h, stop online, accurate metrics & clean upload',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      final started = await controller.startRide();
      expect(started, isTrue);
      expect(controller.isRiding, isTrue);

      // Anchor point (1st accepted point)
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );

      // Simulate 180 seconds of riding at 18 km/h (5.0 m/s)
      // Feed a point every 5 seconds (36 points)
      double currentLat = 30.0444;
      for (int i = 1; i <= 36; i++) {
        currentLat += 0.000225; // 25 meters every 5 seconds = 5.0 m/s
        controller.tickTimerForTest(5);
        controller.processPositionUpdate(
          createPosition(
            latitude: currentLat,
            longitude: 31.2357,
            speedMps: 5.0, // 18.0 km/h
          ),
        );
      }

      expect(controller.durationSeconds, 180);
      expect(controller.currentSpeedKmh, closeTo(18.0, 0.1));
      expect(controller.maxSpeedKmh, closeTo(18.0, 0.1));
      expect(controller.minSpeedKmh, closeTo(18.0, 0.1));
      expect(controller.distanceMeters, closeTo(900.0, 20.0));

      // Stop ride while online
      await controller.stopRide();

      expect(controller.isRiding, isFalse);
      expect(controller.ridesHistory.length, 1);
      final savedRide = controller.ridesHistory.first;
      expect(savedRide.syncStatus, SyncStatus.synced);
      expect(savedRide.durationSeconds, 180);
      expect(savedRide.avgSpeedKmh, closeTo(18.0, 0.5));
      expect(savedRide.maxSpeedKmh, closeTo(18.0, 0.1));
      expect(savedRide.minSpeedKmh, closeTo(18.0, 0.1));
      expect(savedRide.distanceMeters, closeTo(900.0, 20.0));

      // Verified uploaded to Supabase cloud
      expect(mockSupabase.cloudDatabase.length, 1);
      expect(mockSupabase.cloudDatabase.first.clientId, savedRide.clientId);
      expect(controller.pendingSyncCount, 0);

      controller.dispose();
    });

    test(
        'Scenario 2 (Instant Stop / Zero Movement Ride): '
        'Immediate stop at 0s & 0m -> avgSpeed == 0.0, strictly no NaN/Infinity, clean reset',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      expect(controller.isRiding, isTrue);

      // Stop immediately with 0s and 0m
      await controller.stopRide();

      expect(controller.isRiding, isFalse);
      expect(controller.durationSeconds, 0);
      expect(controller.distanceMeters, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);

      expect(controller.ridesHistory.length, 1);
      final zeroRide = controller.ridesHistory.first;
      expect(zeroRide.avgSpeedKmh, 0.0);
      expect(zeroRide.avgSpeedKmh.isNaN, isFalse);
      expect(zeroRide.avgSpeedKmh.isInfinite, isFalse);
      expect(zeroRide.maxSpeedKmh, 0.0);
      expect(zeroRide.minSpeedKmh, 0.0);

      controller.dispose();
    });

    test(
        'Scenario 3 (Stationary Timeout Ride): '
        '10 minutes sitting still with noisy indoor GPS -> distance 0m, maxSpeed 0, minSpeed 0',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Sit still for 10 minutes (600s). Noisy GPS points with 45m accuracy and Doppler 0.2 m/s
      for (int i = 0; i < 20; i++) {
        controller.tickTimerForTest(30);
        controller.processPositionUpdate(
          createPosition(
            latitude: 30.0444 + (i * 0.000001),
            longitude: 31.2357,
            speedMps: 0.2, // 0.72 km/h (Doppler stationary <= 2.5 km/h)
            accuracy: 45.0, // Inaccurate indoor GPS > 20m
          ),
        );
      }

      expect(controller.durationSeconds, 600);
      expect(controller.distanceMeters, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);

      await controller.stopRide();

      final stationaryRide = controller.ridesHistory.first;
      expect(stationaryRide.durationSeconds, 600);
      expect(stationaryRide.distanceMeters, 0.0);
      expect(stationaryRide.avgSpeedKmh, 0.0);
      expect(stationaryRide.maxSpeedKmh, 0.0);
      expect(stationaryRide.minSpeedKmh, 0.0);

      controller.dispose();
    });
  });

  group('GROUP B: REAL-WORLD STREET & HARDWARE GLITCH SCENARIOS', () {
    test(
        'Scenario 4 (20x NFC Rapid-Fire Spam on Bumpy Road): '
        '20 rapid startRide calls do not reset startTime, distance, or sessionId',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      final initialStartTime = controller.startTime;
      final initialSessionId = controller.currentSessionId;

      // Anchor point + movement
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0450, longitude: 31.2357, speedMps: 5.0),
      );
      final accumulatedDistance = controller.distanceMeters;
      expect(accumulatedDistance, greaterThan(50.0));

      // Simulate 20 rapid NFC taps while cycling on a bumpy road
      for (int i = 0; i < 20; i++) {
        final res = await controller.startRide();
        expect(res, isTrue);
      }

      // Verify active state remains 100% stable and intact
      expect(controller.isRiding, isTrue);
      expect(controller.startTime, initialStartTime);
      expect(controller.currentSessionId, initialSessionId);
      expect(controller.distanceMeters, accumulatedDistance);

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 5 (Stop-and-Go Traffic Lights): '
        'Stop at red light for 60s -> speed drops to 0.0, minSpeed remains 12.0 km/h (not 0.0)',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // 1. Initial ride at 20 km/h (5.55 m/s)
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.55),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0450, longitude: 31.2357, speedMps: 5.55),
      );
      expect(controller.currentSpeedKmh, closeTo(20.0, 0.5));
      expect(controller.minSpeedKmh, closeTo(20.0, 0.5));

      // 2. Stop at red light: stationary point (speed = 0.0)
      controller.processPositionUpdate(
        createPosition(latitude: 30.0450, longitude: 31.2357, speedMps: 0.0),
      );
      // Speed immediately zeroed by stationary Doppler filter
      expect(controller.currentSpeedKmh, 0.0);
      // Crucial: minSpeedKmh is NOT polluted by 0.0!
      expect(controller.minSpeedKmh, closeTo(20.0, 0.5));

      // Wait 60 seconds at the light
      controller.setLastPositionTimeForTest(
        DateTime.now().subtract(const Duration(seconds: 4)),
      );
      controller.tickTimerForTest(60);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, closeTo(20.0, 0.5));

      // 3. Resume at 12 km/h (3.33 m/s)
      controller.processPositionUpdate(
        createPosition(latitude: 30.0455, longitude: 31.2357, speedMps: 3.33),
      );
      expect(controller.currentSpeedKmh, closeTo(12.0, 0.5));
      // minSpeed updated from 20.0 to 12.0 km/h (never 0.0)
      expect(controller.minSpeedKmh, closeTo(12.0, 0.5));

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 6 (GPS Tunnel Teleportation Spike): '
        'Corrupted 5km spike rejected as GPS_REJECTED, distance & maxSpeed uncorrupted',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Normal ride segment at 18 km/h (5.0 m/s)
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0446, longitude: 31.2357, speedMps: 5.0),
      );
      final preSpikeDistance = controller.distanceMeters;
      final preSpikeMaxSpeed = controller.maxSpeedKmh;

      // Inject corrupted spike: teleport 5km away with 162 km/h (45 m/s) speed
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0900, // ~5km jump
          longitude: 31.2357,
          speedMps: 45.0, // 162 km/h > 65 km/h
          accuracy: 5.0,
        ),
      );

      // Inject another corrupted spike with accuracy 80m > 20m
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0950,
          longitude: 31.2357,
          speedMps: 5.0,
          accuracy: 80.0,
        ),
      );

      // Verify spikes were completely rejected
      expect(controller.distanceMeters, preSpikeDistance);
      expect(controller.maxSpeedKmh, preSpikeMaxSpeed);

      final rejections = mockTelemetry.loggedEvents
          .where((e) => e['event_type'] == 'GPS_REJECTED')
          .toList();
      expect(rejections.length, 2);
      expect(rejections[0]['reason'], 'speed_spike');
      expect(rejections[1]['reason'], 'accuracy');

      // Continue riding normally: points accepted
      controller.processPositionUpdate(
        createPosition(latitude: 30.0449, longitude: 31.2357, speedMps: 5.0),
      );
      expect(controller.distanceMeters, greaterThan(preSpikeDistance));

      await controller.stopRide();
      controller.dispose();
    });
  });

  group('GROUP C: WORST-CASE CATASTROPHIC FAILURE SCENARIOS', () {
    test(
        'Scenario 7 (Multi-Ride Complete Offline Blackout + App Restart): '
        '5 rides completed offline, app restart retains all in pending queue, sync restores all cleanly',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      // Force Supabase network blackout
      mockSupabase.isOffline = true;

      final controller1 = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Complete 5 separate rides while totally offline
      for (int r = 1; r <= 5; r++) {
        await controller1.startRide();
        controller1.tickTimerForTest(60);
        controller1.processPositionUpdate(
          createPosition(
            latitude: 30.0444,
            longitude: 31.2357,
            speedMps: 5.0,
          ),
        );
        controller1.processPositionUpdate(
          createPosition(
            latitude: 30.0444 + (r * 0.001),
            longitude: 31.2357,
            speedMps: 5.0,
          ),
        );
        await controller1.stopRide();
      }

      expect(controller1.ridesHistory.length, 5);
      expect(controller1.pendingSyncCount, 5);
      // Supabase has 0 rides because network is offline
      expect(mockSupabase.cloudDatabase.isEmpty, isTrue);

      controller1.dispose();

      // Simulate killing the app and reopening it while STILL offline
      final controller2 = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: true, // Will load cached & pending rides
        autoLoadPreferences: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller2.ridesHistory.length, 5);
      expect(controller2.pendingSyncCount, 5);

      // Now restore network connection!
      mockSupabase.isOffline = false;

      // Trigger sync
      await controller2.syncPendingRides();

      // All 5 rides uploaded to Supabase cloud!
      expect(mockSupabase.cloudDatabase.length, 5);
      expect(controller2.pendingSyncCount, 0);
      expect(controller2.ridesHistory.length, 5);
      expect(
        controller2.ridesHistory.every((r) => r.syncStatus == SyncStatus.synced),
        isTrue,
      );

      controller2.dispose();
    });

    test(
        'Scenario 8 (Sudden iPhone Battery Death at 0% Mid-Ride): '
        '4.5km / 20min ride interrupted by battery death is recovered from snapshot on next boot',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller1 = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller1.startRide();
      // Accumulate 20 mins (1200s) and 4500m
      controller1.tickTimerForTest(1200);
      controller1.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller1.processPositionUpdate(
        createPosition(
          latitude: 30.0849, // ~4500 meters
          longitude: 31.2357,
          speedMps: 6.25, // 22.5 km/h
        ),
      );

      expect(controller1.durationSeconds, 1200);
      expect(controller1.distanceMeters, closeTo(4500.0, 50.0));

      // Force save active ride snapshot (simulating periodic 10s timer)
      await controller1.saveActiveRideSnapshotForTest();

      // Simulate iPhone sudden battery shutdown: dispose WITHOUT stopRide()!
      controller1.dispose();
      mockSupabase.isOffline = true; // Phone boots up before network re-establishes

      // Phone turns back on: create fresh RideController
      final controller2 = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: true, // Calls _initOfflineFirst which triggers _recoverInterruptedRide
        autoLoadPreferences: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Interrupted 4.5km / 20min ride was recovered!
      expect(controller2.ridesHistory.length, 1);
      final recovered = controller2.ridesHistory.first;
      expect(recovered.durationSeconds, 1200);
      expect(recovered.distanceMeters, closeTo(4500.0, 50.0));
      expect(recovered.avgSpeedKmh, closeTo(13.5, 0.5));
      expect(recovered.syncStatus, SyncStatus.pending);

      // Queued for Supabase sync
      expect(controller2.pendingSyncCount, 1);

      // Now network is re-established and sync is triggered
      mockSupabase.isOffline = false;
      await controller2.syncPendingRides();
      expect(mockSupabase.cloudDatabase.length, 1);
      expect(controller2.pendingSyncCount, 0);
      expect(recovered.syncStatus, SyncStatus.synced);

      controller2.dispose();
    });

    test(
        'Scenario 9 (Flaky Network / Duplicate Upsert Idempotency): '
        'Syncing twice with same clientId never creates duplicate entries in dashboard',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      final ride = RideModel(
        clientId: 'idempotency_test_ride_123',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 1800,
        distanceMeters: 8000.0,
        avgSpeedKmh: 16.0,
        maxSpeedKmh: 24.0,
        minSpeedKmh: 10.0,
      );

      // Add ride once
      controller.ridesHistory.add(ride);
      await mockSupabase.insertRide(ride);

      // Simulate second sync reception with identical clientId
      final duplicateRide = RideModel(
        clientId: 'idempotency_test_ride_123',
        startTime: ride.startTime,
        durationSeconds: 1800,
        distanceMeters: 8000.0,
        avgSpeedKmh: 16.0,
        maxSpeedKmh: 24.0,
        minSpeedKmh: 10.0,
      );

      // Upsert into Supabase (mock cloud DB)
      await mockSupabase.insertRide(duplicateRide);
      expect(mockSupabase.cloudDatabase.length, 1);

      // Fetch history merging deduplicates
      await controller.fetchHistory();

      // Exactly 1 ride in history, zero duplicate
      expect(controller.ridesHistory.length, 1);
      expect(controller.ridesHistory.first.clientId, 'idempotency_test_ride_123');

      controller.dispose();
    });

    testWidgets(
        'Scenario 10 (4-Hour Marathon Endurance Ride + Telemetry Buffer Cap): '
        '1,000+ offline GPS logs capped at 500 in TelemetryService, UI renders large marathon numbers without overflow',
        (tester) async {
      // 1. Verify TelemetryService buffer capping at 500 entries
      final realTelemetry = TelemetryService();
      realTelemetry.startSession('marathon_session_001');

      // Log 1,200 events while offline
      for (int i = 1; i <= 1200; i++) {
        realTelemetry.logEvent(
          eventType: 'GPS_ACCEPTED',
          latitude: 30.0444 + (i * 0.0001),
          longitude: 31.2357,
          speedMps: 8.33,
          accuracy: 3.0,
          metadata: {'step': i},
        );
      }

      // In-memory buffer capped at 500
      expect(realTelemetry.bufferSize, 500);

      // SharedPreferences persistence also capped at 500
      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString('telemetry_queue');
      expect(rawQueue, isNotNull);
      final List<dynamic> storedQueue = jsonDecode(rawQueue!) as List<dynamic>;
      expect(storedQueue.length, 500);

      realTelemetry.dispose();

      // 2. UI Endurance Layout Test: 4-Hour Marathon (14,400s) & 120 km (120,000m)
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Add a 4-hour marathon ride
      final marathonRide = RideModel(
        clientId: 'marathon_4h_120km',
        startTime: DateTime.now().subtract(const Duration(hours: 4)),
        durationSeconds: 14400, // 4 hours
        distanceMeters: 120000.0, // 120 km
        avgSpeedKmh: 30.0,
        maxSpeedKmh: 58.4,
        minSpeedKmh: 14.2,
        syncStatus: SyncStatus.synced,
      );
      controller.ridesHistory.add(marathonRide);

      // Configure iPhone 14 Pro Viewport (393 x 852)
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Pump DashboardScreen
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no overflow error on Dashboard
      expect(tester.takeException(), isNull);
      expect(find.text('120.00'), findsWidgets); // 120 km distance in hero & card
      expect(find.textContaining('58.4'), findsWidgets); // max speed '58.4 كم/س'

      controller.dispose();
    });
  });

  group('GROUP D: iOS LIFECYCLE & POWER EDGE CASES', () {
    test(
        'Scenario 11 (Background / Phone Call / Wall-Clock Duration): '
        '15-minute background delay correctly updates wall-clock duration and avgSpeed',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      // Simulate phone call / background throttling where startTime was 15 mins (900s) ago
      // but internal timer only ticked 30 seconds
      controller.startTime =
          DateTime.now().subtract(const Duration(seconds: 900));
      controller.durationSeconds = 30;
      controller.distanceMeters = 4500.0; // 4.5 km

      await controller.stopRide();

      expect(controller.durationSeconds, greaterThanOrEqualTo(900));
      final ride = controller.ridesHistory.first;
      expect(ride.durationSeconds, greaterThanOrEqualTo(900));
      expect(ride.avgSpeedKmh, closeTo(18.0, 0.5));
      expect(ride.avgSpeedKmh.isNaN, isFalse);

      controller.dispose();
    });

    test(
        'Scenario 12 (Low Power Mode / GPS Frequency Reduction): '
        '25-second gap between GPS points updates distance and current speed cleanly',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Anchor point
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );

      // Simulate 25 seconds of silence in Low Power Mode
      controller.setLastPositionTimeForTest(
        DateTime.now().subtract(const Duration(seconds: 25)),
      );
      controller.tickTimerForTest(25);
      expect(controller.currentSpeedKmh, 0.0);

      // New point arrives 125 meters away at 5.0 m/s (18 km/h)
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0455, // ~125m step
          longitude: 31.2357,
          speedMps: 5.0,
        ),
      );

      expect(controller.distanceMeters, greaterThan(100.0));
      expect(controller.currentSpeedKmh, closeTo(18.0, 0.5));

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 13 (Timezone or Clock Skew - Clock moving backwards): '
        'Backward clock shift does not cause negative duration or NaN avgSpeed',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      // Simulate system clock moving forward into future then backwards
      controller.startTime = DateTime.now().add(const Duration(minutes: 30));
      controller.durationSeconds = -100;

      await controller.stopRide();

      expect(controller.durationSeconds, greaterThanOrEqualTo(0));
      final ride = controller.ridesHistory.first;
      expect(ride.durationSeconds, greaterThanOrEqualTo(0));
      expect(ride.avgSpeedKmh, 0.0);
      expect(ride.avgSpeedKmh.isNaN, isFalse);

      controller.dispose();
    });

    test(
        'Scenario 14 (Airplane Mode / No A-GPS Assistance - Degraded Accuracy to 19m): '
        'Points with accuracy 18.5m are accepted as they fall within the 20m threshold',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Anchor point
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0444,
          longitude: 31.2357,
          speedMps: 4.0,
          accuracy: 18.5, // degraded but <= 20.0m
        ),
      );

      // Movement points with 19.0m accuracy
      for (int i = 1; i <= 5; i++) {
        controller.processPositionUpdate(
          createPosition(
            latitude: 30.0444 + (i * 0.0001),
            longitude: 31.2357,
            speedMps: 4.0,
            accuracy: 19.0,
          ),
        );
      }

      expect(controller.distanceMeters, greaterThan(30.0));
      expect(controller.routePoints.length, 6);

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 15 (Location Permission Revoked Mid-Ride): '
        'Error logged cleanly to telemetry, controller remains responsive to stop and save',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0448, longitude: 31.2357, speedMps: 5.0),
      );

      // Simulate location permission revocation
      controller.logTelemetryError('location_permission_revoked_mid_ride', {
        'permission': 'denied',
      });

      expect(controller.isRiding, isTrue);
      final errorEvents = mockTelemetry.loggedEvents
          .where((e) => e['event_type'] == 'ERROR')
          .toList();
      expect(errorEvents.length, 1);
      expect(errorEvents.first['reason'],
          'location_permission_revoked_mid_ride');

      // User stops ride safely
      await controller.stopRide();
      expect(controller.isRiding, isFalse);
      expect(controller.ridesHistory.length, 1);

      controller.dispose();
    });
  });

  group('GROUP E: STREET TERRAIN & CYCLING PHYSICS', () {
    test(
        'Scenario 16 (Downhill Sprint at 62 km/h): '
        'Speeds below 65 km/h accepted, maxSpeed recorded at 62.0 km/h',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );

      // Accelerate to 62 km/h (17.22 m/s) on downhill
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0450,
          longitude: 31.2357,
          speedMps: 17.22, // 62.0 km/h
        ),
      );

      expect(controller.currentSpeedKmh, closeTo(62.0, 0.5));
      expect(controller.maxSpeedKmh, closeTo(62.0, 0.5));

      // Decelerate to 25 km/h
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0455,
          longitude: 31.2357,
          speedMps: 6.94, // 25.0 km/h
        ),
      );
      expect(controller.currentSpeedKmh, closeTo(25.0, 0.5));
      expect(controller.maxSpeedKmh, closeTo(62.0, 0.5));

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 17 (Tunnel / Underpass Outage for 2 Minutes): '
        '2 minutes silence followed by valid point 600m away resumes tracking cleanly',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0447, longitude: 31.2357, speedMps: 5.0),
      );
      final preTunnelDist = controller.distanceMeters;

      // Enter tunnel: 120 seconds of no updates
      controller.tickTimerForTest(120);

      // Exit tunnel: point 600m ahead at 15 m/s (54 km/h <= 65 km/h)
      controller.processPositionUpdate(
        createPosition(
          latitude: 30.0501, // ~600m step
          longitude: 31.2357,
          speedMps: 15.0,
        ),
      );

      expect(controller.distanceMeters, greaterThan(preTunnelDist + 500.0));
      expect(controller.currentSpeedKmh, closeTo(54.0, 0.5));

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 18 (Velodrome / Roundabout Circular Track): '
        'Circular path updates accepted without being blocked by micro-jitter filter',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Center around 30.0444, 31.2357 with radius ~25m (0.00022 deg)
      final centerLat = 30.0444;
      final centerLng = 31.2357;
      final radiusDeg = 0.00022;

      for (int i = 0; i < 8; i++) {
        final angle = (i * 2 * pi) / 8;
        final lat = centerLat + (radiusDeg * sin(angle));
        final lng = centerLng + (radiusDeg * cos(angle));
        controller.processPositionUpdate(
          createPosition(
            latitude: lat,
            longitude: lng,
            speedMps: 5.55, // 20 km/h
          ),
        );
      }

      // First point anchor + 7 points around the circle
      expect(controller.routePoints.length, 8);
      expect(controller.distanceMeters, greaterThan(100.0));

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 19 (Elevator Climb after Ride - Vertical without Horizontal): '
        'Vertical climb with horizontal speed 0.0 is rejected, distance uncorrupted',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Ride before entering elevator
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      controller.processPositionUpdate(
        createPosition(latitude: 30.0448, longitude: 31.2357, speedMps: 5.0),
      );
      final finalBikeDist = controller.distanceMeters;

      // Elevator ascends 10 floors: horizontal speed is 0.0, tiny drift < 1m
      for (int f = 1; f <= 10; f++) {
        controller.processPositionUpdate(
          createPosition(
            latitude: 30.0448 + (f * 0.000001), // tiny jitter
            longitude: 31.2357,
            speedMps: 0.0, // horizontal speed 0
            accuracy: 6.0,
          ),
        );
      }

      expect(controller.distanceMeters, finalBikeDist);
      final stationaryRejections = mockTelemetry.loggedEvents
          .where((e) => e['reason'] == 'stationary')
          .toList();
      expect(stationaryRejections.length, 10);

      await controller.stopRide();
      controller.dispose();
    });

    test(
        'Scenario 20 (Severe Handlebar Shaking during Maintenance): '
        'Violent mount vibrations without horizontal progress rejected as micro_jitter/stationary',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
        createPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 3.0),
      );

      // Rapid vibration jitter back and forth by 1.5 meters (< 3.0m threshold)
      for (int i = 0; i < 20; i++) {
        final offset = (i % 2 == 0) ? 0.00001 : -0.00001; // ~1 meter
        controller.processPositionUpdate(
          createPosition(
            latitude: 30.0444 + offset,
            longitude: 31.2357,
            speedMps: 0.2, // Doppler <= 2.5 km/h
            accuracy: 5.0,
          ),
        );
      }

      expect(controller.distanceMeters, 0.0);
      expect(controller.routePoints.length, 1); // Only anchor

      await controller.stopRide();
      controller.dispose();
    });
  });

  group('GROUP F: STORAGE RESILIENCE & CONCURRENCY', () {
    test(
        'Scenario 21 (Corrupted SharedPreferences JSON Strings): '
        'Corrupted storage entries self-heal without crashing and controller starts cleanly',
        () async {
      final prefs = await SharedPreferences.getInstance();
      // Inject corrupted JSON
      await prefs.setString(
          'pending_sync_rides', '{corrupted_json:[missing_brackets');
      await prefs.setString('cached_rides_history', '###INVALID###');

      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      // Initialize controller with autoFetchHistory
      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: true,
        autoLoadPreferences: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.ridesHistory, isEmpty);
      expect(controller.pendingSyncCount, 0);

      // Verify corrupted keys were cleaned / healed
      expect(prefs.getString('pending_sync_rides'), isNull);
      final cachedRaw = prefs.getString('cached_rides_history');
      expect(cachedRaw == null || cachedRaw == '[]', isTrue);

      controller.dispose();
    });

    test(
        'Scenario 22 (Concurrent stopRide() and addManualRide()): '
        'Simultaneous stop and manual add safely creates 2 distinct rides without race condition',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.tickTimerForTest(300);
      controller.distanceMeters = 2000.0;

      // Concurrently trigger stopRide and addManualRide
      await Future.wait([
        controller.stopRide(),
        controller.addManualRide(
          startTime: DateTime.now().subtract(const Duration(days: 1)),
          durationSeconds: 1200,
          distanceMeters: 5000.0,
        ),
      ]);

      expect(controller.ridesHistory.length, 2);
      expect(
          controller.ridesHistory[0].clientId !=
              controller.ridesHistory[1].clientId,
          isTrue);

      controller.dispose();
    });

    test(
        'Scenario 23 (Massive 50-Ride Offline Backlog): '
        '50 queued rides process and sync in batch when connection is restored',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      mockSupabase.isOffline = true;

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Generate 50 manual rides offline
      for (int i = 1; i <= 50; i++) {
        await controller.addManualRide(
          startTime: DateTime.now().subtract(Duration(hours: i)),
          durationSeconds: 600,
          distanceMeters: 2500.0,
        );
      }

      expect(controller.ridesHistory.length, 50);
      expect(controller.pendingSyncCount, 50);

      // Restore network and sync
      mockSupabase.isOffline = false;
      await controller.syncPendingRides();

      expect(mockSupabase.cloudDatabase.length, 50);
      expect(controller.pendingSyncCount, 0);

      controller.dispose();
    });

    test(
        'Scenario 24 (Low Disk Space - Cache Cleared but Pending Queue Preserved): '
        'Pending queue correctly repopulates history even if cache key was wiped',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final ride1 = RideModel(
        clientId: 'pending_ride_survivor_1',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        durationSeconds: 900,
        distanceMeters: 3000.0,
        avgSpeedKmh: 12.0,
        maxSpeedKmh: 20.0,
        minSpeedKmh: 8.0,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'pending_sync_rides', jsonEncode([ride1.toLocalJson()]));
      // cached_rides_history is missing / wiped
      await prefs.remove('cached_rides_history');

      mockSupabase.isOffline = true; // Offline so pending ride stays pending while repopulating history

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: true,
        autoLoadPreferences: false,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.ridesHistory.length, 1);
      expect(controller.ridesHistory.first.clientId, 'pending_ride_survivor_1');
      expect(controller.pendingSyncCount, 1);

      controller.dispose();
    });

    test(
        'Scenario 25 (Extreme Boundary Values in Manual Entry): '
        '1-second / 1m ride and 24-hour / 300km ride compute speeds without NaN or overflow',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Ultra short
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        durationSeconds: 1,
        distanceMeters: 1.0,
      );
      final shortRide =
          controller.ridesHistory.firstWhere((r) => r.durationSeconds == 1);
      expect(shortRide.avgSpeedKmh, closeTo(3.6, 0.1));
      expect(shortRide.avgSpeedKmh.isNaN, isFalse);

      // Ultra long
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(days: 2)),
        durationSeconds: 86400, // 24 hours
        distanceMeters: 300000.0, // 300 km
      );
      final longRide =
          controller.ridesHistory.firstWhere((r) => r.durationSeconds == 86400);
      expect(longRide.avgSpeedKmh, closeTo(12.5, 0.1));
      expect(longRide.avgSpeedKmh.isInfinite, isFalse);

      controller.dispose();
    });
  });

  group('GROUP G: NETWORK & BACKEND CHAOS', () {
    test(
        'Scenario 26 (Flaky Network - Halfway Batch Failure): '
        'First 3 rides succeed, 4th fails; initial 3 marked synced, remaining 7 stay pending for retry',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      mockSupabase.isOffline = true;

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Create 10 pending rides
      for (int i = 1; i <= 10; i++) {
        await controller.addManualRide(
          startTime: DateTime.now().subtract(Duration(hours: i)),
          durationSeconds: 600,
          distanceMeters: 2000.0,
        );
      }
      expect(controller.pendingSyncCount, 10);

      // Fail halfway on 4th insert
      mockSupabase.isOffline = false;
      mockSupabase.failAfterInserts = 3;

      await controller.syncPendingRides();

      expect(mockSupabase.cloudDatabase.length, 3);
      expect(controller.pendingSyncCount, 7);

      // Restore network completely and sync remaining
      mockSupabase.failAfterInserts = -1;
      await controller.syncPendingRides();

      expect(mockSupabase.cloudDatabase.length, 10);
      expect(controller.pendingSyncCount, 0);

      controller.dispose();
    });

    test(
        'Scenario 27 (Supabase Server Timeout 30s): '
        'TimeoutException is safely caught, ride remains in pending queue, error logged',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      mockSupabase.nextInsertError =
          TimeoutException('Connection timed out after 30000ms');

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.tickTimerForTest(60);
      controller.distanceMeters = 500.0;

      // stopRide must not throw even if backend times out
      await controller.stopRide();

      expect(controller.ridesHistory.length, 1);
      expect(controller.pendingSyncCount, 1);
      final errorEvents = mockTelemetry.loggedEvents
          .where((e) => e['event_type'] == 'ERROR')
          .toList();
      expect(errorEvents.isNotEmpty, isTrue);
      expect(errorEvents.first['reason'], 'save_ride_error');

      controller.dispose();
    });

    test(
        'Scenario 28 (Supabase HTTP 500 Internal Server Error): '
        'Backend 500 error preserves ride locally and enables seamless retry',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      mockSupabase.nextInsertError =
          const HttpException('HTTP 500 Internal Server Error');

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.tickTimerForTest(100);
      controller.distanceMeters = 800.0;

      await controller.stopRide();

      expect(controller.ridesHistory.length, 1);
      expect(controller.pendingSyncCount, 1);

      // Now server recovers
      mockSupabase.nextInsertError = null;
      await controller.syncPendingRides();

      expect(mockSupabase.cloudDatabase.length, 1);
      expect(controller.pendingSyncCount, 0);

      controller.dispose();
    });

    test(
        'Scenario 29 (Telemetry Flood - 3,000 Rapid Events): '
        '3,000 events enforce 500 buffer and storage cap without memory leak',
        () async {
      final realTelemetry = TelemetryService();
      realTelemetry.startSession('flood_test_session');

      for (int i = 1; i <= 3000; i++) {
        realTelemetry.logEvent(
          eventType: 'STRESS_TEST',
          metadata: {'event_index': i},
        );
      }

      expect(realTelemetry.bufferSize, 500);

      final prefs = await SharedPreferences.getInstance();
      final rawQueue = prefs.getString('telemetry_queue');
      expect(rawQueue, isNotNull);
      final List<dynamic> storedQueue = jsonDecode(rawQueue!) as List<dynamic>;
      expect(storedQueue.length, 500);

      realTelemetry.dispose();
    });

    test(
        'Scenario 30 (Haptic / Reminder Clamping Spam 50x): '
        'Rapid 50x delta calls clamp strictly between 5 and 180 minutes with persistence',
        () async {
      final mockSupabase = ChaosMockSupabaseService();
      final mockNotification = FakeNotificationService();
      final mockTelemetry = ChaosFakeTelemetryService();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: mockNotification,
        telemetryService: mockTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Spam +5 50 times -> clamps at 180
      for (int i = 0; i < 50; i++) {
        await controller.changeReminderMinutes(5);
      }
      expect(controller.reminderMinutes, 180);

      // Spam -5 50 times -> clamps at 5
      for (int i = 0; i < 50; i++) {
        await controller.changeReminderMinutes(-5);
      }
      expect(controller.reminderMinutes, 5);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminderMinutes'), 5);

      controller.dispose();
    });
  });
}
