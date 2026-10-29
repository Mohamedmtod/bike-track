import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';
import 'package:bike_track/theme/theme_controller.dart';

class MockTestSupabaseService extends SupabaseService {
  final List<RideModel> rides = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    rides.add(ride);
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    return List.from(rides);
  }

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
    rides.removeWhere((r) => r.clientId == clientId);
  }
}

class FakeTestNotificationService implements INotificationService {
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

class FakeTestTelemetryService implements ITelemetryService {
  @override
  String? get currentSessionId => 'test';
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

  group('Midnight Ride Attribution: Model & Serialization Tests', () {
    test('1. RideModel toJson serializes start_time to explicit UTC and fromJson parses to local', () {
      // Local time: 2026-10-01 23:00:00
      final localStart = DateTime(2026, 10, 1, 23, 0, 0);
      final ride = RideModel(
        startTime: localStart,
        durationSeconds: 5400, // 1.5 hours -> ends 00:30 next day
        distanceMeters: 25000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 32.0,
        minSpeedKmh: 12.0,
      );

      final json = ride.toJson();
      final startTimeStr = json['start_time'] as String;

      // Must be formatted in UTC (contains 'Z' or zero offset)
      expect(startTimeStr.endsWith('Z'), isTrue);
      expect(DateTime.parse(startTimeStr).isUtc, isTrue);

      // Deserializing must convert to local time matching localStart
      final deserialized = RideModel.fromJson(json);
      expect(deserialized.startTime.isUtc, isFalse);
      expect(deserialized.startTime.year, localStart.year);
      expect(deserialized.startTime.month, localStart.month);
      expect(deserialized.startTime.day, localStart.day);
      expect(deserialized.startTime.hour, localStart.hour);
      expect(deserialized.startTime.minute, localStart.minute);
    });

    test('2. isOvernight property detects rides crossing midnight', () {
      // Overnight ride: Starts 23:15, lasts 90 mins (ends 00:45 next day)
      final overnightRide = RideModel(
        startTime: DateTime(2026, 10, 1, 23, 15, 0),
        durationSeconds: 5400,
        distanceMeters: 20000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 30.0,
        minSpeedKmh: 10.0,
      );
      expect(overnightRide.isOvernight, isTrue);

      // Normal daytime ride: Starts 14:00, lasts 2 hours (ends 16:00 same day)
      final daytimeRide = RideModel(
        startTime: DateTime(2026, 10, 1, 14, 0, 0),
        durationSeconds: 7200,
        distanceMeters: 40000.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 15.0,
      );
      expect(daytimeRide.isOvernight, isFalse);
    });
  });

  group('Midnight Ride Attribution: Controller & Stats Tests', () {
    test('3. Ride started at 23:00 and stopped at 00:30 belongs to day 1 and not day 2', () async {
      DateTime simulatedClock = DateTime(2026, 10, 1, 23, 0, 0);

      final controller = RideController(
        supabaseService: MockTestSupabaseService(),
        notificationService: FakeTestNotificationService(),
        telemetryService: FakeTestTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      controller.setClockForTest(() => simulatedClock);

      // 1. Start ride on Oct 1 at 23:00
      await controller.startRide();
      controller.distanceMeters = 18000.0;

      // 2. Advance clock to next day (Oct 2, 00:30 - exactly 90 minutes)
      simulatedClock = DateTime(2026, 10, 2, 0, 30, 0);

      // 3. Stop ride
      await controller.stopRide();

      expect(controller.ridesHistory.length, 1);
      final savedRide = controller.ridesHistory.first;
      expect(savedRide.startTime.day, 1);
      expect(savedRide.startTime.month, 10);
      expect(savedRide.startTime.year, 2026);
      expect(savedRide.isOvernight, isTrue);

      // Day 1 summary must contain the 18km ride
      final day1Summary = controller.getDaySummary(DateTime(2026, 10, 1));
      expect(day1Summary.rideCount, 1);
      expect(day1Summary.totalDistanceKm, 18.0);

      // Day 2 summary must have 0 rides
      final day2Summary = controller.getDaySummary(DateTime(2026, 10, 2));
      expect(day2Summary.rideCount, 0);
      expect(day2Summary.totalDistanceKm, 0.0);

      // Today stats on Day 2 (now is Oct 2, 00:30)
      expect(controller.todayDistanceKm, 0.0);
      expect(controller.todayDurationSeconds, 0);

      // When checking Day 1 as today
      simulatedClock = DateTime(2026, 10, 1, 23, 50, 0);
      expect(controller.todayDistanceKm, 18.0);
      expect(controller.todayDurationSeconds, 5400);

      controller.dispose();
    });

    test('4. Active ride started at 23:00 appears in day 1 column of weeklyDailyStats even when clock is 00:15', () async {
      DateTime simulatedClock = DateTime(2026, 10, 1, 23, 0, 0);

      final controller = RideController(
        supabaseService: MockTestSupabaseService(),
        notificationService: FakeTestNotificationService(),
        telemetryService: FakeTestTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      controller.setClockForTest(() => simulatedClock);

      await controller.startRide();
      controller.distanceMeters = 8000.0;
      controller.durationSeconds = 1800; // 30 mins

      // Advance clock into next day (00:15 on Oct 2)
      simulatedClock = DateTime(2026, 10, 2, 0, 15, 0);

      // Retrieve weekly daily stats (includes active ride)
      final weeklyStats = controller.weeklyDailyStats;

      // Find day 1 and day 2 stats in the 7-day window
      final day1Stat = weeklyStats.firstWhere(
        (s) => s.date.day == 1 && s.date.month == 10,
      );
      final day2Stat = weeklyStats.firstWhere(
        (s) => s.date.day == 2 && s.date.month == 10,
      );

      // Day 1 stat MUST contain the active ride
      expect(day1Stat.rideCount, 1);
      expect(day1Stat.totalDistanceKm, 8.0);

      // Day 2 stat must NOT contain the active ride
      expect(day2Stat.rideCount, 0);
      expect(day2Stat.totalDistanceKm, 0.0);

      controller.dispose();
    });
  });

  group('Midnight Ride Attribution: UI Widget Tests', () {
    testWidgets('5. DashboardScreen displays overnight badge on overnight rides and hides it on daytime rides', (tester) async {
      final controller = RideController(
        supabaseService: MockTestSupabaseService(),
        notificationService: FakeTestNotificationService(),
        telemetryService: FakeTestTelemetryService(),
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      final themeController = ThemeController(autoLoad: false);
      final localeController = LocaleController(autoLoad: false);
      await localeController.setLanguage(AppLanguage.arabicEgyptian);

      // Add 1 overnight ride (starts 23:10, 75 mins -> ends 00:25 next day)
      final overnightRide = RideModel(
        clientId: 'overnight_1',
        startTime: DateTime(2026, 10, 1, 23, 10, 0),
        durationSeconds: 4500,
        distanceMeters: 15000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 30.0,
        minSpeedKmh: 10.0,
      );

      // Add 1 daytime ride (starts 10:00, 30 mins -> ends 10:30 same day)
      final daytimeRide = RideModel(
        clientId: 'daytime_1',
        startTime: DateTime(2026, 10, 1, 10, 0, 0),
        durationSeconds: 1800,
        distanceMeters: 6000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 12.0,
      );

      controller.ridesHistory.addAll([overnightRide, daytimeRide]);

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

      // Exactly 1 overnight badge should be displayed
      expect(find.byKey(const Key('ride_overnight_badge')), findsOneWidget);
      expect(find.text(localeController.strings.overnightRideBadge), findsOneWidget);

      controller.dispose();
    });
  });
}
