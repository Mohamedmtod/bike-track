import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/presentation/screens/gym_dashboard_screen.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:bike_track/screens/dashboard_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-UI-01 — Gym Dashboard & Free Selection Navigation Tests', () {
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

    testWidgets('GymDashboardScreen renders header, 3D card, and muscle chips cleanly', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556); // iPhone 14 Pro
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(GymDashboardScreen(dbService: dbService)));
      await pumpUntilFound(tester, find.text('ProBike Gym'));

      expect(find.text('ProBike Gym'), findsOneWidget);
      expect(find.byKey(const Key('open_3d_muscle_map_button')), findsOneWidget);
      expect(find.byKey(const Key('start_free_workout_button')), findsOneWidget);
      expect(find.text('MUSCLE GROUPS (المجموعات العضلية)'), findsOneWidget);

      // Verify sample muscle chips
      expect(find.byKey(const Key('muscle_chip_chest')), findsOneWidget);
      expect(find.byKey(const Key('muscle_chip_biceps')), findsOneWidget);
    });

    testWidgets('Tapping a muscle chip navigates to MuscleDetailScreen with targeted exercises', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(GymDashboardScreen(dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('muscle_chip_chest')));

      // Tap on chest muscle chip
      final chestChip = find.byKey(const Key('muscle_chip_chest'));
      expect(chestChip, findsOneWidget);
      await tester.tap(chestChip);
      await pumpUntilFound(tester, find.byType(MuscleDetailScreen));
      await pumpUntilFound(tester, find.text('TARGETED EXERCISES'));

      // Verify MuscleDetailScreen opened
      expect(find.byType(MuscleDetailScreen), findsOneWidget);
      expect(find.text('TARGETED EXERCISES'), findsOneWidget);
      expect(find.textContaining('Barbell Bench Press'), findsOneWidget);
    });

    testWidgets('Tapping Start Free Workout starts an active session and updates banner', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(GymDashboardScreen(dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('start_free_workout_button')));

      expect(find.text('Workout In Progress'), findsNothing);

      // Tap start workout button
      final startBtn = find.byKey(const Key('start_free_workout_button'));
      await tester.tap(startBtn);
      await pumpUntilFound(tester, find.text('Workout In Progress'));

      // Active workout banner should appear
      expect(find.text('Workout In Progress'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
    });

    testWidgets('DashboardScreen has a gym_button that navigates to GymDashboardScreen', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await tester.pumpWidget(createTestApp(DashboardScreen(controller: controller)));
      await pumpUntilFound(tester, find.byKey(const Key('gym_button')));

      final gymButton = find.byKey(const Key('gym_button'));
      expect(gymButton, findsOneWidget);

      await tester.tap(gymButton);
      await pumpUntilFound(tester, find.byType(GymDashboardScreen));

      expect(find.byType(GymDashboardScreen), findsOneWidget);
      controller.dispose();
    });
  });
}
