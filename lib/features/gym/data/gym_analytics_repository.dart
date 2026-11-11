import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/exercise_analytics.dart';
import 'package:sqflite/sqflite.dart';

class GymAnalyticsRepository {
  final GymDatabaseService _dbService;

  GymAnalyticsRepository({GymDatabaseService? dbService})
      : _dbService = dbService ?? GymDatabaseService.instance;

  Database get _db => _dbService.database;

  /// Calculates estimated 1RM using Brzycki formula: weight * (36 / (37 - reps))
  static double calculate1RM(double weightKg, int reps) {
    if (weightKg <= 0 || reps <= 0) return 0.0;
    if (reps == 1) return weightKg;
    if (reps >= 37) return weightKg * 1.5; // Cap to avoid division by zero or negative
    return weightKg * (36.0 / (37.0 - reps));
  }

  /// Fetches chronological session datapoints for charts.
  Future<List<ExerciseDataPoint>> getExerciseDataPoints(String exerciseId) async {
    final results = await _db.rawQuery('''
      SELECT 
        ws.id as session_id,
        ws.started_at,
        s.weight_kg,
        s.reps,
        s.duration_seconds
      FROM SET_LOG s
      JOIN SESSION_EXERCISE se ON s.session_exercise_id = se.id
      JOIN WORKOUT_SESSION ws ON se.session_id = ws.id
      WHERE (se.exercise_id = ? OR se.performed_exercise_id = ?)
        AND ws.status = 'DONE'
        AND s.completed = 1
      ORDER BY ws.started_at ASC, s.set_number ASC
    ''', [exerciseId, exerciseId]);

    if (results.isEmpty) return [];

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in results) {
      final sId = row['session_id'] as String;
      grouped.putIfAbsent(sId, () => []).add(row);
    }

    final List<ExerciseDataPoint> points = [];
    for (final entry in grouped.entries) {
      final rows = entry.value;
      final date = DateTime.parse(rows.first['started_at'] as String);

      double maxWeight = 0.0;
      double totalVolume = 0.0;
      double best1RM = 0.0;
      int totalReps = 0;

      for (final r in rows) {
        final w = (r['weight_kg'] as num?)?.toDouble() ?? 0.0;
        final reps = (r['reps'] as int?) ?? 0;

        if (w > maxWeight) maxWeight = w;
        totalVolume += (w * reps);
        totalReps += reps;

        final oneRm = calculate1RM(w, reps);
        if (oneRm > best1RM) best1RM = oneRm;
      }

      points.add(
        ExerciseDataPoint(
          date: date,
          maxWeightKg: maxWeight,
          totalVolumeKg: totalVolume,
          estimated1RM: best1RM,
          totalReps: totalReps,
          setsCount: rows.length,
        ),
      );
    }

    return points;
  }

  /// Calculates all-time personal records (PRs) for an exercise.
  Future<ExercisePRs> getExercisePRs(String exerciseId) async {
    final points = await getExerciseDataPoints(exerciseId);
    if (points.isEmpty) return ExercisePRs.empty;

    double maxWeight = 0;
    DateTime? maxWeightDate;

    double best1RM = 0;
    DateTime? best1RMDate;

    double maxVolume = 0;
    DateTime? maxVolumeDate;

    for (final p in points) {
      if (p.maxWeightKg > maxWeight) {
        maxWeight = p.maxWeightKg;
        maxWeightDate = p.date;
      }
      if (p.estimated1RM > best1RM) {
        best1RM = p.estimated1RM;
        best1RMDate = p.date;
      }
      if (p.totalVolumeKg > maxVolume) {
        maxVolume = p.totalVolumeKg;
        maxVolumeDate = p.date;
      }
    }

    return ExercisePRs(
      maxWeightKg: maxWeight,
      maxWeightDate: maxWeightDate,
      bestEstimated1RM: best1RM,
      best1RMDate: best1RMDate,
      maxSessionVolumeKg: maxVolume,
      maxVolumeDate: maxVolumeDate,
      totalSessions: points.length,
    );
  }

  /// Fetches detailed session history with set breakdowns.
  Future<List<ExerciseSessionHistory>> getExerciseSessionHistory(String exerciseId) async {
    final results = await _db.rawQuery('''
      SELECT 
        ws.id as session_id,
        ws.started_at,
        s.set_number,
        s.weight_kg,
        s.reps,
        s.duration_seconds
      FROM SET_LOG s
      JOIN SESSION_EXERCISE se ON s.session_exercise_id = se.id
      JOIN WORKOUT_SESSION ws ON se.session_id = ws.id
      WHERE (se.exercise_id = ? OR se.performed_exercise_id = ?)
        AND ws.status = 'DONE'
        AND s.completed = 1
      ORDER BY ws.started_at DESC, s.set_number ASC
    ''', [exerciseId, exerciseId]);

    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final row in results) {
      final sId = row['session_id'] as String;
      grouped.putIfAbsent(sId, () => []).add(row);
    }

    final List<ExerciseSessionHistory> histories = [];
    for (final entry in grouped.entries) {
      final rows = entry.value;
      final date = DateTime.parse(rows.first['started_at'] as String);

      double maxWeight = 0.0;
      double totalVolume = 0.0;
      final sets = <HistoricalSetEntry>[];

      for (final r in rows) {
        final w = (r['weight_kg'] as num?)?.toDouble();
        final reps = r['reps'] as int?;
        final dur = r['duration_seconds'] as int?;
        final setNum = r['set_number'] as int;

        if (w != null && w > maxWeight) maxWeight = w;
        if (w != null && reps != null) totalVolume += (w * reps);

        sets.add(
          HistoricalSetEntry(
            setNumber: setNum,
            weightKg: w,
            reps: reps,
            durationSeconds: dur,
          ),
        );
      }

      histories.add(
        ExerciseSessionHistory(
          sessionId: entry.key,
          date: date,
          sets: sets,
          sessionVolumeKg: totalVolume,
          maxWeightKg: maxWeight,
        ),
      );
    }

    return histories;
  }
}
