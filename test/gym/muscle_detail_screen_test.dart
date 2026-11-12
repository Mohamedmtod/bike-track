import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-UI-02 — Muscle Detail Screen & Performance Badges Tests', () {
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

    testWidgets('MuscleDetailScreen renders muscle header and targeted exercises with New badge', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(MuscleDetailScreen(muscleId: 'chest', dbService: dbService)));
      await pumpUntilFound(tester, find.text('TARGETED EXERCISES'));

      expect(find.text('TARGETED EXERCISES'), findsOneWidget);
      expect(find.textContaining('Barbell Bench Press'), findsOneWidget);
      expect(find.textContaining('New'), findsWidgets);
    });

    testWidgets('Displays Last Performance badge when previous completed sets exist in DB', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Seed a completed workout session with a set of bench press inside runAsync for isolate sync
      await tester.runAsync(() async {
        final workoutRepo = WorkoutRepository(dbService: dbService);
        final session = await workoutRepo.startSession();
        final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');

        final setLog = SetLog(
          id: 'test_set_1',
          sessionExerciseId: se.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 85.0,
          reps: 8,
          completed: true,
        );
        await workoutRepo.saveSetLog(setLog);
        await workoutRepo.endSession(session.id);
      });

      await tester.pumpWidget(createTestApp(MuscleDetailScreen(muscleId: 'chest', dbService: dbService)));
      await pumpUntilFound(tester, find.text('Last: 85 kg × 8'));

      expect(find.text('Last: 85 kg × 8'), findsOneWidget);
    });

    testWidgets('Tapping exercise card opens modal sheet and adds exercise to workout', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(MuscleDetailScreen(muscleId: 'chest', dbService: dbService)));
      await pumpUntilFound(tester, find.byKey(const Key('exercise_card_bench_press')));

      // Tap bench press card
      await tester.tap(find.byKey(const Key('exercise_card_bench_press')));
      await pumpUntilFound(tester, find.byKey(const Key('add_exercise_to_workout_button')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('INSTRUCTIONS & FORM'), findsOneWidget);
      expect(find.byKey(const Key('add_exercise_to_workout_button')), findsOneWidget);

      // Scroll to button and tap Add to Workout
      await tester.ensureVisible(find.byKey(const Key('add_exercise_to_workout_button')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('add_exercise_to_workout_button')));
      await pumpUntilFound(tester, find.textContaining('Added "Barbell Bench Press'));

      expect(find.textContaining('Added "Barbell Bench Press'), findsOneWidget);

      // Verify session exercise was actually inserted into database
      await tester.runAsync(() async {
        final workoutRepo = WorkoutRepository(dbService: dbService);
        final active = await workoutRepo.getActiveSession();
        expect(active, isNotNull);
        final exercisesInSession = await workoutRepo.getSessionExercises(active!.id);
        expect(exercisesInSession.any((e) => e.exerciseId == 'bench_press'), isTrue);
      });
    });
  });
}

