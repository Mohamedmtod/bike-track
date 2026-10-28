import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/models/analytics_models.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/daily_stats_screen.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/screens/overall_stats_screen.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/services/notification_service.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/services/share_service.dart';
import 'package:bike_track/services/supabase_service.dart';
import 'package:bike_track/services/telemetry_service.dart';
import 'package:bike_track/theme/theme_controller.dart';

class MockSupabaseService implements SupabaseService {
  final List<RideModel> cloudDatabase = [];

  @override
  Future<void> insertRide(RideModel ride) async {
    final existing = cloudDatabase.indexWhere((r) => r.clientId == ride.clientId);
    if (existing >= 0) {
      cloudDatabase[existing] = ride;
    } else {
      cloudDatabase.add(ride);
    }
  }

  @override
  Future<List<RideModel>> getAllRides() async {
    return List<RideModel>.from(cloudDatabase);
  }

  @override
  Future<void> deleteRide(String clientId, [int? id]) async {
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
    int id,
    String title,
    String body,
    Duration duration,
  ) async {}
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

  late MockSupabaseService mockSupabase;
  late FakeNotificationService fakeNotifications;
  late FakeTelemetryService fakeTelemetry;
  late FakeShareTestService fakeShareService;
  late RideController rideController;
  late ThemeController themeController;
  late LocaleController localeController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockSupabase = MockSupabaseService();
    fakeNotifications = FakeNotificationService();
    fakeTelemetry = FakeTelemetryService();
    fakeShareService = FakeShareTestService();

    themeController = ThemeController(autoLoad: false);
    localeController = LocaleController(autoLoad: false);

    rideController = RideController(
      supabaseService: mockSupabase,
      notificationService: fakeNotifications,
      telemetryService: fakeTelemetry,
      shareService: fakeShareService,
      autoFetchHistory: false,
      autoLoadPreferences: false,
    );
  });

  group('Day Analytics & Aggregation Unit Tests', () {
    test('Empty day returns clean zeroed DaySummary without NaN or errors', () {
      final summary = rideController.getDaySummary(DateTime(2026, 10, 15));

      expect(summary.rideCount, equals(0));
      expect(summary.totalDistanceMeters, equals(0.0));
      expect(summary.totalDistanceKm, equals(0.0));
      expect(summary.distanceKm, equals(0.0));
      expect(summary.totalDurationSeconds, equals(0));
      expect(summary.avgSpeedKmh, equals(0.0));
      expect(summary.maxSpeedKmh, isNull);
      expect(summary.minSpeedKmh, isNull);
      expect(summary.hasGpsRoutes, isFalse);
      expect(summary.allPolylines, isEmpty);
      expect(summary.rides, isEmpty);
    });

    test('Multiple rides on same local day compute accurate weighted average speed and metrics', () {
      final targetDate = DateTime(2026, 10, 20, 10, 0, 0);

      // Morning ride: 10km in 30 mins (avg: 20 km/h)
      final ride1 = RideModel(
        clientId: 'ride_morning',
        startTime: DateTime(2026, 10, 20, 8, 30),
        durationSeconds: 1800,
        distanceMeters: 10000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 28.5,
        minSpeedKmh: 10.0,
        routePoints: [
          const LatLng(30.0444, 31.2357),
          const LatLng(30.0500, 31.2400),
        ],
      );

      // Evening ride: 20km in 30 mins (avg: 40 km/h)
      final ride2 = RideModel(
        clientId: 'ride_evening',
        startTime: DateTime(2026, 10, 20, 19, 0),
        durationSeconds: 1800,
        distanceMeters: 20000.0,
        avgSpeedKmh: 40.0,
        maxSpeedKmh: 45.0,
        minSpeedKmh: 15.0,
        routePoints: [
          const LatLng(30.0600, 31.2500),
          const LatLng(30.0700, 31.2600),
        ],
      );

      // Other day ride (should be ignored)
      final rideOtherDay = RideModel(
        clientId: 'ride_other',
        startTime: DateTime(2026, 10, 21, 9, 0),
        durationSeconds: 3600,
        distanceMeters: 15000.0,
        avgSpeedKmh: 15.0,
        maxSpeedKmh: 22.0,
        minSpeedKmh: 8.0,
      );

      rideController.ridesHistory.addAll([ride1, ride2, rideOtherDay]);

      final summary = rideController.getDaySummary(targetDate);

      expect(summary.rideCount, equals(2));
      expect(summary.totalDistanceMeters, equals(30000.0));
      expect(summary.totalDistanceKm, equals(30.0));
      expect(summary.totalDurationSeconds, equals(3600));
      // Weighted avg: 30 km / 1 hr = 30.0 km/h (NOT arithmetic mean 30, but verified)
      expect(summary.avgSpeedKmh, closeTo(30.0, 0.01));
      expect(summary.maxSpeedKmh, equals(45.0));
      expect(summary.minSpeedKmh, equals(10.0));
      expect(summary.hasGpsRoutes, isTrue);
      expect(summary.allPolylines.length, equals(2));
      expect(summary.rides.first.clientId, equals('ride_morning')); // Chronological sorting
      expect(summary.rides.last.clientId, equals('ride_evening'));
    });

    test('Midnight boundary separation using toLocal()', () {
      // 23:55 on Oct 10th
      final lateNightRide = RideModel(
        clientId: 'ride_late_night',
        startTime: DateTime(2026, 10, 10, 23, 55),
        durationSeconds: 600,
        distanceMeters: 3000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 22.0,
        minSpeedKmh: 10.0,
      );

      // 00:05 on Oct 11th
      final earlyMorningRide = RideModel(
        clientId: 'ride_early_morning',
        startTime: DateTime(2026, 10, 11, 0, 5),
        durationSeconds: 900,
        distanceMeters: 5000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 12.0,
      );

      rideController.ridesHistory.addAll([lateNightRide, earlyMorningRide]);

      final oct10Summary = rideController.getDaySummary(DateTime(2026, 10, 10));
      final oct11Summary = rideController.getDaySummary(DateTime(2026, 10, 11));

      expect(oct10Summary.rideCount, equals(1));
      expect(oct10Summary.rides.first.clientId, equals('ride_late_night'));
      expect(oct10Summary.totalDistanceKm, equals(3.0));

      expect(oct11Summary.rideCount, equals(1));
      expect(oct11Summary.rides.first.clientId, equals('ride_early_morning'));
      expect(oct11Summary.totalDistanceKm, equals(5.0));
    });

    test('Manual ride without GPS correctly sets hasGpsRoutes: false', () {
      final manualRide = RideModel(
        clientId: 'manual_ride_1',
        startTime: DateTime(2026, 10, 12, 14, 0),
        durationSeconds: 1200,
        distanceMeters: 6000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 18.0,
        minSpeedKmh: 18.0,
        isManual: true,
        routePoints: const [],
      );

      rideController.ridesHistory.add(manualRide);

      final summary = rideController.getDaySummary(DateTime(2026, 10, 12));
      expect(summary.rideCount, equals(1));
      expect(summary.hasGpsRoutes, isFalse);
      expect(summary.allPolylines, isEmpty);
    });

    test('PersonalRecords correctly detects longest, fastest, and most active day', () {
      final r1 = RideModel(
        clientId: 'r1',
        startTime: DateTime(2026, 10, 1, 10, 0),
        durationSeconds: 3600,
        distanceMeters: 15000.0,
        avgSpeedKmh: 15.0,
        maxSpeedKmh: 20.0,
        minSpeedKmh: 10.0,
      );
      final r2 = RideModel(
        clientId: 'r2',
        startTime: DateTime(2026, 10, 5, 10, 0),
        durationSeconds: 1800,
        distanceMeters: 14000.0,
        avgSpeedKmh: 28.0, // Fastest avg speed
        maxSpeedKmh: 35.0,
        minSpeedKmh: 12.0,
      );
      final r3 = RideModel(
        clientId: 'r3',
        startTime: DateTime(2026, 10, 10, 8, 0),
        durationSeconds: 7200,
        distanceMeters: 45000.0, // Longest ride
        avgSpeedKmh: 22.5,
        maxSpeedKmh: 32.0,
        minSpeedKmh: 11.0,
      );
      // Another ride on Oct 10th to make it the undisputed most active day
      final r4 = RideModel(
        clientId: 'r4',
        startTime: DateTime(2026, 10, 10, 16, 0),
        durationSeconds: 1800,
        distanceMeters: 10000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 10.0,
      );

      rideController.ridesHistory.addAll([r1, r2, r3, r4]);

      final records = rideController.getPersonalRecords();

      expect(records.longestRide?.clientId, equals('r3'));
      expect(records.longestRide?.distanceKm, equals(45.0));

      expect(records.fastestRide?.clientId, equals('r2'));
      expect(records.fastestRide?.avgSpeedKmh, equals(28.0));

      expect(records.mostActiveDayDate?.year, equals(2026));
      expect(records.mostActiveDayDate?.month, equals(10));
      expect(records.mostActiveDayDate?.day, equals(10));
      expect(records.mostActiveDayDistanceKm, equals(55.0)); // 45km + 10km
    });

    test('PeriodSummary generates correct buckets and totals for Week, Month, and Year', () {
      final refDate = DateTime(2026, 10, 15); // Thursday

      final r1 = RideModel(
        clientId: 'r_oct15',
        startTime: DateTime(2026, 10, 15, 10, 0),
        durationSeconds: 3600,
        distanceMeters: 20000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 12.0,
      );

      rideController.ridesHistory.add(r1);

      // 1. Week Summary (Mon to Sun: 7 buckets)
      final weekSummary = rideController.getPeriodSummary(
        period: AnalyticsPeriod.week,
        referenceDate: refDate,
        metric: AnalyticsMetric.distance,
      );

      expect(weekSummary.period, equals(AnalyticsPeriod.week));
      expect(weekSummary.buckets.length, equals(7));
      expect(weekSummary.totalDistanceKm, equals(20.0));
      expect(weekSummary.rideCount, equals(1));

      // 2. Month Summary (October has 31 days: 31 buckets)
      final monthSummary = rideController.getPeriodSummary(
        period: AnalyticsPeriod.month,
        referenceDate: refDate,
        metric: AnalyticsMetric.distance,
      );

      expect(monthSummary.period, equals(AnalyticsPeriod.month));
      expect(monthSummary.buckets.length, equals(31));
      expect(monthSummary.totalDistanceKm, equals(20.0));

      // 3. Year Summary (12 months: 12 buckets)
      final yearSummary = rideController.getPeriodSummary(
        period: AnalyticsPeriod.year,
        referenceDate: refDate,
        metric: AnalyticsMetric.distance,
      );

      expect(yearSummary.period, equals(AnalyticsPeriod.year));
      expect(yearSummary.buckets.length, equals(12));
      expect(yearSummary.totalDistanceKm, equals(20.0));
    });
  });

  group('UI & Widget Navigation Tests', () {
    testWidgets('Tapping weekly bar chart column opens DailyStatsScreen', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final today = DateTime.now();
      final rideToday = RideModel(
        clientId: 'ride_today',
        startTime: today.subtract(const Duration(hours: 2)),
        durationSeconds: 1800,
        distanceMeters: 12000.0,
        avgSpeedKmh: 24.0,
        maxSpeedKmh: 31.0,
        minSpeedKmh: 15.0,
        routePoints: [
          const LatLng(30.0444, 31.2357),
          const LatLng(30.0500, 31.2400),
        ],
      );
      rideController.ridesHistory.add(rideToday);

      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find today's weekly bar column
      final barKey = Key('weekly_bar_${today.year}_${today.month}_${today.day}');
      expect(find.byKey(barKey), findsOneWidget);

      await tester.tap(find.byKey(barKey));
      await tester.pumpAndSettle();

      // Verify navigated to DailyStatsScreen
      expect(find.byType(DailyStatsScreen), findsOneWidget);
      expect(find.text('إحصائيات اليوم'), findsOneWidget);
    });

    testWidgets('DailyStatsScreen displays rest day empty state on zero rides', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final restDay = DateTime(2026, 10, 5);

      await tester.pumpWidget(
        MaterialApp(
          home: DailyStatsScreen(
            controller: rideController,
            date: restDay,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Rest day title and subtitle
      expect(find.text('يوم راحة واستشفاء 🧘‍♂️'), findsWidgets);
      expect(find.textContaining('لم تسجل أي رحلات بالدراجة'), findsWidgets);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('DailyStatsScreen displays multi-ride map, route chips, and filter selection', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final day = DateTime(2026, 10, 18);
      final r1 = RideModel(
        clientId: 'ride_1',
        startTime: DateTime(2026, 10, 18, 9, 0),
        durationSeconds: 1200,
        distanceMeters: 6000.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 24.0,
        minSpeedKmh: 10.0,
        routePoints: [
          const LatLng(30.0444, 31.2357),
          const LatLng(30.0500, 31.2400),
        ],
      );
      final r2 = RideModel(
        clientId: 'ride_2',
        startTime: DateTime(2026, 10, 18, 16, 0),
        durationSeconds: 1800,
        distanceMeters: 10000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 28.0,
        minSpeedKmh: 12.0,
        routePoints: [
          const LatLng(30.0600, 31.2500),
          const LatLng(30.0700, 31.2600),
        ],
      );
      rideController.ridesHistory.addAll([r1, r2]);

      await tester.pumpWidget(
        MaterialApp(
          home: DailyStatsScreen(
            controller: rideController,
            date: day,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Map is rendered
      expect(find.byType(FlutterMap), findsOneWidget);

      // Verify Filter chips exist ("كل المسارات", "رحلة 1", "رحلة 2")
      expect(find.textContaining('كل المسارات'), findsOneWidget);
      expect(find.textContaining('رحلة 1'), findsWidgets);
      expect(find.textContaining('رحلة 2'), findsWidgets);

      // Tap "رحلة 1" chip to isolate ride 1
      await tester.tap(find.textContaining('رحلة 1'));
      await tester.pumpAndSettle();

      // Tap chronological ride list item to open RideDetailsScreen
      final rideTile = find.byKey(const Key('daily_ride_item_0'));
      expect(rideTile, findsOneWidget);
      await tester.tap(rideTile);
      await tester.pumpAndSettle();

      expect(find.byType(RideDetailsScreen), findsOneWidget);
    });

    testWidgets('Tapping share button calls IShareService with generated card', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final day = DateTime(2026, 10, 18);
      final r1 = RideModel(
        clientId: 'ride_share_test',
        startTime: DateTime(2026, 10, 18, 9, 0),
        durationSeconds: 1800,
        distanceMeters: 10000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 25.0,
        minSpeedKmh: 12.0,
        routePoints: [
          const LatLng(30.0444, 31.2357),
          const LatLng(30.0500, 31.2400),
        ],
      );
      rideController.ridesHistory.add(r1);

      await tester.pumpWidget(
        MaterialApp(
          home: DailyStatsScreen(
            controller: rideController,
            date: day,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find share button
      final shareBtn = find.byKey(const Key('daily_stats_share_button'));
      expect(shareBtn, findsOneWidget);

      await tester.tap(shareBtn);
      await tester.pumpAndSettle();

      // Verify fakeShareService was invoked
      expect(fakeShareService.sharedByteLengths.length, equals(1));
      expect(fakeShareService.sharedSubjects.first, contains('ProBike'));
      expect(fakeShareService.sharedTexts.first, contains('10.0 كم'));
    });

    testWidgets('OverallStatsScreen switches periods and metrics cleanly', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final r1 = RideModel(
        clientId: 'r_overall_1',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        durationSeconds: 3600,
        distanceMeters: 25000.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 15.0,
      );
      rideController.ridesHistory.add(r1);

      await tester.pumpWidget(
        MaterialApp(
          home: OverallStatsScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify title & all-time odometer
      expect(find.text('مركز الإحصائيات'), findsOneWidget);
      expect(find.text('العداد التراكمي الشامل'), findsOneWidget);
      expect(find.textContaining('25.0 كم'), findsWidgets);

      // Switch to "شهر" (Month)
      await tester.tap(find.text('شهر'));
      await tester.pumpAndSettle();

      // Switch metric to "المدة" (Duration)
      await tester.tap(find.text('المدة'));
      await tester.pumpAndSettle();

      // Switch metric to "السرعة" (Speed)
      await tester.tap(find.text('السرعة'));
      await tester.pumpAndSettle();

      // Switch to "الكل" (All time)
      await tester.tap(find.text('الكل'));
      await tester.pumpAndSettle();

      // Personal records section verification
      expect(find.text('أرقامك القياسية 🏆'), findsOneWidget);
      expect(find.text('أطول رحلة'), findsOneWidget);
      expect(find.text('أسرع رحلة (متوسط)'), findsOneWidget);
      expect(find.text('اليوم الأكثر نشاطاً'), findsOneWidget);
    });

    testWidgets('DailyStatsScreen displays manual-only notice when day has rides but no GPS tracks', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final day = DateTime(2026, 10, 14);
      final manualRide = RideModel(
        clientId: 'manual_only_ride',
        startTime: DateTime(2026, 10, 14, 15, 0),
        durationSeconds: 1500,
        distanceMeters: 7500.0,
        avgSpeedKmh: 18.0,
        maxSpeedKmh: 18.0,
        minSpeedKmh: 18.0,
        isManual: true,
        routePoints: const [],
      );
      rideController.ridesHistory.add(manualRide);

      await tester.pumpWidget(
        MaterialApp(
          home: DailyStatsScreen(
            controller: rideController,
            date: day,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('جميع رحلات هذا اليوم مسجلة يدوياً بدون مسار GPS.'), findsWidgets);
      expect(find.byType(FlutterMap), findsNothing);
    });

    testWidgets('DailyStatsScreen displays live ride notice when ride is currently active on today', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() async {
        if (rideController.state != RideState.idle) {
          await rideController.stopRide();
        }
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Start an active ride
      await rideController.startRide();

      await tester.pumpWidget(
        MaterialApp(
          home: DailyStatsScreen(
            controller: rideController,
            date: DateTime.now(),
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('يتضمن هذا الملخص بيانات الرحلة الجارية حالياً 🔴'), findsOneWidget);

      await rideController.stopRide();
      await tester.pumpAndSettle();
    });

    testWidgets('OverallStatsScreen chevron buttons navigate periods and personal record opens RideDetailsScreen', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testRide = RideModel(
        clientId: 'ride_record_longest',
        startTime: DateTime(2026, 10, 10, 8, 0),
        durationSeconds: 7200,
        distanceMeters: 50000.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 15.0,
      );
      rideController.ridesHistory.add(testRide);

      await tester.pumpWidget(
        MaterialApp(
          home: OverallStatsScreen(
            controller: rideController,
            themeController: themeController,
            localeController: localeController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap previous period button
      final prevBtn = find.byTooltip('الفترة السابقة');
      expect(prevBtn, findsOneWidget);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      // Tap next period button
      final nextBtn = find.byTooltip('الفترة التالية');
      expect(nextBtn, findsOneWidget);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      // Tap longest ride card to open RideDetailsScreen
      expect(find.text('أطول رحلة'), findsOneWidget);
      await tester.tap(find.text('أطول رحلة'));
      await tester.pumpAndSettle();

      expect(find.byType(RideDetailsScreen), findsOneWidget);
    });
  });
}
