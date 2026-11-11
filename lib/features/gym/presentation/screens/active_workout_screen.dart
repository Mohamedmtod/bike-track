import 'dart:async';
import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/models/workout_session.dart';
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
  final SessionExercise sessionExercise;
  final Exercise exercise;
  final List<SetLog> sets;
  final SetLog? ghostSet;

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

  // Session duration timer
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;

  // Rest countdown timer
  Timer? _restTimer;
  int _restSecondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _workoutRepo = WorkoutRepository(dbService: _dbService);
    _exerciseRepo = ExerciseRepository(dbService: _dbService);
    _loadSessionData();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSessionData() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      final session = await _workoutRepo.getActiveSession();
      if (session == null || session.id != widget.sessionId) {
        // Fallback: fetch session by ID directly if needed
        final allRecent = await _workoutRepo.getRecentSessions(limit: 10);
        final found = allRecent.where((s) => s.id == widget.sessionId).firstOrNull;
        _session = found ?? session;
      } else {
        _session = session;
      }

      if (_session != null) {
        _elapsed = DateTime.now().difference(_session!.startedAt.toLocal());
        _startDurationTimer();
      }

      final sessionExercises = await _workoutRepo.getSessionExercises(widget.sessionId);
      final allExercises = await _exerciseRepo.getAllExercises();
      final exerciseMap = {for (final e in allExercises) e.id: e};

      // Fetch ghost sets for pre-fill
      final ghostMap = await _exerciseRepo.getLastPerformanceForExercises(
        sessionExercises.map((se) => se.exerciseId).toList(),
      );

      final items = <_ActiveWorkoutExerciseItem>[];
      for (final se in sessionExercises) {
        final ex = exerciseMap[se.exerciseId];
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

  void _startRestTimer({int duration = 90}) {
    HapticFeedback.mediumImpact();
    _restTimer?.cancel();
    setState(() {
      _restSecondsRemaining = duration;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_restSecondsRemaining <= 1) {
        timer.cancel();
        HapticFeedback.heavyImpact();
        if (mounted) {
          setState(() {
            _restSecondsRemaining = 0;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _restSecondsRemaining--;
          });
        }
      }
    });
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

    final newSet = SetLog(
      id: 'set_${item.sessionExercise.id}_$nextSetNum',
      sessionExerciseId: item.sessionExercise.id,
      setNumber: nextSetNum,
      setType: SetType.working,
      weightKg: lastSet?.weightKg,
      reps: lastSet?.reps,
      durationSeconds: lastSet?.durationSeconds,
      side: 'both',
      completed: false,
    );

    await _workoutRepo.saveSetLog(newSet);
    setState(() {
      item.sets.add(newSet);
    });
  }

  Future<void> _toggleSetCompleted(_ActiveWorkoutExerciseItem item, int setIndex) async {
    final current = item.sets[setIndex];
    final updated = current.copyWith(completed: !current.completed);

    HapticFeedback.mediumImpact();
    await _workoutRepo.saveSetLog(updated);

    setState(() {
      item.sets[setIndex] = updated;
    });

    if (updated.completed) {
      _startRestTimer(duration: 90);
    }
  }

  Future<void> _updateSetWeight(_ActiveWorkoutExerciseItem item, int setIndex, double delta) async {
    final current = item.sets[setIndex];
    final currentWeight = current.weightKg ?? item.ghostSet?.weightKg ?? 0.0;
    final newWeight = (currentWeight + delta).clamp(0.0, 500.0);

    final updated = current.copyWith(weightKg: newWeight);
    await _workoutRepo.saveSetLog(updated);

    setState(() {
      item.sets[setIndex] = updated;
    });
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
            onPressed: () {
              _restTimer?.cancel();
              setState(() => _restSecondsRemaining = 0);
            },
            child: const Text('SKIP', style: TextStyle(color: Color(0xFF8E9BAE), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              setState(() => _restSecondsRemaining += 30);
            },
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
          Icon(Icons.fitness_center_rounded, color: Colors.white24, size: 48),
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
          // Header with Exercise Name and Equipment
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
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
                // Remove Exercise
                IconButton(
                  icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF8E9BAE), size: 20),
                  onPressed: () async {
                    await _workoutRepo.cancelSession(item.sessionExercise.id);
                    setState(() {
                      _exerciseItems.remove(item);
                    });
                  },
                ),
              ],
            ),
          ),

          // Sets Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white.withValues(alpha: 0.03),
            child: const Row(
              children: [
                SizedBox(width: 32, child: Text('SET', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold))),
                SizedBox(width: 80, child: Text('PREVIOUS', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(child: Center(child: Text('KG', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
                Expanded(child: Center(child: Text('REPS', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
                SizedBox(width: 44, child: Center(child: Text('DONE', style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 11, fontWeight: FontWeight.bold)))),
              ],
            ),
          ),

          // Sets List
          ...item.sets.asMap().entries.map((entry) {
            final idx = entry.key;
            final setLog = entry.value;
            return _buildSetRow(item, idx, setLog, accentLime);
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
  ) {
    final ghost = item.ghostSet;
    final ghostText = ghost != null && ghost.weightKg != null && ghost.reps != null
        ? '${ghost.weightKg!.toStringAsFixed(ghost.weightKg! % 1 == 0 ? 0 : 1)}k × ${ghost.reps}'
        : '-';

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
          // Set Number
          SizedBox(
            width: 32,
            child: Text(
              '${setIndex + 1}',
              style: TextStyle(
                color: setLog.completed ? accentLime : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),

          // Previous Ghost Text
          SizedBox(
            width: 80,
            child: Text(
              ghostText,
              style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
            ),
          ),

          // Weight KG with Quick Buttons
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: () => _updateSetWeight(item, setIndex, -2.5),
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.remove_circle_outline, color: Color(0xFF8E9BAE), size: 16),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    setLog.weightKg != null
                        ? setLog.weightKg!.toStringAsFixed(setLog.weightKg! % 1 == 0 ? 0 : 1)
                        : (item.ghostSet?.weightKg?.toString() ?? '0'),
                    style: TextStyle(
                      color: setLog.weightKg != null ? Colors.white : Colors.white38,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
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

          // Reps
          Expanded(
            child: Center(
              child: Text(
                setLog.reps?.toString() ?? (item.ghostSet?.reps?.toString() ?? '10'),
                style: TextStyle(
                  color: setLog.reps != null ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),

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
