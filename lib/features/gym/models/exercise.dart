/// Exercise logging type determining the required workout inputs.
enum ExerciseLoggingType {
  weightAndReps,
  bodyweightReps,
  durationOnly;

  static ExerciseLoggingType fromString(String value) {
    switch (value) {
      case 'bodyweightReps':
        return ExerciseLoggingType.bodyweightReps;
      case 'durationOnly':
        return ExerciseLoggingType.durationOnly;
      case 'weightAndReps':
      default:
        return ExerciseLoggingType.weightAndReps;
    }
  }

  String toDbString() {
    switch (this) {
      case ExerciseLoggingType.bodyweightReps:
        return 'bodyweightReps';
      case ExerciseLoggingType.durationOnly:
        return 'durationOnly';
      case ExerciseLoggingType.weightAndReps:
        return 'weightAndReps';
    }
  }
}

/// Representation of an exercise in the Gym catalog.
class Exercise {
  final String id;
  final String name;
  final ExerciseLoggingType loggingType;
  final String laterality; // 'bilateral', 'unilateral'
  final String equipment; // 'barbell', 'dumbbell', 'cable', 'machine', 'bodyweight'
  final String? instructions;
  final String? assetKey;

  const Exercise({
    required this.id,
    required this.name,
    required this.loggingType,
    required this.laterality,
    required this.equipment,
    this.instructions,
    this.assetKey,
  });

  factory Exercise.fromMap(Map<String, dynamic> map) {
    return Exercise(
      id: map['id'] as String,
      name: map['name'] as String,
      loggingType: ExerciseLoggingType.fromString(map['logging_type'] as String),
      laterality: map['laterality'] as String,
      equipment: map['equipment'] as String,
      instructions: map['instructions'] as String?,
      assetKey: map['asset_key'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'logging_type': loggingType.toDbString(),
      'laterality': laterality,
      'equipment': equipment,
      'instructions': instructions,
      'asset_key': assetKey,
    };
  }
}

/// Association between an exercise and a targeted muscle.
class ExerciseMuscleTarget {
  final String exerciseId;
  final String muscleId;
  final String role; // 'PRIMARY', 'SECONDARY'

  const ExerciseMuscleTarget({
    required this.exerciseId,
    required this.muscleId,
    required this.role,
  });

  factory ExerciseMuscleTarget.fromMap(Map<String, dynamic> map) {
    return ExerciseMuscleTarget(
      exerciseId: map['exercise_id'] as String,
      muscleId: map['muscle_id'] as String,
      role: map['role'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'exercise_id': exerciseId,
      'muscle_id': muscleId,
      'role': role,
    };
  }
}
