import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/models/workout_session.dart';
import 'package:sqflite/sqflite.dart';

class WorkoutRepository {
  final GymDatabaseService _dbService;

  WorkoutRepository({GymDatabaseService? dbService})
      : _dbService = dbService ?? GymDatabaseService.instance;

  Database get _db => _dbService.database;

  /// Fetches current active workout session if one is in progress.
  Future<WorkoutSession?> getActiveSession() async {
    final results = await _db.query(
      'WORKOUT_SESSION',
      where: "status = 'IN_PROGRESS'",
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (results.isEmpty) return null;
    return WorkoutSession.fromMap(results.first);
  }

  /// Fetches recent completed sessions.
  Future<List<WorkoutSession>> getRecentSessions({int limit = 5}) async {
    final results = await _db.query(
      'WORKOUT_SESSION',
      where: "status = 'DONE'",
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return results.map(WorkoutSession.fromMap).toList();
  }

  /// Creates and starts a new workout session.
  Future<WorkoutSession> startSession({String? notes}) async {
    final id = 'session_${DateTime.now().millisecondsSinceEpoch}';
    final session = WorkoutSession(
      id: id,
      startedAt: DateTime.now().toUtc(),
      status: 'IN_PROGRESS',
      notes: notes,
    );

    await _db.insert('WORKOUT_SESSION', session.toMap());
    return session;
  }

  /// Marks a workout session as completed.
  Future<void> endSession(String sessionId) async {
    await _db.update(
      'WORKOUT_SESSION',
      {
        'status': 'DONE',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
        'rest_ends_at_utc': null,
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
  }

  /// Cancels / discards an active session.
  Future<void> cancelSession(String sessionId) async {
    await _db.delete('WORKOUT_SESSION', where: 'id = ?', whereArgs: [sessionId]);
  }

  /// Adds an exercise to a session.
  Future<SessionExercise> addExerciseToSession(String sessionId, String exerciseId) async {
    final countResult = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM SESSION_EXERCISE WHERE session_id = ?',
      [sessionId],
    );
    final count = Sqflite.firstIntValue(countResult) ?? 0;

    final id = 'se_${DateTime.now().millisecondsSinceEpoch}_$count';
    final se = SessionExercise(
      id: id,
      sessionId: sessionId,
      exerciseId: exerciseId,
      sortOrder: count,
    );

    await _db.insert('SESSION_EXERCISE', se.toMap());
    return se;
  }

  /// Fetches all exercises in a session.
  Future<List<SessionExercise>> getSessionExercises(String sessionId) async {
    final results = await _db.query(
      'SESSION_EXERCISE',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'sort_order ASC',
    );
    return results.map(SessionExercise.fromMap).toList();
  }

  /// Saves or updates a set log instantly.
  Future<void> saveSetLog(SetLog setLog) async {
    await _db.insert(
      'SET_LOG',
      setLog.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fetches sets for a specific session exercise.
  Future<List<SetLog>> getSetsForSessionExercise(String sessionExerciseId) async {
    final results = await _db.query(
      'SET_LOG',
      where: 'session_exercise_id = ?',
      whereArgs: [sessionExerciseId],
      orderBy: 'set_number ASC',
    );
    return results.map(SetLog.fromMap).toList();
  }

  /// Ghost Pre-fill helper: Gets the last performed working sets for a given exercise.
  Future<List<SetLog>> getLastPerformance(String exerciseId) async {
    final lastSessionResults = await _db.rawQuery('''
      SELECT se.id as session_exercise_id
      FROM SESSION_EXERCISE se
      JOIN WORKOUT_SESSION ws ON se.session_id = ws.id
      WHERE se.exercise_id = ? AND ws.status = 'DONE'
      ORDER BY ws.ended_at DESC
      LIMIT 1
    ''', [exerciseId]);

    if (lastSessionResults.isEmpty) return [];

    final sessionExerciseId = lastSessionResults.first['session_exercise_id'] as String;
    return getSetsForSessionExercise(sessionExerciseId);
  }
}
