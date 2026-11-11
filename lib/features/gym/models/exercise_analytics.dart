class ExerciseDataPoint {
  final DateTime date;
  final double maxWeightKg;
  final double totalVolumeKg;
  final double estimated1RM;
  final int totalReps;
  final int setsCount;

  const ExerciseDataPoint({
    required this.date,
    required this.maxWeightKg,
    required this.totalVolumeKg,
    required this.estimated1RM,
    required this.totalReps,
    required this.setsCount,
  });
}

class ExercisePRs {
  final double maxWeightKg;
  final DateTime? maxWeightDate;
  final double bestEstimated1RM;
  final DateTime? best1RMDate;
  final double maxSessionVolumeKg;
  final DateTime? maxVolumeDate;
  final int totalSessions;

  const ExercisePRs({
    required this.maxWeightKg,
    this.maxWeightDate,
    required this.bestEstimated1RM,
    this.best1RMDate,
    required this.maxSessionVolumeKg,
    this.maxVolumeDate,
    required this.totalSessions,
  });

  static const empty = ExercisePRs(
    maxWeightKg: 0,
    bestEstimated1RM: 0,
    maxSessionVolumeKg: 0,
    totalSessions: 0,
  );
}

class HistoricalSetEntry {
  final int setNumber;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;

  const HistoricalSetEntry({
    required this.setNumber,
    this.weightKg,
    this.reps,
    this.durationSeconds,
  });
}

class ExerciseSessionHistory {
  final String sessionId;
  final DateTime date;
  final List<HistoricalSetEntry> sets;
  final double sessionVolumeKg;
  final double maxWeightKg;

  const ExerciseSessionHistory({
    required this.sessionId,
    required this.date,
    required this.sets,
    required this.sessionVolumeKg,
    required this.maxWeightKg,
  });
}

