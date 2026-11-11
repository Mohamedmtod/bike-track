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

    testWidgets('Tapping Set Type badge cycles through WORKING, WARMUP, DROP, and persists to SQLite', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      String? setLogId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');
        setLogId = 'set_${se.id}_1';
        await workoutRepo.saveSetLog(
          SetLog(
            id: setLogId!,
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
      await pumpUntilFound(tester, find.byKey(Key('set_type_$setLogId')));

      // Initial state is working set ('1')
      expect(find.text('1'), findsOneWidget);

      // Tap 1: Cycles from working -> warmup ('W')
      await tester.tap(find.byKey(Key('set_type_$setLogId')));
      await tester.pump();
      expect(find.text('W'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.setType, equals(SetType.warmup));
      });

      // Tap 2: Cycles from warmup -> drop ('D')
      await tester.tap(find.byKey(Key('set_type_$setLogId')));
      await tester.pump();
      expect(find.text('D'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.setType, equals(SetType.drop));
      });

      // Tap 3: Cycles from drop -> working ('1')
      await tester.tap(find.byKey(Key('set_type_$setLogId')));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.setType, equals(SetType.working));
      });
    });

    testWidgets('Single tap on Ghost Pre-fill copies previous weight & reps instantly to set', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      String? newSetId;
      await tester.runAsync(() async {
        // Seed past completed session with 95 kg x 8 reps
        final pastSession = await workoutRepo.startSession();
        final pastSe = await workoutRepo.addExerciseToSession(pastSession.id, 'bench_press');
        await workoutRepo.saveSetLog(
          SetLog(
            id: 'past_set_${pastSe.id}_1',
            sessionExerciseId: pastSe.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: 95.0,
            reps: 8,
            completed: true,
          ),
        );
        await workoutRepo.endSession(pastSession.id);

        // Current active session with empty set
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');
        newSetId = 'set_${se.id}_1';
        await workoutRepo.saveSetLog(
          SetLog(
            id: newSetId!,
            sessionExerciseId: se.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: null,
            reps: null,
            completed: false,
          ),
        );
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(Key('ghost_prefill_$newSetId')));

      // Tap Ghost Pre-fill
      await tester.tap(find.byKey(Key('ghost_prefill_$newSetId')));
      await tester.pump();

      // Values should now be populated in UI and SQLite
      expect(find.text('95'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.weightKg, equals(95.0));
        expect(sets.first.reps, equals(8));
      });
    });

    testWidgets('Unilateral exercises display side badge and allow cycling L -> R -> B', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      String? setLogId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        final se = await workoutRepo.addExerciseToSession(session.id, 'cable_woodchopper');
        setLogId = 'set_${se.id}_1';
        await workoutRepo.saveSetLog(
          SetLog(
            id: setLogId!,
            sessionExerciseId: se.id,
            setNumber: 1,
            setType: SetType.working,
            weightKg: 20.0,
            reps: 12,
            side: 'left',
            completed: false,
          ),
        );
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(Key('set_side_$setLogId')));

      // Initial side is L
      expect(find.text('L'), findsOneWidget);

      // Tap: left -> right ('R')
      await tester.tap(find.byKey(Key('set_side_$setLogId')));
      await tester.pump();
      expect(find.text('R'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.side, equals('right'));
      });

      // Tap: right -> both ('B')
      await tester.tap(find.byKey(Key('set_side_$setLogId')));
      await tester.pump();
      expect(find.text('B'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.side, equals('both'));
      });
    });

    testWidgets('Duration-only exercises show duration stepper and update seconds in SQLite', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      String? setLogId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        final se = await workoutRepo.addExerciseToSession(session.id, 'plank');
        setLogId = 'set_${se.id}_1';
        await workoutRepo.saveSetLog(
          SetLog(
            id: setLogId!,
            sessionExerciseId: se.id,
            setNumber: 1,
            setType: SetType.working,
            durationSeconds: 45,
            completed: false,
          ),
        );
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.text('45s'));

      expect(find.text('TIME'), findsOneWidget);
      expect(find.text('45s'), findsOneWidget);

      // Increment duration by 5s
      await tester.tap(find.byKey(Key('increment_duration_$setLogId')));
      await tester.pump();
      expect(find.text('50s'), findsOneWidget);

      await tester.runAsync(() async {
        final sets = await workoutRepo.getSetsForSessionExercise((await workoutRepo.getSessionExercises(sessionId!)).first.id);
        expect(sets.first.durationSeconds, equals(50));
      });
    });

    testWidgets('Swapping exercise replaces current exercise with targeted alternative in SQLite and UI', (tester) async {
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
      await pumpUntilFound(tester, find.byKey(const Key('exercise_menu_bench_press')));

      // Open 3-dots popup menu
      await tester.tap(find.byKey(const Key('exercise_menu_bench_press')));
      await tester.pumpAndSettle();

      // Tap Swap Exercise
      await tester.tap(find.text('Swap Exercise (استبدال)'));
      await pumpUntilFound(tester, find.byKey(const Key('swap_item_incline_db_press')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(find.byKey(const Key('swap_item_incline_db_press')));

      // Select Incline Dumbbell Press
      await tester.tap(find.byKey(const Key('swap_item_incline_db_press')));
      await tester.pumpAndSettle();

      expect(find.text('Incline Dumbbell Press (تجميع بالدمبل عالي)'), findsOneWidget);

      await tester.runAsync(() async {
        final exercises = await workoutRepo.getSessionExercises(sessionId!);
        expect(exercises.first.performedExerciseId, equals('incline_db_press'));
      });
    });

    testWidgets('Monotonic rest timer recovers when session already has rest_ends_at_utc', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      String? sessionId;
      await tester.runAsync(() async {
        final session = await workoutRepo.startSession();
        sessionId = session.id;
        await workoutRepo.updateRestEndsAt(
          session.id,
          DateTime.now().toUtc().add(const Duration(seconds: 45)),
          durationSeconds: 45,
        );
      });

      await tester.pumpWidget(createTestApp(ActiveWorkoutScreen(sessionId: sessionId!, dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('rest_timer_banner')));

      expect(find.byKey(const Key('rest_timer_banner')), findsOneWidget);
      expect(find.textContaining('REST:'), findsOneWidget);

      // Tap +30s
      await tester.tap(find.text('+30s'));
      await tester.pump();

      // Tap SKIP
      await tester.tap(find.text('SKIP'));
      await tester.pump();

      expect(find.byKey(const Key('rest_timer_banner')), findsNothing);

      await tester.runAsync(() async {
        final active = await workoutRepo.getActiveSession();
        expect(active?.restEndsAtUtc, isNull);
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
