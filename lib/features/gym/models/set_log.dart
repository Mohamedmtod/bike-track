enum SetType {
  warmup,
  working,
  drop;

  static SetType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'WARMUP':
        return SetType.warmup;
      case 'DROP':
        return SetType.drop;
      case 'WORKING':
      default:
        return SetType.working;
    }
  }

  String toDbString() {
    switch (this) {
      case SetType.warmup:
        return 'WARMUP';
      case SetType.drop:
        return 'DROP';
      case SetType.working:
        return 'WORKING';
    }
  }
}

class SetLog {
  final String id;
  final String sessionExerciseId;
  final int setNumber;
  final String? logicalSetId;
  final SetType setType;
  final bool failureStatus;
  final double? weightKg;
  final int? reps;
  final int? durationSeconds;
  final String side; // 'both', 'left', 'right'
  final int? restTakenSeconds;
  final bool completed;

  const SetLog({
    required this.id,
    required this.sessionExerciseId,
    required this.setNumber,
    this.logicalSetId,
    required this.setType,
    this.failureStatus = false,
    this.weightKg,
    this.reps,
    this.durationSeconds,
    this.side = 'both',
    this.restTakenSeconds,
    this.completed = false,
  });

  factory SetLog.fromMap(Map<String, dynamic> map) {
    return SetLog(
      id: map['id'] as String,
      sessionExerciseId: map['session_exercise_id'] as String,
      setNumber: map['set_number'] as int,
      logicalSetId: map['logical_set_id'] as String?,
      setType: SetType.fromString(map['set_type'] as String),
      failureStatus: (map['failure_status'] as int?) == 1,
      weightKg: (map['weight_kg'] as num?)?.toDouble(),
      reps: map['reps'] as int?,
      durationSeconds: map['duration_seconds'] as int?,
      side: (map['side'] as String?) ?? 'both',
      restTakenSeconds: map['rest_taken_seconds'] as int?,
      completed: (map['completed'] as int?) == 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_exercise_id': sessionExerciseId,
      'set_number': setNumber,
      'logical_set_id': logicalSetId,
      'set_type': setType.toDbString(),
      'failure_status': failureStatus ? 1 : 0,
      'weight_kg': weightKg,
      'reps': reps,
      'duration_seconds': durationSeconds,
      'side': side,
      'rest_taken_seconds': restTakenSeconds,
      'completed': completed ? 1 : 0,
    };
  }

  SetLog copyWith({
    String? id,
    String? sessionExerciseId,
    int? setNumber,
    String? logicalSetId,
    SetType? setType,
    bool? failureStatus,
    double? weightKg,
    int? reps,
    int? durationSeconds,
    String? side,
    int? restTakenSeconds,
    bool? completed,
  }) {
    return SetLog(
      id: id ?? this.id,
      sessionExerciseId: sessionExerciseId ?? this.sessionExerciseId,
      setNumber: setNumber ?? this.setNumber,
      logicalSetId: logicalSetId ?? this.logicalSetId,
      setType: setType ?? this.setType,
      failureStatus: failureStatus ?? this.failureStatus,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      side: side ?? this.side,
      restTakenSeconds: restTakenSeconds ?? this.restTakenSeconds,
      completed: completed ?? this.completed,
    );
  }
}

