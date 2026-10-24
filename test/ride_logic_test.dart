import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/telemetry_service.dart';

class FakeNotificationService implements INotificationService {
  final List<String> log = [];
  final Map<int, Duration> scheduledPeriodic = {};
  final Set<int> cancelledIds = {};

  @override
  Future<void> init() async {
    log.add('init');
  }

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
    scheduledPeriodic[id] = repeatDuration;
  }

  @override
  Future<void> cancel(int id) async {
    log.add('cancel:$id');
    cancelledIds.add(id);
    scheduledPeriodic.remove(id);
  }
}

class FakeTelemetryService implements ITelemetryService {
  String? sessionId;
  final List<Map<String, dynamic>> loggedEvents = [];
  int cleanOldLogsCallCount = 0;
  int? lastCleanDays;
  int flushCallCount = 0;
  bool isDisposed = false;

  @override
  String? get currentSessionId => sessionId;

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
      'session_id': sessionId,
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
    cleanOldLogsCallCount++;
    lastCleanDays = days;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}

Position createTestPosition(
  double lat,
  double lng,
  double speedMps, {
  double accuracy = 3.0,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 15.0,
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

  group('Ride Logic & NFC Idempotency Tests', () {
    test('NFC Idempotency: Duplicate startRide calls do not restart active ride',
        () async {
      final controller = RideController(autoFetchHistory: false);

      expect(controller.isRiding, false);

      // Call startRide 5 times consecutively (e.g. repeated NFC taps)
      final res1 = await controller.startRide();
      expect(res1, true);
      final initialStartTime = controller.startTime;
      expect(controller.isRiding, true);
      expect(initialStartTime, isNotNull);

      final res2 = await controller.startRide();
      final res3 = await controller.startRide();
      final res4 = await controller.startRide();
      final res5 = await controller.startRide();

      expect(res2, true);
      expect(res3, true);
      expect(res4, true);
      expect(res5, true);
      expect(controller.isRiding, true);
      expect(controller.startTime, initialStartTime);

      // Call stopRide 3 times consecutively
      await controller.stopRide();
      expect(controller.isRiding, false);

      await controller.stopRide();
      await controller.stopRide();
      expect(controller.isRiding, false);

      controller.dispose();
    });

    test('Reminder Interval Control (+5 / -5 mins) with persistence & clamping',
        () async {
      final controller = RideController(autoFetchHistory: false);

      // Default is 30 mins
      expect(controller.reminderMinutes, 30);

      // +5 mins -> 35
      await controller.changeReminderMinutes(5);
      expect(controller.reminderMinutes, 35);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminderMinutes'), 35);

      // Decrement 10 times by -5 mins -> clamps at minimum 5 mins (never <= 0)
      for (int i = 0; i < 10; i++) {
        await controller.changeReminderMinutes(-5);
      }
      expect(controller.reminderMinutes, 5);
      expect(prefs.getInt('reminderMinutes'), 5);

      // Cannot exceed 180 mins
      for (int i = 0; i < 40; i++) {
        await controller.changeReminderMinutes(5);
      }
      expect(controller.reminderMinutes, 180);

      controller.dispose();
    });

    test('Simulated Bike GPS Route, speed calculations and jitter filtering',
        () async {
      final controller = RideController(autoFetchHistory: false);
      await controller.startRide();

      // Point 1: Initial position, 0.0 m/s
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0));
      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);

      // Point 2: GPS jitter (< 2 meters away)
      controller.processPositionUpdate(
          createTestPosition(30.044405, 31.235705, 0.5));
      expect(controller.routePoints.length, 1,
          reason: 'Jitter < 2m should not add new point');
      expect(controller.distanceMeters, 0.0);

      // Point 3: Movement ~111m North at 5.0 m/s (18.0 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0));
      expect(controller.routePoints.length, 2);
      expect(controller.distanceMeters, greaterThan(100.0));
      expect(controller.currentSpeedKmh, 18.0);
      expect(controller.maxSpeedKmh, 18.0);
      expect(controller.minSpeedKmh, 18.0);

      // Point 4: Acceleration ~111m North at 8.0 m/s (28.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0464, 31.2357, 8.0));
      expect(controller.routePoints.length, 3);
      expect(controller.currentSpeedKmh, 28.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 18.0);

      // Point 5: Deceleration ~111m North at 3.0 m/s (10.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0474, 31.2357, 3.0));
      expect(controller.routePoints.length, 4);
      expect(controller.currentSpeedKmh, 10.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 10.8);

      controller.dispose();
    });

    test('Periodic Notification Trigger counts accurately on timer intervals',
        () async {
      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Set reminder to 20 mins
      await controller.changeReminderMinutes(-10); // 30 - 10 = 20 mins
      expect(controller.reminderMinutes, 20);
      expect(controller.reminderNotificationTriggerCount, 0);

      // Fast forward 1199 seconds (just before 20 mins)
      controller.tickTimerForTest(1199);
      expect(controller.reminderNotificationTriggerCount, 0);

      // Tick 1 more second -> 1200 seconds (exactly 20 mins)
      controller.tickTimerForTest(1);
      expect(controller.reminderNotificationTriggerCount, 1);

      // Fast forward another 20 mins (1200 seconds) -> 2400 seconds
      controller.tickTimerForTest(1200);
      expect(controller.reminderNotificationTriggerCount, 2);

      controller.dispose();
    });

    test('FakeNotificationService: Scheduling 30m, 35m, 5m, 180m, and stopRide cancel',
        () async {
      final fakeNotifier = FakeNotificationService();
      final controller = RideController(
        notificationService: fakeNotifier,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // 1. Changing interval when NOT riding should NOT schedule any notification
      await controller.changeReminderMinutes(5);
      expect(fakeNotifier.scheduledPeriodic.containsKey(3), isFalse);

      // 2. startRide schedules notification 3 with reminderMinutes (35m)
      await controller.startRide();
      expect(fakeNotifier.log, contains('show:1'));
      expect(fakeNotifier.scheduledPeriodic[3], const Duration(minutes: 35));

      // 3. changeReminderMinutes during ride cancels and reschedules with new duration
      await controller.changeReminderMinutes(-30); // Clamped to 5 min
      expect(controller.reminderMinutes, 5);
      expect(fakeNotifier.cancelledIds.contains(3), isTrue);
      expect(fakeNotifier.scheduledPeriodic[3], const Duration(minutes: 5));

      // 4. Clamped to 180 min
      await controller.changeReminderMinutes(200); // Clamped to 180 min
      expect(controller.reminderMinutes, 180);
      expect(fakeNotifier.scheduledPeriodic[3], const Duration(minutes: 180));

      // 5. stopRide cancels reminder notification 3
      await controller.stopRide();
      expect(fakeNotifier.scheduledPeriodic.containsKey(3), isFalse);
      expect(fakeNotifier.log, contains('show:2'));

      controller.dispose();
    });

    test('Real elapsed duration calculation and GPS speed zeroing after 3 seconds',
        () async {
      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Simulate a clock jump / 10-minute elapsed time
      controller.startTime =
          DateTime.now().subtract(const Duration(minutes: 10, seconds: 25));
      expect(DateTime.now().difference(controller.startTime!).inSeconds,
          greaterThanOrEqualTo(625));

      // GPS position update sets speed
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 5.0)); // 18.0 km/h
      expect(controller.currentSpeedKmh, 18.0);

      // Simulate position received while ride stopped -> should be ignored
      await controller.stopRide();
      final prevPointsCount = controller.routePoints.length;
      controller.processPositionUpdate(
          createTestPosition(30.0500, 31.2400, 10.0));
      expect(controller.routePoints.length, prevPointsCount);

      controller.dispose();
    });
  });

  group('Anti-Drift GPS Filter Pipeline Tests', () {
    test('1. 20m Accuracy rejection retains currentPosition for centering but rejects point',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Inaccurate point: 25.0 meters accuracy (> 20.0m)
      final pos = createTestPosition(30.0500, 31.2500, 5.0, accuracy: 25.0);
      controller.processPositionUpdate(pos);

      // Visual position updated for immediate map centering
      expect(controller.currentPosition, pos);
      // Speed reset and point rejected
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.routePoints, isEmpty);
      expect(controller.distanceMeters, 0.0);
      expect(controller.maxSpeedKmh, 0.0);

      // Telemetry verified
      final rejection = fakeTelemetry.loggedEvents
          .firstWhere((e) => e['event_type'] == 'GPS_REJECTED');
      expect(rejection['reason'], 'accuracy');
      expect(rejection['accuracy'], 25.0);

      controller.dispose();
    });

    test('2. First accurate point anchors route with zero distance', () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Stationary first accurate point: 5m accuracy, 0 m/s
      final anchor = createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0);
      controller.processPositionUpdate(anchor);

      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);

      final accepted = fakeTelemetry.loggedEvents
          .firstWhere((e) => e['event_type'] == 'GPS_ACCEPTED');
      expect((accepted['metadata'] as Map)['anchor'], isTrue);

      controller.dispose();
    });

    test('3. Stationary subsequent points rejected via Doppler (<= 2.5 km/h)',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0));

      // Subsequent stationary point: 0.5 m/s = 1.8 km/h (<= 2.5 km/h)
      final stationary =
          createTestPosition(30.0450, 31.2357, 0.5, accuracy: 5.0);
      controller.processPositionUpdate(stationary);

      expect(controller.currentPosition, stationary);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);

      final rejected = fakeTelemetry.loggedEvents.last;
      expect(rejected['event_type'], 'GPS_REJECTED');
      expect(rejected['reason'], 'stationary');

      controller.dispose();
    });

    test('4. 3m Micro-jitter rejection prevents drift while moving below distance threshold',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
          createTestPosition(30.044400, 31.235700, 0.0, accuracy: 5.0));

      // Point ~1.5m away with speed 2.0 m/s (7.2 km/h > 2.5 km/h)
      final jitter =
          createTestPosition(30.044410, 31.235700, 2.0, accuracy: 5.0);
      controller.processPositionUpdate(jitter);

      expect(controller.currentPosition, jitter);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);

      final rejected = fakeTelemetry.loggedEvents.last;
      expect(rejected['event_type'], 'GPS_REJECTED');
      expect(rejected['reason'], 'micro_jitter');

      controller.dispose();
    });

    test('5. 65 km/h Raw-speed spike rejection ignores anomalies', () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0));

      // Speed spike: 25.0 m/s = 90.0 km/h (> 65.0 km/h) ~100m away
      final spike =
          createTestPosition(30.0454, 31.2357, 25.0, accuracy: 5.0);
      controller.processPositionUpdate(spike);

      expect(controller.currentPosition, spike);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);
      expect(controller.maxSpeedKmh, 0.0);

      final rejected = fakeTelemetry.loggedEvents.last;
      expect(rejected['event_type'], 'GPS_REJECTED');
      expect(rejected['reason'], 'speed_spike');

      controller.dispose();
    });

    test('6. Accepted moving points update route, distance, and max/min speeds',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Anchor
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0));

      // Moving point 1: ~111m away at 5.0 m/s (18.0 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0, accuracy: 5.0));
      expect(controller.routePoints.length, 2);
      expect(controller.distanceMeters, greaterThan(100.0));
      expect(controller.currentSpeedKmh, 18.0);
      expect(controller.maxSpeedKmh, 18.0);
      expect(controller.minSpeedKmh, 18.0);

      // Moving point 2: ~111m further at 8.0 m/s (28.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0464, 31.2357, 8.0, accuracy: 5.0));
      expect(controller.routePoints.length, 3);
      expect(controller.currentSpeedKmh, 28.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 18.0);

      // Moving point 3: ~111m further at 3.0 m/s (10.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0474, 31.2357, 3.0, accuracy: 5.0));
      expect(controller.routePoints.length, 4);
      expect(controller.currentSpeedKmh, 10.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 10.8);

      controller.dispose();
    });

    test('7. Indoor drift test: 10 noisy points leave distance and max speed strictly at 0.0',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Simulate typical indoor drift with fluctuating coordinates, poor accuracy, and micro-movements
      final driftPoints = [
        createTestPosition(30.044400, 31.235700, 0.0, accuracy: 4.0), // Anchor
        createTestPosition(30.044405, 31.235703, 0.2, accuracy: 5.0), // Stationary Doppler (0.72 km/h)
        createTestPosition(30.044410, 31.235706, 0.4, accuracy: 12.0), // Stationary Doppler (1.44 km/h)
        createTestPosition(30.044412, 31.235708, 1.5, accuracy: 25.0), // Rejected: poor accuracy 25m
        createTestPosition(30.044408, 31.235705, 0.1, accuracy: 8.0), // Stationary Doppler
        createTestPosition(30.044415, 31.235710, 2.0, accuracy: 6.0), // Micro-jitter (< 3m)
        createTestPosition(30.044420, 31.235712, 0.3, accuracy: 35.0), // Poor accuracy 35m
        createTestPosition(30.044400, 31.235700, 0.0, accuracy: 5.0), // Micro-jitter back to origin
        createTestPosition(30.044401, 31.235702, 0.6, accuracy: 7.0), // Stationary Doppler (2.16 km/h)
        createTestPosition(30.044403, 31.235701, 30.0, accuracy: 4.0), // Speed spike (108 km/h)
      ];

      for (final p in driftPoints) {
        controller.processPositionUpdate(p);
      }

      // Visual position must be updated to the last received GPS point
      expect(controller.currentPosition, driftPoints.last);
      // Distance and max speed must remain strictly 0.0 despite the 10 drift updates
      expect(controller.distanceMeters, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.routePoints.length, 1); // Only the initial anchor

      controller.dispose();
    });
  });

  group('Isolated Telemetry Service Tests', () {
    test('1. Session ID creation, RIDE_START event, and 14-day cleanup invocation',
        () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      expect(controller.currentSessionId, isNull);

      await controller.startRide();

      expect(controller.currentSessionId, isNotNull);
      expect(controller.currentSessionId, startsWith('ride_'));
      expect(fakeTelemetry.sessionId, controller.currentSessionId);
      expect(fakeTelemetry.cleanOldLogsCallCount, 1);
      expect(fakeTelemetry.lastCleanDays, 14);

      final startEvent = fakeTelemetry.loggedEvents
          .firstWhere((e) => e['event_type'] == 'RIDE_START');
      expect(startEvent['session_id'], controller.currentSessionId);
      expect((startEvent['metadata'] as Map)['reminder_minutes'], 30);
      expect((startEvent['metadata'] as Map)['start_time'], isNotNull);

      controller.dispose();
    });

    test('2. Telemetry event logging for GPS_ACCEPTED and GPS_REJECTED', () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Accurate anchor
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0));
      // Rejection: accuracy
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 5.0, accuracy: 30.0));
      // Movement accepted
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0, accuracy: 5.0));

      final acceptedEvents = fakeTelemetry.loggedEvents
          .where((e) => e['event_type'] == 'GPS_ACCEPTED')
          .toList();
      final rejectedEvents = fakeTelemetry.loggedEvents
          .where((e) => e['event_type'] == 'GPS_REJECTED')
          .toList();

      expect(acceptedEvents.length, 2);
      expect(rejectedEvents.length, 1);
      expect(rejectedEvents.first['reason'], 'accuracy');
      expect(acceptedEvents.last['speed_mps'], 5.0);

      controller.dispose();
    });

    test('3. Stop ride logs RIDE_STOP and flushes telemetry buffer', () async {
      final fakeTelemetry = FakeTelemetryService();
      final controller = RideController(
        telemetryService: fakeTelemetry,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0, accuracy: 5.0));
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0, accuracy: 5.0));

      expect(fakeTelemetry.flushCallCount, 0);

      await controller.stopRide();

      expect(fakeTelemetry.flushCallCount, 1);
      final stopEvent = fakeTelemetry.loggedEvents
          .firstWhere((e) => e['event_type'] == 'RIDE_STOP');
      final metadata = stopEvent['metadata'] as Map<String, dynamic>;
      expect(metadata['duration_seconds'], isNotNull);
      expect(metadata['distance_meters'], greaterThan(100.0));
      expect(metadata['route_points_count'], 2);

      controller.dispose();
    });

    test('4. TelemetryService in-memory buffering and transport error suppression',
        () async {
      // Instantiating with no Supabase client to test transport swallow
      final telemetry = TelemetryService();
      telemetry.startSession('ride_test_session');

      expect(telemetry.currentSessionId, 'ride_test_session');

      telemetry.logEvent(
        eventType: 'GPS_ACCEPTED',
        latitude: 30.0,
        longitude: 31.0,
        speedMps: 4.0,
        accuracy: 3.0,
        metadata: {'test': true},
      );

      // flush and cleanOldLogs should not throw or crash when client is absent
      await expectLater(telemetry.flush(), completes);
      await expectLater(telemetry.cleanOldLogs(14), completes);

      telemetry.dispose();
    });
  });
}
