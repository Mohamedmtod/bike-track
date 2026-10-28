import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/live_ride_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';

Position createTestPosition({
  required double latitude,
  required double longitude,
  double speedMps = 5.0,
  double accuracy = 3.0,
}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.now(),
    accuracy: accuracy,
    altitude: 10.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speedMps,
    speedAccuracy: 0.5,
  );
}

class FakeNotificationTestService implements INotificationService {
  final List<String> calls = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> showNotification(int id, String title, String body) async {
    calls.add('show:$id');
  }

  @override
  Future<void> periodicallyShowWithDuration(
      int id, String title, String body, Duration repeatDuration) async {
    calls.add('periodic:$id:${repeatDuration.inMinutes}');
  }

  @override
  Future<void> cancel(int id) async {
    calls.add('cancel:$id');
  }
}

class FakeTelemetryTestService implements ITelemetryService {
  String? sessionId;
  final List<String> eventTypes = [];

  @override
  String? get currentSessionId => sessionId;
  @override
  int get bufferSize => eventTypes.length;
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
    eventTypes.add(eventType);
  }
  @override
  Future<void> flush() async {}
  @override
  Future<void> cleanOldLogs([int days = 14]) async {}
  @override
  void dispose() {}
}

class MockSupabaseTestService extends Fake implements SupabaseService {
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

  group('Pause / Resume Logic & State Machine Tests', () {
    test('1. pauseRide() freezes durationSeconds and clamps currentSpeed to 0.0',
        () async {
      final notif = FakeNotificationTestService();
      final telem = FakeTelemetryTestService();
      final controller = RideController(
        notificationService: notif,
        telemetryService: telem,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      expect(controller.state, RideState.recording);
      expect(controller.isRiding, isTrue);
      expect(controller.isPaused, isFalse);

      // Ride 60 seconds
      controller.tickTimerForTest(60);
      expect(controller.durationSeconds, 60);

      // Pause ride
      final paused = await controller.pauseRide();
      expect(paused, isTrue);
      expect(controller.state, RideState.paused);
      expect(controller.isPaused, isTrue);
      expect(controller.isRiding, isTrue);
      expect(controller.currentSpeedKmh, 0.0);
      expect(notif.calls.contains('cancel:3'), isTrue);
      expect(telem.eventTypes.contains('RIDE_PAUSED'), isTrue);

      // Ticking timer while paused does NOT increment durationSeconds
      controller.tickTimerForTest(30);
      expect(controller.durationSeconds, 60);

      controller.dispose();
    });

    test('2. GPS points are rejected for route & distance during pause, but currentPosition updates',
        () async {
      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Accept first anchor point
      controller.processPositionUpdate(
        createTestPosition(latitude: 30.0444, longitude: 31.2357, speedMps: 5.0),
      );
      // Accept second point
      controller.processPositionUpdate(
        createTestPosition(latitude: 30.0450, longitude: 31.2357, speedMps: 5.0),
      );

      expect(controller.routePoints.length, 2);
      final initialDistance = controller.distanceMeters;
      expect(initialDistance, greaterThan(0));

      // Pause ride
      await controller.pauseRide();

      // Send 5 new noisy GPS points while paused (e.g. inside supermarket)
      for (int i = 1; i <= 5; i++) {
        controller.processPositionUpdate(
          createTestPosition(
            latitude: 30.0450 + (i * 0.001),
            longitude: 31.2357,
            speedMps: 4.0,
          ),
        );
      }

      // Distance and route points MUST be unchanged!
      expect(controller.routePoints.length, 2);
      expect(controller.distanceMeters, initialDistance);
      expect(controller.currentSpeedKmh, 0.0);

      // But currentPosition was updated for map centering
      expect(controller.currentPosition?.latitude, 30.0450 + 0.005);

      controller.dispose();
    });

    test('3. resumeRide() restarts duration accumulation and reschedules hydration reminder',
        () async {
      final notif = FakeNotificationTestService();
      final telem = FakeTelemetryTestService();
      final controller = RideController(
        notificationService: notif,
        telemetryService: telem,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.tickTimerForTest(45);
      await controller.pauseRide();
      expect(controller.durationSeconds, 45);

      // Resume
      final resumed = await controller.resumeRide();
      expect(resumed, isTrue);
      expect(controller.state, RideState.recording);
      expect(controller.isPaused, isFalse);
      expect(telem.eventTypes.contains('RIDE_RESUMED'), isTrue);
      expect(notif.calls.any((c) => c.startsWith('periodic:3:')), isTrue);

      // Tick 15 more seconds
      controller.tickTimerForTest(15);
      expect(controller.durationSeconds, 60);

      await controller.stopRide();
      expect(controller.durationSeconds, 60);
      expect(controller.state, RideState.idle);

      controller.dispose();
    });

    test('4. Injected clock test: stopRide() excludes paused supermarket break from Wall-Clock',
        () async {
      var simulatedTime = DateTime(2026, 10, 27, 10, 0, 0);
      DateTime clock() => simulatedTime;

      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      controller.setClockForTest(clock);

      // 10:00: Start ride
      await controller.startRide();

      // Ride for 15 minutes (active segment: 10:00 to 10:15)
      simulatedTime = simulatedTime.add(const Duration(minutes: 15));

      // 10:15: Enter supermarket and pause
      await controller.pauseRide();
      expect(controller.durationSeconds, 900); // 15 mins

      // In supermarket for 20 minutes (10:15 to 10:35)
      simulatedTime = simulatedTime.add(const Duration(minutes: 20));

      // 10:35: Leave supermarket and resume
      await controller.resumeRide();
      expect(controller.durationSeconds, 900); // Still 15 mins!

      // Ride for another 10 minutes (10:35 to 10:45)
      simulatedTime = simulatedTime.add(const Duration(minutes: 10));

      // 10:45: Stop ride
      await controller.stopRide();

      // Total wall-clock elapsed was 45 minutes, but active duration must be exactly 25 minutes (1500 seconds)!
      expect(controller.durationSeconds, 1500);
      expect(controller.ridesHistory.first.durationSeconds, 1500);

      controller.dispose();
    });

    test('5. Idempotency: Duplicate pauseRide() or resumeRide() calls are safe no-ops',
        () async {
      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();

      // Double pause
      expect(await controller.pauseRide(), isTrue);
      expect(await controller.pauseRide(), isFalse); // Second is no-op
      expect(controller.state, RideState.paused);

      // Double resume
      expect(await controller.resumeRide(), isTrue);
      expect(await controller.resumeRide(), isFalse); // Second is no-op
      expect(controller.state, RideState.recording);

      await controller.stopRide();
      controller.dispose();
    });

    test('6. Snapshot preserves state and recovery can restore in Paused state or Save to History',
        () async {
      final controller1 = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller1.startRide();
      controller1.tickTimerForTest(300); // 5 mins
      controller1.processPositionUpdate(
        createTestPosition(latitude: 30.0444, longitude: 31.2357),
      );
      controller1.processPositionUpdate(
        createTestPosition(latitude: 30.0500, longitude: 31.2357),
      );
      await controller1.pauseRide();

      // Verify SharedPreferences snapshot
      final prefs = await SharedPreferences.getInstance();
      final snapRaw = prefs.getString('active_ride_snapshot');
      expect(snapRaw, isNotNull);
      final snapJson = jsonDecode(snapRaw!) as Map<String, dynamic>;
      expect(snapJson['is_paused'], isTrue);
      expect(snapJson['accumulated_active_seconds'], 300);
      expect(snapJson['route_points_count'], 2);

      controller1.dispose();

      // Boot up controller2 with promptRecoveryOnInterrupted: true
      final controller2 = RideController(
        autoFetchHistory: true,
        autoLoadPreferences: false,
        promptRecoveryOnInterrupted: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller2.hasInterruptedRide, isTrue);
      expect(controller2.interruptedRideSnapshot, isNotNull);

      // Option 1: Restore interrupted ride into active session
      final restored = await controller2.restoreInterruptedRide();
      expect(restored, isTrue);
      expect(controller2.isRiding, isTrue);
      expect(controller2.state, RideState.paused); // ALWAYS restores in Paused state!
      expect(controller2.durationSeconds, 300);
      expect(controller2.routePoints.length, 2);

      // Now save and finish
      await controller2.stopRide();
      expect(controller2.isRiding, isFalse);

      controller2.dispose();
    });

    test('6b. Active recording crash recovery preserves unpaused duration (not 0) and resumes seamlessly',
        () async {
      var simulatedTime = DateTime(2026, 10, 27, 8, 0, 0);
      DateTime clock() => simulatedTime;

      final controller1 = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      controller1.setClockForTest(clock);

      await controller1.startRide();
      expect(controller1.state, RideState.recording);

      // Record for 600 seconds (10 minutes) with NO pause
      simulatedTime = simulatedTime.add(const Duration(minutes: 10));
      // Save active ride snapshot while actively recording
      await controller1.saveActiveRideSnapshotForTest();

      final prefs = await SharedPreferences.getInstance();
      final snapRaw = prefs.getString('active_ride_snapshot');
      expect(snapRaw, isNotNull);
      final snapJson = jsonDecode(snapRaw!) as Map<String, dynamic>;
      expect(snapJson['is_paused'], isFalse);
      expect(snapJson['state'], 'recording');
      expect(snapJson['accumulated_active_seconds'], 600);
      expect(snapJson['duration_seconds'], 600);

      controller1.dispose();

      // Controller2 recovers the interrupted recording session
      final controller2 = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
        promptRecoveryOnInterrupted: true,
      );
      controller2.setClockForTest(clock);
      await controller2.recoverInterruptedRideForTest();

      expect(controller2.hasInterruptedRide, isTrue);

      final restored = await controller2.restoreInterruptedRide();
      expect(restored, isTrue);
      expect(controller2.isRiding, isTrue);
      expect(controller2.state, RideState.paused); // Always restored in paused state
      expect(controller2.durationSeconds, 600); // Must be 600s, NEVER 0!

      // Resume ride and ride for 5 more minutes
      await controller2.resumeRide();
      expect(controller2.state, RideState.recording);
      simulatedTime = simulatedTime.add(const Duration(minutes: 5));

      await controller2.stopRide();
      expect(controller2.durationSeconds, 900); // 15 minutes total!
      expect(controller2.ridesHistory.first.durationSeconds, 900);

      controller2.dispose();
    });

    test('6c. Paused crash recovery with 0 active duration never inflates with pause duration',
        () async {
      var simulatedTime = DateTime(2026, 10, 27, 9, 0, 0);
      DateTime clock() => simulatedTime;

      final controller1 = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      controller1.setClockForTest(clock);

      await controller1.startRide();
      // Pause immediately (0 active seconds)
      await controller1.pauseRide();
      expect(controller1.durationSeconds, 0);

      // 30 minutes pass while paused in shop
      simulatedTime = simulatedTime.add(const Duration(minutes: 30));

      final prefs = await SharedPreferences.getInstance();
      // Snapshot stored with snapshot_time 30 mins after start_time
      final snap = <String, dynamic>{
        'client_id': 'test_zero_pause_id',
        'start_time': DateTime(2026, 10, 27, 9, 0, 0).toIso8601String(),
        'state': 'paused',
        'is_paused': true,
        'accumulated_active_seconds': 0,
        'duration_seconds': 0,
        'snapshot_time': simulatedTime.toIso8601String(),
        'distance_meters': 0.0,
        'max_speed_kmh': 0.0,
        'min_speed_kmh': 0.0,
        'route_points': <dynamic>[],
      };
      await prefs.setString('active_ride_snapshot', jsonEncode(snap));
      controller1.dispose();

      // Controller2 saves interrupted ride as finished
      final controller2 = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
        promptRecoveryOnInterrupted: false,
      );
      controller2.setClockForTest(clock);
      await controller2.saveInterruptedRideAsFinished(snap);

      // Duration MUST be 0 and NOT inflated by the 30-minute wall-clock break!
      expect(controller2.ridesHistory.first.durationSeconds, 0);

      controller2.dispose();
    });

    test('6d. changeReminderMinutes() during pause updates preference without scheduling notification',
        () async {
      final notif = FakeNotificationTestService();
      final controller = RideController(
        notificationService: notif,
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      expect(notif.calls.any((c) => c.startsWith('periodic:3:')), isTrue);
      notif.calls.clear();

      // Pause ride
      await controller.pauseRide();
      expect(controller.isPaused, isTrue);
      expect(controller.isRecording, isFalse);
      expect(notif.calls.contains('cancel:3'), isTrue);
      notif.calls.clear();

      // Change reminder minutes by +5 while paused
      await controller.changeReminderMinutes(5);
      expect(controller.reminderMinutes, 35);
      // Notification must NOT be rescheduled while paused!
      expect(notif.calls.any((c) => c.startsWith('periodic:3:')), isFalse);

      // Resume ride -> notification rescheduled with 35 minutes
      await controller.resumeRide();
      expect(notif.calls.contains('periodic:3:35'), isTrue);

      await controller.stopRide();
      controller.dispose();
    });

    test('6e. startRide() is strictly blocked when interruptedRideSnapshot exists to prevent data loss',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final snap = <String, dynamic>{
        'client_id': 'pending_interrupted_ride_123',
        'start_time': DateTime(2026, 10, 27, 8, 0, 0).toIso8601String(),
        'state': 'recording',
        'is_paused': false,
        'accumulated_active_seconds': 450,
        'duration_seconds': 450,
        'snapshot_time': DateTime(2026, 10, 27, 8, 7, 30).toIso8601String(),
        'distance_meters': 2500.0,
        'max_speed_kmh': 24.0,
        'min_speed_kmh': 5.0,
        'route_points': <dynamic>[],
      };
      await prefs.setString('active_ride_snapshot', jsonEncode(snap));

      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
        promptRecoveryOnInterrupted: true,
      );
      await controller.recoverInterruptedRideForTest();

      expect(controller.hasInterruptedRide, isTrue);
      expect(controller.isRiding, isFalse);

      // Attempting to start a new ride while an interrupted session is awaiting decision MUST be blocked!
      final startAttempt = await controller.startRide();
      expect(startAttempt, isFalse);
      expect(controller.isRiding, isFalse);
      expect(controller.hasInterruptedRide, isTrue);

      // Verify the original snapshot was NOT overwritten in SharedPreferences
      final remainingSnap = prefs.getString('active_ride_snapshot');
      expect(remainingSnap, isNotNull);
      final decodedSnap = jsonDecode(remainingSnap!) as Map<String, dynamic>;
      expect(decodedSnap['client_id'], 'pending_interrupted_ride_123');
      expect(decodedSnap['duration_seconds'], 450);

      // Once resolved (e.g. discarded or saved as finished), startRide() is allowed
      await controller.discardInterruptedRide();
      expect(controller.hasInterruptedRide, isFalse);

      final allowedStart = await controller.startRide();
      expect(allowedStart, isTrue);
      expect(controller.isRiding, isTrue);

      await controller.stopRide();
      controller.dispose();
    });

    test('6f. saveInterruptedRideAsFinished() updates cached_rides_history before clearing snapshot',
        () async {
      final prefs = await SharedPreferences.getInstance();
      final snap = <String, dynamic>{
        'client_id': 'offline_recovered_ride_456',
        'start_time': DateTime(2026, 10, 27, 7, 30, 0).toIso8601String(),
        'state': 'paused',
        'is_paused': true,
        'accumulated_active_seconds': 720,
        'duration_seconds': 720,
        'snapshot_time': DateTime(2026, 10, 27, 7, 45, 0).toIso8601String(),
        'distance_meters': 3800.0,
        'max_speed_kmh': 28.5,
        'min_speed_kmh': 4.0,
        'route_points': <dynamic>[],
      };
      await prefs.setString('active_ride_snapshot', jsonEncode(snap));
      await prefs.remove('cached_rides_history');

      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
        promptRecoveryOnInterrupted: true,
      );
      await controller.recoverInterruptedRideForTest();

      // Save as finished
      await controller.saveInterruptedRideAsFinished();

      // 1. Snapshot must be cleared
      expect(prefs.getString('active_ride_snapshot'), isNull);
      expect(controller.hasInterruptedRide, isFalse);

      // 2. cached_rides_history in SharedPreferences MUST be populated immediately
      final cachedJson = prefs.getString('cached_rides_history');
      expect(cachedJson, isNotNull);
      final List<dynamic> cachedList = jsonDecode(cachedJson!) as List<dynamic>;
      expect(cachedList.length, 1);
      expect(cachedList.first['client_id'], 'offline_recovered_ride_456');
      expect(cachedList.first['duration_seconds'], 720);

      // 3. Pending sync queue also preserves it for eventual server sync
      final pendingJson = prefs.getString('pending_sync_rides');
      expect(pendingJson, isNotNull);
      final List<dynamic> pendingList = jsonDecode(pendingJson!) as List<dynamic>;
      expect(pendingList.any((r) => r['client_id'] == 'offline_recovered_ride_456'), isTrue);

      controller.dispose();
    });
  });

  group('Pause / Resume UI & Cockpit Widget Tests (iPhone 14 Pro)', () {
    testWidgets('7. LiveRideScreen dual action controls: Pause, Resume, and Hold-to-Stop',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = RideController(
        supabaseService: MockSupabaseTestService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveRideScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      const strings = AppStrings(AppLanguage.arabicEgyptian);

      // Verify Pause and Stop buttons are visible
      final pauseBtn = find.text(strings.livePauseButton);
      final stopBtn = find.text(strings.liveFinishButton);
      expect(pauseBtn, findsOneWidget);
      expect(stopBtn, findsOneWidget);
      expect(find.text(strings.liveHoldToStopNotice), findsOneWidget);

      // Tap Pause
      await tester.tap(pauseBtn);
      await tester.pumpAndSettle();

      expect(controller.isPaused, isTrue);
      // Button text changed to Resume
      expect(find.text(strings.liveResumeButton), findsOneWidget);
      // Badge changed to Paused
      expect(find.textContaining(strings.liveStatusPaused), findsWidgets);

      // Tap Resume
      await tester.tap(find.text(strings.liveResumeButton));
      await tester.pumpAndSettle();

      expect(controller.isPaused, isFalse);
      expect(find.text(strings.livePauseButton), findsOneWidget);

      controller.dispose();
    });

    testWidgets('8. DashboardScreen reflects Paused ride banner and recovery card',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = RideController(
        supabaseService: MockSupabaseTestService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();
      await controller.pauseRide();

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      const strings = AppStrings(AppLanguage.arabicEgyptian);

      // Verify Paused banner is displayed
      expect(find.text(strings.activeRidePausedBanner), findsOneWidget);

      controller.dispose();
    });

    testWidgets('9. Hold-to-Stop button cancels when dragging finger outside bounds & has semantics',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final controller = RideController(
        supabaseService: MockSupabaseTestService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      await tester.pumpWidget(
        MaterialApp(
          home: LiveRideScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      const strings = AppStrings(AppLanguage.arabicEgyptian);
      // Verify accessibility semantics
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label ==
                  '${strings.liveFinishButton}: ${strings.liveHoldToStopNotice}',
        ),
        findsOneWidget,
      );

      final stopBtn = find.text(strings.liveFinishButton);
      expect(stopBtn, findsOneWidget);

      // Pointer down on stop button
      final gesture = await tester.startGesture(tester.getCenter(stopBtn));
      await tester.pump(const Duration(milliseconds: 300));
      expect(controller.isRiding, isTrue);

      // Drag pointer far away outside the button bounds
      await gesture.moveTo(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 700));

      // Release pointer
      await gesture.up();
      await tester.pumpAndSettle();

      // Ride should still be running because drag-out cancelled the hold
      expect(controller.isRiding, isTrue);

      controller.dispose();
    });
  });
}
