class WorkoutSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String status; // 'IN_PROGRESS', 'DONE', 'CANCELLED'
  final DateTime? restEndsAtUtc;
  final int? restDurationSeconds;
  final String? notes;

  const WorkoutSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    required this.status,
    this.restEndsAtUtc,
    this.restDurationSeconds,
    this.notes,
  });

  bool get isInProgress => status == 'IN_PROGRESS';

  Duration get duration {
    final end = endedAt ?? DateTime.now().toUtc();
    return end.difference(startedAt);
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map) {
    return WorkoutSession(
      id: map['id'] as String,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at'] as String) : null,
      status: map['status'] as String,
      restEndsAtUtc: map['rest_ends_at_utc'] != null
          ? DateTime.parse(map['rest_ends_at_utc'] as String)
          : null,
      restDurationSeconds: map['rest_duration_seconds'] as int?,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'status': status,
      'rest_ends_at_utc': restEndsAtUtc?.toUtc().toIso8601String(),
      'rest_duration_seconds': restDurationSeconds,
      'notes': notes,
    };
  }
}

class SessionExercise {
  final String id;
  final String sessionId;
  final String exerciseId;
  final String? performedExerciseId;
  final String? supersetGroupId;
  final String? notes;
  final int sortOrder;

  const SessionExercise({
    required this.id,
    required this.sessionId,
    required this.exerciseId,
    this.performedExerciseId,
    this.supersetGroupId,
    this.notes,
    required this.sortOrder,
  });

  factory SessionExercise.fromMap(Map<String, dynamic> map) {
    return SessionExercise(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      exerciseId: map['exercise_id'] as String,
      performedExerciseId: map['performed_exercise_id'] as String?,
      supersetGroupId: map['superset_group_id'] as String?,
      notes: map['notes'] as String?,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'exercise_id': exerciseId,
      'performed_exercise_id': performedExerciseId,
      'superset_group_id': supersetGroupId,
      'notes': notes,
      'sort_order': sortOrder,
    };
  }
}

