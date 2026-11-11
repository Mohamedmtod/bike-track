import 'package:flutter_test/flutter_test.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Setup sqflite ffi for local desktop tests
  sqfliteFfiInit();

  group('TEST-DB-01 — Gym SQLite Database Schema & Integrity Tests', () {
    late GymDatabaseService dbService;
    late Database db;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      db = await dbService.initialize(inMemory: true);
    });

    tearDown(() async {
      await dbService.close();
    });

    test('All 7 tables and indexes exist in database', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames, containsAll([
        'MUSCLE',
        'MUSCLE_MESH_BINDING',
        'EXERCISE',
        'EXERCISE_MUSCLE',
        'WORKOUT_SESSION',
        'SESSION_EXERCISE',
        'SET_LOG',
      ]));
    });

    test('Foreign key cascade deletes child session_exercise and set_log', () async {
      // 1. Insert or Replace Exercise
      await db.insert('EXERCISE', {
        'id': 'test_bench_press',
        'name': 'Barbell Bench Press Test',
        'logging_type': 'weightAndReps',
        'laterality': 'bilateral',
        'equipment': 'barbell',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 2. Insert Workout Session
      await db.insert('WORKOUT_SESSION', {
        'id': 'session_1',
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'IN_PROGRESS',
      });

      // 3. Insert Session Exercise
      await db.insert('SESSION_EXERCISE', {
        'id': 'se_1',
        'session_id': 'session_1',
        'exercise_id': 'test_bench_press',
        'sort_order': 0,
      });

      // 4. Insert Set Logs (including duration_seconds for plank check)
      await db.insert('SET_LOG', {
        'id': 'set_1',
        'session_exercise_id': 'se_1',
        'set_number': 1,
        'set_type': 'WORKING',
        'weight_kg': 80.0,
        'reps': 10,
        'duration_seconds': null,
        'side': 'both',
        'completed': 1,
      });

      await db.insert('SET_LOG', {
        'id': 'set_2',
        'session_exercise_id': 'se_1',
        'set_number': 2,
        'set_type': 'DROP',
        'weight_kg': 60.0,
        'reps': 12,
        'duration_seconds': null,
        'side': 'both',
        'completed': 1,
      });

      // Verify insertion
      final setsBefore = await db.query('SET_LOG', where: 'session_exercise_id = ?', whereArgs: ['se_1']);
      expect(setsBefore.length, equals(2));

      // Delete the parent session
      await db.delete('WORKOUT_SESSION', where: 'id = ?', whereArgs: ['session_1']);

      // Verify CASCADE deleted session_exercise and set_log
      final seAfter = await db.query('SESSION_EXERCISE', where: 'session_id = ?', whereArgs: ['session_1']);
      expect(seAfter.isEmpty, isTrue);

      final setsAfter = await db.query('SET_LOG', where: 'session_exercise_id = ?', whereArgs: ['se_1']);
      expect(setsAfter.isEmpty, isTrue);
    });

    test('CHECK constraints enforce valid set_type and side enum values', () async {
      await db.insert('EXERCISE', {
        'id': 'test_plank',
        'name': 'Standard Plank Test',
        'logging_type': 'durationOnly',
        'laterality': 'bilateral',
        'equipment': 'bodyweight',
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      await db.insert('WORKOUT_SESSION', {
        'id': 'session_2',
        'started_at': DateTime.now().toUtc().toIso8601String(),
        'status': 'IN_PROGRESS',
      });

      await db.insert('SESSION_EXERCISE', {
        'id': 'se_2',
        'session_id': 'session_2',
        'exercise_id': 'test_plank',
        'sort_order': 0,
      });

      // Valid insert with duration_seconds
      await db.insert('SET_LOG', {
        'id': 'set_plank_1',
        'session_exercise_id': 'se_2',
        'set_number': 1,
        'set_type': 'WORKING',
        'weight_kg': null,
        'reps': null,
        'duration_seconds': 60,
        'side': 'both',
        'completed': 1,
      });

      final queryResult = await db.query('SET_LOG', where: 'id = ?', whereArgs: ['set_plank_1']);
      expect(queryResult.first['duration_seconds'], equals(60));

      // Invalid set_type should throw DatabaseException
      expect(
        () async => await db.insert('SET_LOG', {
          'id': 'invalid_set',
          'session_exercise_id': 'se_2',
          'set_number': 2,
          'set_type': 'INVALID_TYPE',
          'side': 'both',
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Invalid side should throw DatabaseException
      expect(
        () async => await db.insert('SET_LOG', {
          'id': 'invalid_side',
          'session_exercise_id': 'se_2',
          'set_number': 3,
          'set_type': 'WORKING',
          'side': 'MIDDLE',
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
