import 'package:bike_track/features/gym/data/gym_analytics_repository.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/presentation/screens/exercise_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-UI-03 — Exercise Analytics, PRs, and Progression Charts', () {
    late GymDatabaseService dbService;
    late GymAnalyticsRepository analyticsRepo;
    late WorkoutRepository workoutRepo;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
      analyticsRepo = GymAnalyticsRepository(dbService: dbService);
      workoutRepo = WorkoutRepository(dbService: dbService);
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

    test('Brzycki formula calculates accurate 1RM across standard reps and edge cases', () {
      // 1 rep = exact weight
      expect(GymAnalyticsRepository.calculate1RM(100.0, 1), equals(100.0));

      // 100 kg x 5 reps -> 100 * (36 / 32) = 112.5 kg
      expect(GymAnalyticsRepository.calculate1RM(100.0, 5), closeTo(112.5, 0.01));

      // 80 kg x 10 reps -> 80 * (36 / 27) = 106.67 kg
      expect(GymAnalyticsRepository.calculate1RM(80.0, 10), closeTo(106.67, 0.01));

      // Zero or negative
      expect(GymAnalyticsRepository.calculate1RM(0.0, 10), equals(0.0));
      expect(GymAnalyticsRepository.calculate1RM(100.0, 0), equals(0.0));
    });

    test('GymAnalyticsRepository computes accurate PRs and datapoints across multiple sessions', () async {
      // Session 1: 80 kg x 10, 85 kg x 8
      final s1 = await workoutRepo.startSession();
      final se1 = await workoutRepo.addExerciseToSession(s1.id, 'bench_press');
      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_${se1.id}_1',
          sessionExerciseId: se1.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 80.0,
          reps: 10,
          completed: true,
        ),
      );
      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_${se1.id}_2',
          sessionExerciseId: se1.id,
          setNumber: 2,
          setType: SetType.working,
          weightKg: 85.0,
          reps: 8,
          completed: true,
        ),
      );
      await workoutRepo.endSession(s1.id);

      // Session 2: 90 kg x 6, 100 kg x 3
      final s2 = await workoutRepo.startSession();
      final se2 = await workoutRepo.addExerciseToSession(s2.id, 'bench_press');
      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_${se2.id}_1',
          sessionExerciseId: se2.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 90.0,
          reps: 6,
          completed: true,
        ),
      );
      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_${se2.id}_2',
          sessionExerciseId: se2.id,
          setNumber: 2,
          setType: SetType.working,
          weightKg: 100.0,
          reps: 3,
          completed: true,
        ),
      );
      await workoutRepo.endSession(s2.id);

      // Fetch points
      final points = await analyticsRepo.getExerciseDataPoints('bench_press');
      expect(points.length, equals(2));
      expect(points[0].maxWeightKg, equals(85.0));
      // Vol 1: (80*10) + (85*8) = 800 + 680 = 1480
      expect(points[0].totalVolumeKg, equals(1480.0));
      expect(points[1].maxWeightKg, equals(100.0));

      // Fetch PRs
      final prs = await analyticsRepo.getExercisePRs('bench_press');
      expect(prs.maxWeightKg, equals(100.0));
      expect(prs.totalSessions, equals(2));
      expect(prs.maxSessionVolumeKg, equals(1480.0));

      // Fetch session histories
      final history = await analyticsRepo.getExerciseSessionHistory('bench_press');
      expect(history.length, equals(2));
      expect(history.first.sets.length, equals(2));
    });

    testWidgets('ExerciseAnalyticsScreen renders PR cards, progression chart, and session history', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.runAsync(() async {
        // Seed 2 sessions
        final s1 = await workoutRepo.startSession();
        final se1 = await workoutRepo.addExerciseToSession(s1.id, 'bench_press');
        await workoutRepo.saveSetLog(
          SetLog(
            id: 'set_${se1.id}_1',
            sessionExerciseId: se1.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: 80.0,
            reps: 10,
            completed: true,
          ),
        );
        await workoutRepo.endSession(s1.id);

        final s2 = await workoutRepo.startSession();
        final se2 = await workoutRepo.addExerciseToSession(s2.id, 'bench_press');
        await workoutRepo.saveSetLog(
          SetLog(
            id: 'set_${se2.id}_1',
            sessionExerciseId: se2.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: 100.0,
            reps: 5,
            completed: true,
          ),
        );
        await workoutRepo.endSession(s2.id);
      });

      await tester.pumpWidget(
        createTestApp(
          ExerciseAnalyticsScreen(
            exerciseId: 'bench_press',
            dbService: dbService,
          ),
        ),
      );

      await pumpUntilFound(tester, find.byKey(const Key('pr_max_weight_card')));

      // Assert PR Cards are rendered with accurate values
      expect(find.byKey(const Key('pr_max_weight_card')), findsOneWidget);
      expect(find.text('100 kg'), findsOneWidget);
      expect(find.byKey(const Key('pr_1rm_card')), findsOneWidget);
      expect(find.byKey(const Key('pr_volume_card')), findsOneWidget);
      expect(find.byKey(const Key('pr_sessions_card')), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // 2 sessions

      // Assert Chart Card is rendered
      expect(find.byKey(const Key('exercise_progression_chart_card')), findsOneWidget);

      // Switch Chart Metric to 1RM
      await tester.tap(find.byKey(const Key('metric_btn_estimated1RM')));
      await tester.pump();

      // Switch Chart Metric to Volume
      await tester.tap(find.byKey(const Key('metric_btn_volume')));
      await tester.pump();

      // Assert Session History List renders
      expect(find.textContaining('Workout History'), findsOneWidget);
    });

    testWidgets('ExerciseAnalyticsScreen displays clean empty state when no workouts recorded', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestApp(
          ExerciseAnalyticsScreen(
            exerciseId: 'bench_press',
            dbService: dbService,
          ),
        ),
      );

      await pumpUntilFound(tester, find.byKey(const Key('pr_max_weight_card')));

      expect(find.text('--'), findsNWidgets(3)); // weight, 1rm, volume are '--'
      expect(find.text('0'), findsOneWidget); // 0 sessions
      expect(find.text('No session history recorded yet.'), findsOneWidget);
      expect(find.text('No workout history yet.'), findsOneWidget);
    });
  });
}

