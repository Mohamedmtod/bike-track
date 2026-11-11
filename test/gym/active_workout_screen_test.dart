import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/presentation/screens/active_workout_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-WL-01..05 — Active Workout Logging & Engine Tests', () {
    late GymDatabaseService dbService;
    late WorkoutRepository workoutRepo;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
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

    testWidgets('ActiveWorkoutScreen renders empty state when session has no exercises', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.text('Active Workout'));

      expect(find.text('Active Workout'), findsOneWidget);
      expect(find.text('No exercises in this workout yet.'), findsOneWidget);
      expect(find.byKey(const Key('empty_add_exercise_button')), findsOneWidget);
      expect(find.byKey(const Key('finish_workout_button')), findsOneWidget);
    });

    testWidgets('Adding exercise from picker creates exercise section and first set', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('empty_add_exercise_button')));

      // Tap Add Exercise
      await tester.tap(find.byKey(const Key('empty_add_exercise_button')));
      await pumpUntilFound(tester, find.byKey(const Key('picker_item_bench_press')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byKey(const Key('picker_item_bench_press')));

      // Select Barbell Bench Press
      await tester.tap(find.byKey(const Key('picker_item_bench_press')));
      await pumpUntilFound(tester, find.byKey(const Key('workout_exercise_bench_press')));

      expect(find.byKey(const Key('workout_exercise_bench_press')), findsOneWidget);
      expect(find.text('BARBELL • BILATERAL'), findsOneWidget);
      expect(find.text('SET'), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // Set 1 automatically created
    });

    testWidgets('Completing a set toggles checkbox, triggers rest countdown, and saves to SQLite', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');
        await workoutRepo.saveSetLog(
          SetLog(
            id: 'set_${se.id}_1',
            sessionExerciseId: se.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: 80.0,
            reps: 10,
            completed: false,
          ),
        );
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.text('80'));

      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

      // Tap Complete Set Checkbox
      await tester.tap(find.byIcon(Icons.radio_button_unchecked));
      await pumpUntilFound(tester, find.byKey(const Key('rest_timer_banner')));

      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.byKey(const Key('rest_timer_banner')), findsOneWidget);
      expect(find.textContaining('REST:'), findsOneWidget);

      // Verify set completed status persisted in SQLite
      await tester.runAsync(() async {
        final exercises = await workoutRepo.getSessionExercises(sessionId!);
        final sets = await workoutRepo.getSetsForSessionExercise(exercises.first.id);
        expect(sets.first.completed, isTrue);
      });
    });

    testWidgets('Finishing workout marks session DONE in database', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('finish_workout_button')));

      // Tap finish workout
      await tester.tap(find.byKey(const Key('finish_workout_button')));
      await pumpUntilFound(tester, find.textContaining('Workout completed'));

      expect(find.textContaining('Workout completed'), findsOneWidget);

      // Verify session status is DONE
      await tester.runAsync(() async {
        final active = await workoutRepo.getActiveSession();
        expect(active, isNull); // No active sessions remaining
        final recent = await workoutRepo.getRecentSessions();
        expect(recent.any((s) => s.id == sessionId && s.status == 'DONE'), isTrue);
      });
    });
  });
}
