import 'package:bike_track/features/gym/data/gym_bike_bridge.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_3d_screen.dart';
import 'package:bike_track/features/gym/services/gym_heatmap_service.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-HM-01 — GymBikeBridge Cycling Load Tests', () {
    test('Bridge correctly computes cycling fatigue and distributes to legs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final now = DateTime.now();
      final ride1 = RideModel(
        id: 1,
        startTime: now.subtract(const Duration(hours: 4)),
        durationSeconds: 3600,
        distanceMeters: 25000.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 10.0,
      );

      final ride2 = RideModel(
        id: 2,
        startTime: now.subtract(const Duration(hours: 20)),
        durationSeconds: 3600,
        distanceMeters: 20000.0,
        avgSpeedKmh: 20.0,
        maxSpeedKmh: 30.0,
        minSpeedKmh: 10.0,
      );

      final bridge = GymBikeBridge(
        prefs: prefs,
        overrideRides: [ride1, ride2],
      );

      final fatigue = await bridge.getCyclingMuscleFatigue();
      expect(fatigue.containsKey('quads'), isTrue);
      expect(fatigue.containsKey('calves'), isTrue);
      expect(fatigue.containsKey('hamstrings'), isTrue);
      expect(fatigue.containsKey('glutes'), isTrue);

      // Quads receive highest load (1.0 factor)
      expect(fatigue['quads']!, greaterThan(fatigue['calves']!));
      expect(fatigue['calves']!, greaterThan(fatigue['hamstrings']!));
      expect(fatigue['hamstrings']!, greaterThan(fatigue['glutes']!));
      expect(fatigue['quads']!, greaterThan(5.0));
    });

    test('Old rides beyond 48 hours window are excluded from fatigue calculation', () async {
      final now = DateTime.now();
      final oldRide = RideModel(
        id: 99,
        startTime: now.subtract(const Duration(hours: 50)),
        durationSeconds: 7200,
        distanceMeters: 50000.0,
        avgSpeedKmh: 25.0,
        maxSpeedKmh: 35.0,
        minSpeedKmh: 10.0,
      );

      final bridge = GymBikeBridge(overrideRides: [oldRide]);
      final fatigue = await bridge.getCyclingMuscleFatigue();
      expect(fatigue.isEmpty, isTrue);
    });
  });

  group('TEST-HM-02 — GymHeatmapService Combined Load Tests', () {
    late GymDatabaseService dbService;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('Service accurately merges completed Gym sets and Cycling rides into fatigue tiers', () async {
      final db = dbService.database;

      // Create a completed workout session with chest press sets
      final now = DateTime.now().toUtc().toIso8601String();
      await db.insert('WORKOUT_SESSION', {
        'id': 'sess-heat-1',
        'started_at': now,
        'status': 'DONE',
      });

      await db.insert('SESSION_EXERCISE', {
        'id': 'se-heat-1',
        'session_id': 'sess-heat-1',
        'exercise_id': 'bench_press',
        'sort_order': 0,
      });

      // Add 6 heavy working sets to drive fatigue >= 7.0 (High Fatigue)
      for (int i = 1; i <= 6; i++) {
        await db.insert('SET_LOG', {
          'id': 'set-heat-$i',
          'session_exercise_id': 'se-heat-1',
          'set_number': i,
          'set_type': 'WORKING',
          'weight_kg': 100.0,
          'reps': 10,
          'completed': 1,
        });
      }

      // Add cycling ride that stresses quads
      final recentRide = RideModel(
        id: 100,
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        durationSeconds: 3600,
        distanceMeters: 30000.0,
        avgSpeedKmh: 30.0,
        maxSpeedKmh: 40.0,
        minSpeedKmh: 10.0,
      );
      final bikeBridge = GymBikeBridge(overrideRides: [recentRide]);

      final heatmapService = GymHeatmapService(
        dbService: dbService,
        bikeBridge: bikeBridge,
      );

      final scores = await heatmapService.computeMuscleFatigueScores();

      // Chest should have high fatigue from 6 working sets
      expect(scores.containsKey('chest'), isTrue);
      expect(scores['chest']!.gymScore, greaterThanOrEqualTo(5.0));
      expect(scores['chest']!.totalScore, greaterThan(3.0));

      // Quads should have cycling score
      expect(scores.containsKey('quads'), isTrue);
      expect(scores['quads']!.cyclingScore, greaterThan(5.0));

      // Color Map generates valid hex strings
      final colorMap = await heatmapService.computeHeatmapColorMap();
      expect(colorMap['chest'], isNotNull);
      expect(colorMap['chest']!.startsWith('#'), isTrue);
      expect(colorMap['quads'], isNotNull);
      expect(colorMap['quads']!.startsWith('#'), isTrue);
    });
  });

  group('TEST-HM-03 — Muscle3DScreen Heatmap UI & Category Filtering Tests', () {
    late GymDatabaseService dbService;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
    });

    tearDown(() async {
      await dbService.close();
      GymDatabaseService.defaultInstance = null;
    });

    Widget createTestApp(Widget home) {
      return MaterialApp(
        home: home,
      );
    }

    Future<void> pumpUntilFound(WidgetTester tester, Finder finder, {int maxRounds = 30}) async {
      for (int i = 0; i < maxRounds; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 60)));
        await tester.pump(const Duration(milliseconds: 60));
        if (finder.evaluate().isNotEmpty) {
          return;
        }
      }
      await tester.pump();
    }

    testWidgets('Tapping heatmap toggle button turns Heatmap ON and displays legend', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(Muscle3DScreen(dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('heatmap_toggle_button')));

      // Initially legend is not visible
      expect(find.byKey(const Key('heatmap_legend')), findsNothing);

      // Tap heatmap toggle
      await tester.tap(find.byKey(const Key('heatmap_toggle_button')));
      await pumpUntilFound(tester, find.byKey(const Key('heatmap_legend')));

      expect(find.byKey(const Key('heatmap_legend')), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
      expect(find.text('Fatigued'), findsOneWidget);

      // Tap again to toggle OFF
      await tester.tap(find.byKey(const Key('heatmap_toggle_button')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('heatmap_legend')), findsNothing);
    });

    testWidgets('Category filters in quick chips bar isolate targeted muscle groups', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(Muscle3DScreen(dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('category_filter_all')));

      expect(find.byKey(const Key('category_filter_all')), findsOneWidget);
      expect(find.byKey(const Key('category_filter_back')), findsOneWidget);
      expect(find.byKey(const Key('category_filter_legs')), findsOneWidget);

      // Initially ALL shows chest
      expect(find.byKey(const Key('3d_chip_chest')), findsOneWidget);

      // Filter by BACK
      await tester.ensureVisible(find.byKey(const Key('category_filter_back')));
      await tester.tap(find.byKey(const Key('category_filter_back')));
      await tester.pump(const Duration(milliseconds: 100));

      // Chest should no longer be visible in BACK filter
      expect(find.byKey(const Key('3d_chip_chest')), findsNothing);
      // Latissimus Dorsi or Traps should be visible
      expect(find.byKey(const Key('3d_chip_lats')), findsOneWidget);

      // Filter by LEGS
      await tester.ensureVisible(find.byKey(const Key('category_filter_legs')));
      await tester.tap(find.byKey(const Key('category_filter_legs')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('3d_chip_lats')), findsNothing);
      expect(find.byKey(const Key('3d_chip_quads')), findsOneWidget);

      // Restore ALL
      await tester.ensureVisible(find.byKey(const Key('category_filter_all')));
      await tester.tap(find.byKey(const Key('category_filter_all')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('3d_chip_chest')), findsOneWidget);
    });
  });
}
