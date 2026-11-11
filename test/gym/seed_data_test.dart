import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/gym_seed_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('TEST-DB-02 — Gym Seed Data & Muscle/Exercise Catalog Tests', () {
    late GymDatabaseService dbService;
    late Database db;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      db = await dbService.initialize(inMemory: true);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('All 18 muscle groups and 126 mesh bindings are automatically seeded', () async {
      final muscles = await db.query('MUSCLE');
      expect(muscles.length, equals(18), reason: 'Must seed exactly 18 muscle groups');

      final muscleIds = muscles.map((m) => m['id'] as String).toSet();
      expect(muscleIds, containsAll([
        'chest',
        'front-shoulders',
        'rear-shoulders',
        'biceps',
        'triceps',
        'forearms',
        'abdominals',
        'obliques',
        'traps',
        'traps-middle',
        'lats',
        'lowerback',
        'glutes',
        'quads',
        'hamstrings',
        'calves',
        'tibialis',
        'adductors',
      ]));

      final bindings = await db.query('MUSCLE_MESH_BINDING');
      expect(bindings.length, equals(126), reason: 'Must seed exactly 126 3D mesh bindings');

      for (final b in bindings) {
        expect(muscleIds.contains(b['muscle_id']), isTrue);
        expect(b['side'], anyOf('left', 'right', 'both'));
      }
    });

    test('Exercise catalog is seeded with diverse equipment and logging types', () async {
      final exercises = await db.query('EXERCISE');
      expect(exercises.length, greaterThanOrEqualTo(30), reason: 'Should have a rich exercise catalog');

      final loggingTypes = exercises.map((e) => e['logging_type'] as String).toSet();
      expect(loggingTypes, containsAll(['weightAndReps', 'bodyweightReps', 'durationOnly']));

      // Check durationOnly for isometric holds like plank
      final plank = exercises.firstWhere((e) => e['id'] == 'plank');
      expect(plank['logging_type'], equals('durationOnly'));

      // Check bodyweight exercises
      final pushup = exercises.firstWhere((e) => e['id'] == 'pushup');
      expect(pushup['logging_type'], equals('bodyweightReps'));

      // Check standard barbell/dumbbell exercises
      final benchPress = exercises.firstWhere((e) => e['id'] == 'bench_press');
      expect(benchPress['logging_type'], equals('weightAndReps'));
      expect(benchPress['equipment'], equals('barbell'));
    });

    test('EXERCISE_MUSCLE targets link exercises with primary and secondary muscles', () async {
      final targets = await db.query('EXERCISE_MUSCLE');
      expect(targets.isNotEmpty, isTrue);

      final roles = targets.map((t) => t['role'] as String).toSet();
      expect(roles, containsAll(['PRIMARY', 'SECONDARY']));

      // Check bench press targets
      final benchTargets = await db.query(
        'EXERCISE_MUSCLE',
        where: 'exercise_id = ?',
        whereArgs: ['bench_press'],
      );
      final primaryMuscles = benchTargets
          .where((t) => t['role'] == 'PRIMARY')
          .map((t) => t['muscle_id'])
          .toList();
      final secondaryMuscles = benchTargets
          .where((t) => t['role'] == 'SECONDARY')
          .map((t) => t['muscle_id'])
          .toList();

      expect(primaryMuscles, contains('chest'));
      expect(secondaryMuscles, containsAll(['triceps', 'front-shoulders']));
    });

    test('Querying exercises by targeted muscle returns accurate results', () async {
      // Query all exercises targeting 'chest'
      final chestExercises = await db.rawQuery('''
        SELECT e.id, e.name, em.role
        FROM EXERCISE e
        JOIN EXERCISE_MUSCLE em ON e.id = em.exercise_id
        WHERE em.muscle_id = 'chest'
        ORDER BY em.role ASC, e.name ASC
      ''');

      expect(chestExercises.isNotEmpty, isTrue);
      final exerciseIds = chestExercises.map((e) => e['id'] as String).toList();
      expect(exerciseIds, containsAll(['bench_press', 'incline_db_press', 'cable_chest_fly', 'pushup', 'dips']));
    });

    test('GymSeedData.populate is idempotent and safe to call multiple times', () async {
      // Calling populate again should be a no-op
      await GymSeedData.populate(db);
      await GymSeedData.populate(db);

      final muscles = await db.query('MUSCLE');
      expect(muscles.length, equals(18));

      final bindings = await db.query('MUSCLE_MESH_BINDING');
      expect(bindings.length, equals(126));
    });
  });
}

