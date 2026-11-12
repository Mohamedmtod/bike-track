import 'dart:async';
import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/models/workout_session.dart';
import 'package:bike_track/features/gym/services/audio_session_coordinator.dart';
import 'package:bike_track/features/gym/services/gym_live_activity_service.dart';
import 'package:bike_track/features/gym/presentation/widgets/exercise_thumbnail_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final String sessionId;
  final GymDatabaseService? dbService;

  const ActiveWorkoutScreen({
    super.key,
    required this.sessionId,
    this.dbService,
  });

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutExerciseItem {
  SessionExercise sessionExercise;
  Exercise exercise;
  final List<SetLog> sets;
  SetLog? ghostSet;

  _ActiveWorkoutExerciseItem({
    required this.sessionExercise,
    required this.exercise,
    required this.sets,
    this.ghostSet,
  });
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final GymDatabaseService _dbService;
  late final WorkoutRepository _workoutRepo;
  late final ExerciseRepository _exerciseRepo;

  WorkoutSession? _session;
  List<_ActiveWorkoutExerciseItem> _exerciseItems = [];
  bool _isLoading = true;

  // Live session elapsed duration timer
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  // Monotonic rest countdown timer
  Timer? _restTimer;
  DateTime? _restTargetEndTime;
  int _restSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _workoutRepo = WorkoutRepository(dbService: _dbService);
    _exerciseRepo = ExerciseRepository(dbService: _dbService);
    AppAudioSessionCoordinator.instance.initialize();
    _loadSessionData();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _restTimer?.cancel();
    GymLiveActivityService.instance.endRestTimerActivity();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      final session = await _workoutRepo.getActiveSession();
      if (session == null || session.id != widget.sessionId) {
        final allRecent = await _workoutRepo.getRecentSessions(limit: 10);
        final found = allRecent.where((s) => s.id == widget.sessionId).firstOrNull;
        _session = found ?? session;
      } else {
        _session = session;
      }

      if (_session != null) {
        _elapsed = DateTime.now().difference(_session!.startedAt.toLocal());
        _startDurationTimer();

        // Resume rest countdown if active in database
        if (_session!.restEndsAtUtc != null) {
          final diff = _session!.restEndsAtUtc!.difference(DateTime.now().toUtc()).inSeconds;
          if (diff > 0) {
            _startRestTimer(duration: diff, persist: false);
          }
        }
      }

      final sessionExercises = await _workoutRepo.getSessionExercises(widget.sessionId);
      final allExercises = await _exerciseRepo.getAllExercises();
      final exerciseMap = {for (final e in allExercises) e.id: e};

      // Query ghost performances for exercises
      final targetExerciseIds = sessionExercises.map((se) => se.performedExerciseId ?? se.exerciseId).toList();
      final ghostMap = await _exerciseRepo.getLastPerformanceForExercises(targetExerciseIds);

      final items = <_ActiveWorkoutExerciseItem>[];
      for (final se in sessionExercises) {
        final effectiveExId = se.performedExerciseId ?? se.exerciseId;
        final ex = exerciseMap[effectiveExId] ?? exerciseMap[se.exerciseId];
        if (ex != null) {
          final sets = await _workoutRepo.getSetsForSessionExercise(se.id);
          items.add(
            _ActiveWorkoutExerciseItem(
              sessionExercise: se,
              exercise: ex,
              sets: sets,
              ghostSet: ghostMap[ex.id],
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _exerciseItems = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _session != null) {
        setState(() {
          _elapsed = DateTime.now().difference(_session!.startedAt.toLocal());
        });
      }
    });
  }

  void _startRestTimer({
    int duration = 90,
    bool persist = true,
    String? exerciseName,
    int? setNumber,
  }) {
    HapticFeedback.mediumImpact();
    _restTargetEndTime = DateTime.now().add(Duration(seconds: duration));
    _restTimer?.cancel();

    if (persist) {
      _workoutRepo.updateRestEndsAt(
        widget.sessionId,
        _restTargetEndTime,
        durationSeconds: duration,
      );
    }

    GymLiveActivityService.instance.startRestTimerActivity(
      restDurationSeconds: duration,
      endsAtUtc: _restTargetEndTime!,
      exerciseName: exerciseName,
      setNumber: setNumber,
    );

    setState(() {
      _restSecondsRemaining = duration;
    });

    _restTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_restTargetEndTime == null) {
        timer.cancel();
        return;
      }
      final remaining = _restTargetEndTime!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        AppAudioSessionCoordinator.instance.playRestCompleteSound();
        GymLiveActivityService.instance.endRestTimerActivity();
        _workoutRepo.updateRestEndsAt(widget.sessionId, null);
        if (mounted) {
          setState(() {
            _restSecondsRemaining = 0;
            _restTargetEndTime = null;
          });
        }
      } else {
        if (mounted && remaining != _restSecondsRemaining) {
          setState(() {
            _restSecondsRemaining = remaining;
          });
        }
      }
    });
  }

  void _addRestTime(int seconds) {
    if (_restTargetEndTime != null) {
      _restTargetEndTime = _restTargetEndTime!.add(Duration(seconds: seconds));
      _workoutRepo.updateRestEndsAt(
        widget.sessionId,
        _restTargetEndTime,
        durationSeconds: _restSecondsRemaining + seconds,
      );
      GymLiveActivityService.instance.startRestTimerActivity(
        restDurationSeconds: _restSecondsRemaining + seconds,
        endsAtUtc: _restTargetEndTime!,
      );
      setState(() {
        _restSecondsRemaining = _restTargetEndTime!.difference(DateTime.now()).inSeconds;
      });
    }
  }

  void _skipRestTimer() {
    _restTimer?.cancel();
    _restTargetEndTime = null;
    GymLiveActivityService.instance.endRestTimerActivity();
    _workoutRepo.updateRestEndsAt(widget.sessionId, null);
    setState(() => _restSecondsRemaining = 0);
  }

  Future<void> _addExerciseToWorkout(Exercise exercise) async {
    HapticFeedback.lightImpact();
    final se = await _workoutRepo.addExerciseToSession(widget.sessionId, exercise.id);
    final ghost = (await _exerciseRepo.getLastPerformanceForExercises([exercise.id]))[exercise.id];

    final newItem = _ActiveWorkoutExerciseItem(
      sessionExercise: se,
      exercise: exercise,
      sets: [],
      ghostSet: ghost,
    );

    setState(() {
      _exerciseItems.add(newItem);
    });

    // Automatically add first set for quick entry
    await _addSetToExercise(newItem);
  }

  Future<void> _addSetToExercise(_ActiveWorkoutExerciseItem item) async {
    HapticFeedback.lightImpact();
    final nextSetNum = item.sets.length + 1;
    final lastSet = item.sets.isNotEmpty ? item.sets.last : item.ghostSet;

    final defaultSide = item.exercise.laterality == 'unilateral' ? 'left' : 'both';

    final newSet = SetLog(
      id: 'set_${item.sessionExercise.id}_$nextSetNum',
      sessionExerciseId: item.sessionExercise.id,
      setNumber: nextSetNum,
      setType: SetType.working,
      weightKg: lastSet?.weightKg,
      reps: lastSet?.reps,
      durationSeconds: lastSet?.durationSeconds ?? (item.exercise.loggingType == ExerciseLoggingType.durationOnly ? 45 : null),
      side: defaultSide,
      completed: false,
    );

    await _workoutRepo.saveSetLog(newSet);
    setState(() {
      item.sets.add(newSet);
    });
  }

  Future<void> _cycleSetType(_ActiveWorkoutExerciseItem item, int setIndex) async {
    HapticFeedback.selectionClick();
    final current = item.sets[setIndex];
    SetType nextType;
    switch (current.setType) {
      case SetType.working:
        nextType = SetType.warmup;
        break;
      case SetType.warmup:
        nextType = SetType.drop;
        break;
      case SetType.drop:
        nextType = SetType.working;
        break;
    }

    final updated = current.copyWith(setType: nextType);
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _cycleSide(_ActiveWorkoutExerciseItem item, int setIndex) async {
    HapticFeedback.selectionClick();
    final current = item.sets[setIndex];
    String nextSide;
    switch (current.side.toLowerCase()) {
      case 'left':
        nextSide = 'right';
        break;
      case 'right':
        nextSide = 'both';
        break;
      default:
        nextSide = 'left';
        break;
    }

    final updated = current.copyWith(side: nextSide);
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _applyGhostValues(_ActiveWorkoutExerciseItem item, int setIndex) async {
    final ghost = item.ghostSet ?? (setIndex > 0 ? item.sets[setIndex - 1] : null);
    if (ghost == null) return;

    HapticFeedback.mediumImpact();
    final current = item.sets[setIndex];
    final updated = current.copyWith(
      weightKg: ghost.weightKg,
      reps: ghost.reps,
      durationSeconds: ghost.durationSeconds,
    );

    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _toggleSetCompleted(_ActiveWorkoutExerciseItem item, int setIndex) async {
    final current = item.sets[setIndex];
    final updated = current.copyWith(completed: !current.completed);

    HapticFeedback.mediumImpact();
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);

    if (updated.completed) {
      _startRestTimer(
        duration: 90,
        exerciseName: item.exercise.name,
        setNumber: setIndex + 1,
      );
    }
  }

  Future<void> _updateSetWeight(_ActiveWorkoutExerciseItem item, int setIndex, double delta) async {
    final current = item.sets[setIndex];
    final currentWeight = current.weightKg ?? item.ghostSet?.weightKg ?? 0.0;
    final newWeight = (currentWeight + delta).clamp(0.0, 500.0);

    final updated = current.copyWith(weightKg: newWeight);
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _updateSetReps(_ActiveWorkoutExerciseItem item, int setIndex, int delta) async {
    final current = item.sets[setIndex];
    final currentReps = current.reps ?? item.ghostSet?.reps ?? 10;
    final newReps = (currentReps + delta).clamp(1, 100);

    final updated = current.copyWith(reps: newReps);
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _updateSetDuration(_ActiveWorkoutExerciseItem item, int setIndex, int deltaSeconds) async {
    final current = item.sets[setIndex];
    final currentDuration = current.durationSeconds ?? item.ghostSet?.durationSeconds ?? 45;
    final newDuration = (currentDuration + deltaSeconds).clamp(5, 600);

    final updated = current.copyWith(durationSeconds: newDuration);
    setState(() {
      item.sets[setIndex] = updated;
    });
    await _workoutRepo.saveSetLog(updated);
  }

  Future<void> _showQuickWeightDialog(_ActiveWorkoutExerciseItem item, int setIndex) async {
    final current = item.sets[setIndex];
    double val = current.weightKg ?? item.ghostSet?.weightKg ?? 60.0;
    final textController = TextEditingController(text: val.toStringAsFixed(val % 1 == 0 ? 0 : 1));

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14161F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set Weight (${item.exercise.name})',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 120,
                        child: TextField(
                          controller: textController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFCCFF00), fontSize: 28, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(
                            suffixText: 'kg',
                            suffixStyle: TextStyle(color: Color(0xFF8E9BAE), fontSize: 16),
                            border: InputBorder.none,
                          ),
                          onChanged: (text) {
                            final parsed = double.tryParse(text);
                            if (parsed != null) val = parsed;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Quick adjustment chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [-10.0, -5.0, -2.5, 2.5, 5.0, 10.0].map((step) {
                      final isPos = step > 0;
                      return ActionChip(
                        backgroundColor: const Color(0xFF1F2232),
                        side: BorderSide(color: isPos ? const Color(0xFFCCFF00).withValues(alpha: 0.4) : Colors.white12),
                        label: Text(
                          isPos ? '+$step kg' : '$step kg',
                          style: TextStyle(
                            color: isPos ? const Color(0xFFCCFF00) : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        onPressed: () {
                          val = (val + step).clamp(0.0, 500.0);
                          textController.text = val.toStringAsFixed(val % 1 == 0 ? 0 : 1);
                          setSheetState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCCFF00),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final parsed = double.tryParse(textController.text) ?? val;
                        final updated = current.copyWith(weightKg: parsed);
                        _workoutRepo.saveSetLog(updated);
                        setState(() {
                          item.sets[setIndex] = updated;
                        });
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Confirm Weight', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _swapExercise(_ActiveWorkoutExerciseItem item) async {
    final alternatives = await _exerciseRepo.getAlternativeExercises(item.exercise.id);
    if (!mounted) return;

    if (alternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No alternative exercises found targeting the same primary muscle.'),
          backgroundColor: Color(0xFF14161F),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<Exercise>(
      context: context,
      backgroundColor: const Color(0xFF14161F),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Swap "${item.exercise.name}" with:',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: alternatives.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white10),
                  itemBuilder: (ctx, i) {
                    final alt = alternatives[i];
                    return ListTile(
                      key: Key('swap_item_${alt.id}'),
                      leading: ExerciseThumbnailWidget(exercise: alt, size: 40),
                      title: Text(alt.name, style: const TextStyle(color: Colors.white)),
                      subtitle: Text('${alt.equipment} • ${alt.laterality}', style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12)),
                      trailing: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF00E5FF)),
                      onTap: () => Navigator.of(ctx).pop(alt),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        item.exercise = selected;
        item.sessionExercise = SessionExercise(
          id: item.sessionExercise.id,
          sessionId: item.sessionExercise.sessionId,
          exerciseId: item.sessionExercise.exerciseId,
          performedExerciseId: selected.id,
          sortOrder: item.sessionExercise.sortOrder,
        );
      });
      await _workoutRepo.swapExerciseInSession(item.sessionExercise.id, selected.id);
      final ghost = (await _exerciseRepo.getLastPerformanceForExercises([selected.id]))[selected.id];
      if (!mounted) return;
      setState(() {
        item.ghostSet = ghost;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Swapped to ${selected.name}! 🔄'),
          backgroundColor: const Color(0xFF14161F),
        ),
      );
    }
  }

  Future<void> _removeExercise(_ActiveWorkoutExerciseItem item) async {
    setState(() {
      _exerciseItems.remove(item);
    });
    await _workoutRepo.removeExerciseFromSession(item.sessionExercise.id);
  }

  Future<void> _finishWorkout() async {
    HapticFeedback.heavyImpact();
    await _workoutRepo.endSession(widget.sessionId);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Workout completed and saved! Great job! 💪'),
          backgroundColor: Color(0xFF14161F),
        ),
      );
    }
  }

  Future<void> _discardWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14161F),
        title: const Text('Discard Workout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to discard this workout? Recorded sets will be removed.',
          style: TextStyle(color: Color(0xFF8E9BAE)),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF8E9BAE))),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Discard', style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _workoutRepo.cancelSession(widget.sessionId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _showExercisePicker() async {
    final allExercises = await _exerciseRepo.getAllExercises();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14161F),
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return _ExercisePickerSheet(
          exercises: allExercises,
          onExerciseSelected: (ex) {
            Navigator.of(ctx).pop();
            _addExerciseToWorkout(ex);
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF090A0F);
    const cardDark = Color(0xFF14161F);
    const accentLime = Color(0xFFCCFF00);
    const accentCyan = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Active Workout',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Text(
              'Elapsed: ${_formatDuration(_elapsed)}',
              style: const TextStyle(color: accentLime, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            key: const Key('discard_workout_button'),
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFF8E9BAE)),
            tooltip: 'Discard',
            onPressed: _discardWorkout,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: ElevatedButton(
              key: const Key('finish_workout_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentLime,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: _finishWorkout,
              child: const Text('FINISH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentLime))
          : Column(
              children: [
                // Rest Countdown Banner (if active)
                if (_restSecondsRemaining > 0)
                  _buildRestBanner(cardDark, accentCyan),

                // Main Exercise List
                Expanded(
                  child: _exerciseItems.isEmpty
                      ? _buildEmptyState(accentLime)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _exerciseItems.length,
                          itemBuilder: (context, index) {
                            return _buildExerciseSection(
                              _exerciseItems[index],
                              cardDark,
                              accentLime,
                            );
                          },
                        ),
                ),

                // Bottom Add Exercise Bar
                _buildBottomBar(cardDark, accentLime),
              ],
            ),
    );
  }

  Widget _buildRestBanner(Color cardDark, Color accentCyan) {
    return Container(
      key: const Key('rest_timer_banner'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardDark,
        border: Border(bottom: BorderSide(color: accentCyan.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, color: accentCyan, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'REST: ${_restSecondsRemaining}s',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _skipRestTimer,
            child: const Text('SKIP', style: TextStyle(color: Color(0xFF8E9BAE), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _addRestTime(30),
            child: Text('+30s', style: TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color accentLime) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 48),
          const SizedBox(height: 16),
          const Text(
            'No exercises in this workout yet.',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap "+ Add Exercise" below to pick your first exercise!',
            style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            key: const Key('empty_add_exercise_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentLime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add Exercise (إضافة تمرينة)', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _showExercisePicker,
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseSection(
    _ActiveWorkoutExerciseItem item,
    Color cardDark,
    Color accentLime,
  ) {
    final isDurationOnly = item.exercise.loggingType == ExerciseLoggingType.durationOnly;

    return Container(
      key: Key('workout_exercise_${item.exercise.id}'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Exercise Name, Equipment, and Movement Thumbnail
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ExerciseThumbnailWidget(
                  exercise: item.exercise,
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.exercise.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.exercise.equipment.toUpperCase()} • ${item.exercise.laterality.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
                // Options menu (Swap & Remove)
                PopupMenuButton<String>(
                  key: Key('exercise_menu_${item.exercise.id}'),
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF8E9BAE), size: 20),
                  color: const Color(0xFF1A1C29),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onSelected: (val) {
                    if (val == 'swap') {
                      _swapExercise(item);
                    } else if (val == 'remove') {
                      _removeExercise(item);
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'swap',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, color: Color(0xFF00E5FF), size: 18),
                            SizedBox(width: 8),
                            Text('Swap Exercise (استبدال)', style: TextStyle(color: Colors.white, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                            SizedBox(width: 8),
                            Text('Remove Exercise (حذف)', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sets Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withValues(alpha: 0.03),
            child: Row(
              children: [
                const SizedBox(width: 44, child: Text('SET', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 74, child: Text('PREVIOUS', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold))),
                if (isDurationOnly) ...[
                  const Expanded(child: Center(child: Text('TIME', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
                ] else ...[
                  const Expanded(child: Center(child: Text('KG', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
                  const Expanded(child: Center(child: Text('REPS', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
                ],
                const SizedBox(width: 44, child: Center(child: Text('DONE', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),

          // Sets List
          ...item.sets.asMap().entries.map((entry) {
            final idx = entry.key;
            final setLog = entry.value;
            return _buildSetRow(item, idx, setLog, accentLime, isDurationOnly);
          }),

          // Add Set Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: Key('add_set_${item.exercise.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentLime,
                      side: BorderSide(color: accentLime.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('+ Add Set', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => _addSetToExercise(item),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(
    _ActiveWorkoutExerciseItem item,
    int setIndex,
    SetLog setLog,
    Color accentLime,
    bool isDurationOnly,
  ) {
    final ghost = item.ghostSet;
    final ghostText = ghost != null && ghost.weightKg != null && ghost.reps != null
        ? '${ghost.weightKg!.toStringAsFixed(ghost.weightKg! % 1 == 0 ? 0 : 1)}k × ${ghost.reps}'
        : (ghost?.durationSeconds != null ? '${ghost!.durationSeconds}s' : '-');

    final isUnilateral = item.exercise.laterality.toLowerCase() == 'unilateral';

    return Container(
      key: Key('set_row_${setLog.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: setLog.completed
            ? accentLime.withValues(alpha: 0.08)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.04))),
      ),
      child: Row(
        children: [
          // Set Type Badge (Working, Warmup, Drop) + Side Badge (if unilateral)
          SizedBox(
            width: 44,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSetTypeBadge(item, setIndex, setLog),
                if (isUnilateral) _buildSideBadge(item, setIndex, setLog),
              ],
            ),
          ),

          // Previous Ghost Text with Quick-Fill Tap
          SizedBox(
            width: 74,
            child: InkWell(
              key: Key('ghost_prefill_${setLog.id}'),
              onTap: () => _applyGhostValues(item, setIndex),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      ghostText,
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (ghost != null && !setLog.completed) ...[
                    const SizedBox(width: 2),
                    const Icon(Icons.copy_rounded, color: Color(0xFF8E9BAE), size: 10),
                  ],
                ],
              ),
            ),
          ),

          if (isDurationOnly) ...[
            // Duration column for timed exercises (Plank, etc.)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      key: Key('decrement_duration_${setLog.id}'),
                      onTap: () => _updateSetDuration(item, setIndex, -5),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.remove_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${setLog.durationSeconds ?? item.ghostSet?.durationSeconds ?? 45}s',
                      style: TextStyle(
                        color: setLog.durationSeconds != null ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      key: Key('increment_duration_${setLog.id}'),
                      onTap: () => _updateSetDuration(item, setIndex, 5),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.add_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Weight KG with Quick Increment Buttons and Modal dialog tap
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      key: Key('decrement_weight_${setLog.id}'),
                      onTap: () => _updateSetWeight(item, setIndex, -2.5),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.remove_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      key: Key('edit_weight_${setLog.id}'),
                      onTap: () => _showQuickWeightDialog(item, setIndex),
                      child: Text(
                        setLog.weightKg != null
                            ? setLog.weightKg!.toStringAsFixed(setLog.weightKg! % 1 == 0 ? 0 : 1)
                            : (item.ghostSet?.weightKg?.toString() ?? '0'),
                        style: TextStyle(
                          color: setLog.weightKg != null ? Colors.white : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      key: Key('increment_weight_${setLog.id}'),
                      onTap: () => _updateSetWeight(item, setIndex, 2.5),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.add_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Reps column with Stepper
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      key: Key('decrement_reps_${setLog.id}'),
                      onTap: () => _updateSetReps(item, setIndex, -1),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.remove_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      setLog.reps?.toString() ?? (item.ghostSet?.reps?.toString() ?? '10'),
                      style: TextStyle(
                        color: setLog.reps != null ? Colors.white : Colors.white38,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      key: Key('increment_reps_${setLog.id}'),
                      onTap: () => _updateSetReps(item, setIndex, 1),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.add_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Checkmark (Complete Set)
          SizedBox(
            width: 44,
            child: IconButton(
              key: Key('complete_set_${setLog.id}'),
              icon: Icon(
                setLog.completed ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                color: setLog.completed ? accentLime : const Color(0xFF8E9BAE),
                size: 24,
              ),
              onPressed: () => _toggleSetCompleted(item, setIndex),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetTypeBadge(_ActiveWorkoutExerciseItem item, int setIndex, SetLog setLog) {
    Color color;
    String label;
    switch (setLog.setType) {
      case SetType.warmup:
        color = const Color(0xFFFFB300); // Amber
        label = 'W';
        break;
      case SetType.drop:
        color = const Color(0xFFBA68C8); // Purple
        label = 'D';
        break;
      case SetType.working:
        color = setLog.completed ? const Color(0xFFCCFF00) : Colors.white;
        label = '${setIndex + 1}';
        break;
    }

    return InkWell(
      key: Key('set_type_${setLog.id}'),
      onTap: () => _cycleSetType(item, setIndex),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildSideBadge(_ActiveWorkoutExerciseItem item, int setIndex, SetLog setLog) {
    String label;
    Color color;
    switch (setLog.side.toLowerCase()) {
      case 'left':
        label = 'L';
        color = const Color(0xFF00E5FF);
        break;
      case 'right':
        label = 'R';
        color = const Color(0xFFFF4081);
        break;
      default:
        label = 'B';
        color = const Color(0xFF8E9BAE);
        break;
    }

    return InkWell(
      key: Key('set_side_${setLog.id}'),
      onTap: () => _cycleSide(item, setIndex),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(left: 3),
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 9),
        ),
      ),
    );
  }

  Widget _buildBottomBar(Color cardDark, Color accentLime) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardDark,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            key: const Key('add_exercise_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentLime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Add Exercise (إضافة تمرينة)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: _showExercisePicker,
          ),
        ),
      ),
    );
  }
}

class _ExercisePickerSheet extends StatefulWidget {
  final List<Exercise> exercises;
  final ValueChanged<Exercise> onExerciseSelected;

  const _ExercisePickerSheet({
    required this.exercises,
    required this.onExerciseSelected,
  });

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.exercises.where((e) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return e.name.toLowerCase().contains(q) || e.equipment.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search exercise...',
              hintStyle: const TextStyle(color: Color(0xFF8E9BAE)),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF8E9BAE)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final ex = filtered[index];
                return ListTile(
                  key: Key('picker_item_${ex.id}'),
                  leading: ExerciseThumbnailWidget(exercise: ex, size: 40),
                  title: Text(ex.name, style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${ex.equipment} • ${ex.laterality}',
                    style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                  ),
                  trailing: const Icon(Icons.add_circle_outline, color: Color(0xFFCCFF00)),
                  onTap: () => widget.onExerciseSelected(ex),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
