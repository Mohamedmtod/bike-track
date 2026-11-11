import 'package:bike_track/features/gym/data/gym_bike_bridge.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:sqflite/sqflite.dart';

class MuscleFatigueScore {
  final String muscleId;
  final double gymScore;
  final double cyclingScore;
  final double totalScore;
  final String hexColor;

  const MuscleFatigueScore({
    required this.muscleId,
    required this.gymScore,
    required this.cyclingScore,
    required this.totalScore,
    required this.hexColor,
  });
}

/// Service that computes 3D Muscle Load & Fatigue Heatmap by combining
/// Gym workout volume with Cycling telemetry loads.
class GymHeatmapService {
  final GymDatabaseService _dbService;
  final GymBikeBridge _bikeBridge;

  GymHeatmapService({
    GymDatabaseService? dbService,
    GymBikeBridge? bikeBridge,
  })  : _dbService = dbService ?? GymDatabaseService.instance,
        _bikeBridge = bikeBridge ?? GymBikeBridge();

  Database get _db => _dbService.database;

  static const String colorHighFatigue = '#FF3B30'; // Red
  static const String colorModerateFatigue = '#FFCC00'; // Yellow/Amber
  static const String colorRecovered = '#34C759'; // Green

  /// Computes combined fatigue score for all muscles.
  Future<Map<String, MuscleFatigueScore>> computeMuscleFatigueScores({
    Duration window = const Duration(hours: 48),
  }) async {
    final cutoff = DateTime.now().toUtc().subtract(window).toIso8601String();

    final gymResults = await _db.rawQuery('''
      SELECT 
        em.muscle_id,
        em.role,
        ws.started_at,
        s.set_type
      FROM SET_LOG s
      JOIN SESSION_EXERCISE se ON s.session_exercise_id = se.id
      JOIN WORKOUT_SESSION ws ON se.session_id = ws.id
      JOIN EXERCISE_MUSCLE em ON (
        (se.performed_exercise_id IS NOT NULL AND se.performed_exercise_id = em.exercise_id)
        OR (se.performed_exercise_id IS NULL AND se.exercise_id = em.exercise_id)
      )
      WHERE ws.status = 'DONE' AND s.completed = 1 AND ws.started_at >= ?
    ''', [cutoff]);

    final Map<String, double> gymFatigue = {};
    final now = DateTime.now();

    for (final row in gymResults) {
      final muscleId = row['muscle_id'] as String;
      final role = row['role'] as String;
      final setTypeStr = (row['set_type'] as String?)?.toUpperCase() ?? 'WORKING';
      final startedAt = DateTime.parse(row['started_at'] as String);

      final hoursAgo = now.difference(startedAt.toLocal()).inHours;
      final decay = (1.0 - (hoursAgo / window.inHours)).clamp(0.1, 1.0);

      double setBase = 1.0;
      if (setTypeStr == 'WARMUP') setBase = 0.35;
      if (setTypeStr == 'DROP') setBase = 1.25;

      final roleMult = role == 'PRIMARY' ? 1.0 : 0.5;
      final score = setBase * roleMult * decay;

      gymFatigue[muscleId] = (gymFatigue[muscleId] ?? 0.0) + score;
    }

    // Merge cycling load
    final cycleFatigue = await _bikeBridge.getCyclingMuscleFatigue(window: window);

    // Fetch all 18 muscles to ensure complete map
    final muscleRows = await _db.query('MUSCLE');
    final allMuscleIds = muscleRows.map((r) => r['id'] as String).toSet();

    // Include muscles touched by cycling or gym even if not yet in database
    allMuscleIds.addAll(gymFatigue.keys);
    allMuscleIds.addAll(cycleFatigue.keys);

    final Map<String, MuscleFatigueScore> scores = {};
    for (final mId in allMuscleIds) {
      final gScore = gymFatigue[mId] ?? 0.0;
      final cScore = cycleFatigue[mId] ?? 0.0;
      final total = gScore + cScore;

      String color;
      if (total >= 7.0) {
        color = colorHighFatigue;
      } else if (total >= 3.0) {
        color = colorModerateFatigue;
      } else {
        color = colorRecovered;
      }

      scores[mId] = MuscleFatigueScore(
        muscleId: mId,
        gymScore: gScore,
        cyclingScore: cScore,
        totalScore: total,
        hexColor: color,
      );
    }

    return scores;
  }

  /// Returns a clean `Map<String, String>` of muscleId -> hexColor for Three.js.
  Future<Map<String, String>> computeHeatmapColorMap({
    Duration window = const Duration(hours: 48),
  }) async {
    final scores = await computeMuscleFatigueScores(window: window);
    return {for (final e in scores.entries) e.key: e.value.hexColor};
  }
}
