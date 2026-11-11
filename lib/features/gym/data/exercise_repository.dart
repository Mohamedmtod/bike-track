import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:sqflite/sqflite.dart';

class ExerciseRepository {
  final GymDatabaseService _dbService;

  ExerciseRepository({GymDatabaseService? dbService})
      : _dbService = dbService ?? GymDatabaseService.instance;

  Database get _db => _dbService.database;

  Future<List<Exercise>> getAllExercises() async {
    final results = await _db.query('EXERCISE', orderBy: 'name ASC');
    return results.map(Exercise.fromMap).toList();
  }

  Future<Exercise?> getExerciseById(String id) async {
    final results = await _db.query('EXERCISE', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Exercise.fromMap(results.first);
  }

  Future<List<Exercise>> getExercisesForMuscle(String muscleId) async {
    final results = await _db.rawQuery('''
      SELECT e.*
      FROM EXERCISE e
      JOIN EXERCISE_MUSCLE em ON e.id = em.exercise_id
      WHERE em.muscle_id = ?
      ORDER BY em.role ASC, e.name ASC
    ''', [muscleId]);
    return results.map(Exercise.fromMap).toList();
  }

  Future<List<Exercise>> searchExercises(String query) async {
    final cleanQuery = '%${query.trim().toLowerCase()}%';
    final results = await _db.rawQuery('''
      SELECT * FROM EXERCISE
      WHERE LOWER(name) LIKE ? OR LOWER(equipment) LIKE ?
      ORDER BY name ASC
    ''', [cleanQuery, cleanQuery]);
    return results.map(Exercise.fromMap).toList();
  }

  /// Fetches the last completed set performance for a list of exercise IDs.
  Future<Map<String, SetLog>> getLastPerformanceForExercises(List<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return {};
    final placeholders = List.filled(exerciseIds.length, '?').join(',');
    final results = await _db.rawQuery('''
      SELECT s.*, se.exercise_id
      FROM SET_LOG s
      JOIN SESSION_EXERCISE se ON s.session_exercise_id = se.id
      JOIN WORKOUT_SESSION ws ON se.session_id = ws.id
      WHERE se.exercise_id IN ($placeholders) AND s.completed = 1
      ORDER BY ws.started_at DESC, s.set_number DESC
    ''', exerciseIds);

    final map = <String, SetLog>{};
    for (final row in results) {
      final exId = row['exercise_id'] as String;
      if (!map.containsKey(exId)) {
        map[exId] = SetLog.fromMap(row);
      }
    }
    return map;
  }
}
