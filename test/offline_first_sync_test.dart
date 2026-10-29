import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/main.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';
import 'package:bike_track/theme/theme_controller.dart';

class MockSlowSupabaseService extends SupabaseService {
  final List<RideModel> uploadedRides = [];
  Duration delay = Duration.zero;
  bool shouldFail = false;
  int failAfterCount = -1;
  int insertCallCount = 0;
  Completer<void>? hangCompleter;

  @override
  Future<void> insertRide(RideModel ride) async {
    insertCallCount++;
    if (hangCompleter != null) {
      await hangCompleter!.future;
    }
    if (delay > Duration.zero) {
      await Future<void>.delayed(delay);
    }
    if (shouldFail || (failAfterCount >= 0 && insertCallCount > failAfterCount)) {
      throw const SocketException('Network is unreachable');
    }
    uploadedRides.add(ride);
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    return List.from(uploadedRides);
  }

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
    uploadedRides.removeWhere((r) => r.clientId == clientId);
  }
}

class FakeNotificationService implements INotificationService {
  int cancelCount = 0;
  int showCount = 0;

  @override
  Future<void> init() async {}
  @override
  Future<void> showNotification(int id, String title, String body) async {
    showCount++;
  }
  @override
  Future<void> periodicallyShowWithDuration(
      int id, String title, String body, Duration repeatDuration) async {}
  @override
  Future<void> cancel(int id) async {
    cancelCount++;
  }
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('P1: Non-Blocking Stop & Real 3-Second Timeout Tests', () {
    test('1. stopRide() finishes in milliseconds and saves locally without blocking on hanging backend',
        () async {
      final mockSupabase = MockSlowSupabaseService();
      // Simulate completely hanging network call (like waiting for DNS/TCP timeout)
      mockSupabase.hangCompleter = Completer<void>();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.distanceMeters = 1500.0;
      controller.tickTimerForTest(120);

      final stopwatch = Stopwatch()..start();
      // stopRide must NOT wait for the hanging backend call or notifications!
      await controller.stopRide();
      stopwatch.stop();

      // Completes in < 100ms because it persists locally first and returns immediately
      expect(stopwatch.elapsedMilliseconds, lessThan(150));
      expect(controller.isRiding, false);
      expect(controller.ridesHistory.length, 1);
      expect(controller.ridesHistory.first.syncStatus, SyncStatus.pending);
      expect(controller.pendingSyncCount, 1);

      // Verify ride was written to SharedPreferences pending queue
      final prefs = await SharedPreferences.getInstance();
      final pendingRaw = prefs.getString('pending_sync_rides');
      expect(pendingRaw, isNotNull);
      expect(pendingRaw, contains(controller.ridesHistory.first.clientId));

      // Release the hanging call to clean up
      mockSupabase.hangCompleter!.complete();
      controller.dispose();
    });

    test('2. 3-Second Timeout: syncPendingRides() enforces 3s timeout when backend hangs and keeps ride pending',
        () async {
      final mockSupabase = MockSlowSupabaseService();
      // Never completes -> triggers .timeout(const Duration(seconds: 3))
      mockSupabase.hangCompleter = Completer<void>();

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(minutes: 5)),
        durationSeconds: 300,
        distanceMeters: 1000.0,
      );
      expect(controller.pendingSyncCount, 1);

      final stopwatch = Stopwatch()..start();
      // Call sync directly: must time out at ~3 seconds
      await controller.syncPendingRides(force: true);
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(2900));
      expect(stopwatch.elapsedMilliseconds, lessThan(4500));
      // Ride remains in pending queue safely
      expect(controller.pendingSyncCount, 1);
      expect(controller.ridesHistory.first.syncStatus, SyncStatus.pending);

      mockSupabase.hangCompleter!.complete();
      controller.dispose();
    });
  });

  group('P2: Mutex, Lifecycle & Retry Timer Tests', () {
    test('3. Mutex: Concurrent syncPendingRides() calls return same future and deduplicate upload',
        () async {
      final mockSupabase = MockSlowSupabaseService();
      mockSupabase.delay = const Duration(milliseconds: 60);

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      // Add a manual ride to queue
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(minutes: 10)),
        durationSeconds: 300,
        distanceMeters: 1000.0,
      );
      expect(controller.pendingSyncCount, 1);

      // Fire 3 simultaneous sync calls (e.g. from UI button, timer, and network change)
      final future1 = controller.syncPendingRides(force: true);
      final future2 = controller.syncPendingRides(force: true);
      final future3 = controller.syncPendingRides(force: true);

      expect(identical(future1, future2), true);
      expect(identical(future2, future3), true);
      expect(controller.isSyncingPending, true);

      await Future.wait([future1, future2, future3]);

      expect(controller.isSyncingPending, false);
      expect(controller.pendingSyncCount, 0);
      expect(mockSupabase.insertCallCount, 1); // Exact 1 upload, no duplicates!

      controller.dispose();
    });

    test('4. 20-Second Retry Timer: Starts when pending > 0, pauses on background, cancels when empty',
        () async {
      final mockSupabase = MockSlowSupabaseService();
      mockSupabase.shouldFail = true; // Offline initially

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );

      await controller.startRide();
      controller.distanceMeters = 500.0;
      await controller.stopRide();

      expect(controller.pendingSyncCount, 1);
      // Timer is active in foreground
      expect(controller.pendingSyncTimer, isNotNull);
      expect(controller.pendingSyncTimer!.isActive, isTrue);

      // Background the app: timer is cancelled
      controller.setAppInForeground(false);
      expect(controller.isAppInForeground, false);
      expect(controller.pendingSyncTimer, isNull);

      // Bring app back to foreground: timer restarts
      controller.setAppInForeground(true);
      expect(controller.isAppInForeground, true);
      expect(controller.pendingSyncTimer, isNotNull);
      expect(controller.pendingSyncTimer!.isActive, isTrue);

      // Network recovers
      mockSupabase.shouldFail = false;

      // Pulse the 20-second timer: proves the timer's own callback executes retry
      controller.onPendingSyncTimerTick();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.pendingSyncCount, 0);
      expect(mockSupabase.uploadedRides.length, 1);
      // When queue is empty, timer cancels and cleans up
      expect(controller.pendingSyncTimer, isNull);

      controller.dispose();
    });

    testWidgets('5. BikeTrackApp: Lifecycle observer updates isAppInForeground on paused and resumed',
        (tester) async {
      final mockSupabase = MockSlowSupabaseService();
      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);

      await tester.pumpWidget(
        BikeTrackApp(
          rideController: controller,
          themeController: themeController,
          localeController: localeController,
        ),
      );
      await tester.pumpAndSettle();

      expect(controller.isAppInForeground, true);

      // Simulate iOS background transition
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(controller.isAppInForeground, false);

      // Simulate user returning to app
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.isAppInForeground, true);

      controller.dispose();
    });
  });

  group('P2: DashboardScreen Pending Sync Card & Delete False-Positive Tests', () {
    testWidgets('6. Deleting a pending ride removes the card and does NOT show sync success snackbar',
        (tester) async {
      final mockSupabase = MockSlowSupabaseService();
      mockSupabase.shouldFail = true; // Offline

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);
      await localeController.setLanguage(AppLanguage.arabicEgyptian);

      // Add 1 pending ride
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 600,
        distanceMeters: 2000.0,
      );
      expect(controller.pendingSyncCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: controller,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card is visible
      expect(find.byKey(const Key('dashboard_pending_sync_card')), findsOneWidget);

      // User deletes the pending ride
      final pendingClientId = controller.ridesHistory.first.clientId;
      await controller.deleteRide(pendingClientId);
      await tester.pumpAndSettle();

      // Queue is now empty, card is gone
      expect(controller.pendingSyncCount, 0);
      expect(find.byKey(const Key('dashboard_pending_sync_card')), findsNothing);

      // CRITICAL VERIFICATION: No false "تمت مزامنة جميع الرحلات" SnackBar is shown!
      expect(find.text(localeController.strings.syncSuccessSnackbar), findsNothing);

      controller.dispose();
    });

    testWidgets('7. Genuine sync completion shows syncSuccessSnackbar and hides card',
        (tester) async {
      final mockSupabase = MockSlowSupabaseService();
      mockSupabase.shouldFail = true; // Offline initially

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);
      await localeController.setLanguage(AppLanguage.arabicEgyptian);

      // Add 2 offline rides
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 600,
        distanceMeters: 2000.0,
      );
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        durationSeconds: 900,
        distanceMeters: 3000.0,
      );

      expect(controller.pendingSyncCount, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: controller,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card must be visible with 2 pending rides
      expect(find.byKey(const Key('dashboard_pending_sync_card')), findsOneWidget);
      expect(find.byKey(const Key('dashboard_sync_now_button')), findsOneWidget);
      expect(find.text('2 رحلات بانتظار المزامنة'), findsOneWidget);

      // Network recovers
      mockSupabase.shouldFail = false;

      // Tap "Sync Now" button
      await tester.tap(find.byKey(const Key('dashboard_sync_now_button')));
      await tester.pump();

      // Complete async sync and settle
      await tester.pumpAndSettle();

      // Queue is cleared; card disappears
      expect(controller.pendingSyncCount, 0);
      expect(find.byKey(const Key('dashboard_pending_sync_card')), findsNothing);

      // Success SnackBar is genuinely shown!
      expect(find.text(localeController.strings.syncSuccessSnackbar), findsOneWidget);

      controller.dispose();
    });

    testWidgets('8. Partial sync (1/2 succeeds) + deleting remaining ride does NOT show sync SnackBar',
        (tester) async {
      final mockSupabase = MockSlowSupabaseService();
      // Offline initially while creating rides
      mockSupabase.shouldFail = true;

      final controller = RideController(
        supabaseService: mockSupabase,
        notificationService: FakeNotificationService(),
        telemetryService: FakeTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);
      await localeController.setLanguage(AppLanguage.arabicEgyptian);

      // Add 2 offline rides
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        durationSeconds: 600,
        distanceMeters: 2000.0,
      );
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        durationSeconds: 900,
        distanceMeters: 3000.0,
      );
      expect(controller.pendingSyncCount, 2);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: controller,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger sync: 1st ride succeeds, 2nd fails
      mockSupabase.shouldFail = false;
      mockSupabase.insertCallCount = 0;
      mockSupabase.failAfterCount = 1;
      await controller.syncPendingRides(force: true);
      await tester.pumpAndSettle();

      // Exactly 1 ride remains in queue
      expect(controller.pendingSyncCount, 1);
      // Because queue was NOT drained, syncDrainedCycleCount is still 0
      expect(controller.syncDrainedCycleCount, 0);
      // No snackbar should be displayed
      expect(find.text(localeController.strings.syncSuccessSnackbar), findsNothing);

      // Now user deletes the 2nd (failed/remaining) ride
      final remainingClientId = controller.ridesHistory.firstWhere((r) => r.syncStatus == SyncStatus.pending).clientId;
      await controller.deleteRide(remainingClientId);
      await tester.pumpAndSettle();

      // Queue is now empty (0 pending rides)
      expect(controller.pendingSyncCount, 0);
      expect(find.byKey(const Key('dashboard_pending_sync_card')), findsNothing);

      // CRITICAL: SnackBar MUST NOT BE SHOWN! The emptying was caused by delete, not sync!
      expect(find.text(localeController.strings.syncSuccessSnackbar), findsNothing);

      // Now add a new ride, allow network, and sync to drain
      mockSupabase.failAfterCount = -1;
      mockSupabase.shouldFail = false;
      await controller.addManualRide(
        startTime: DateTime.now().subtract(const Duration(minutes: 10)),
        durationSeconds: 300,
        distanceMeters: 1000.0,
      );
      expect(controller.pendingSyncCount, 1);
      await tester.pumpAndSettle();

      // Sync and drain
      await controller.syncPendingRides(force: true);
      await tester.pumpAndSettle();

      // Genuine drain happened: SnackBar is now shown!
      expect(controller.pendingSyncCount, 0);
      expect(controller.syncDrainedCycleCount, 1);
      expect(find.text(localeController.strings.syncSuccessSnackbar), findsOneWidget);

      controller.dispose();
    });
  });
}
