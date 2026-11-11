import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/presentation/screens/exercise_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MuscleDetailScreen extends StatefulWidget {
  final String muscleId;
  final GymDatabaseService? dbService;

  const MuscleDetailScreen({
    super.key,
    required this.muscleId,
    this.dbService,
  });

  @override
  State<MuscleDetailScreen> createState() => _MuscleDetailScreenState();
}

class _MuscleDetailScreenState extends State<MuscleDetailScreen> {
  late final GymDatabaseService _dbService;
  late final MuscleRepository _muscleRepo;
  late final ExerciseRepository _exerciseRepo;
  late final WorkoutRepository _workoutRepo;

  bool _isLoading = true;
  Muscle? _muscle;
  List<Exercise> _exercises = [];
  Map<String, SetLog> _lastPerformance = {};

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _muscleRepo = MuscleRepository(dbService: _dbService);
    _exerciseRepo = ExerciseRepository(dbService: _dbService);
    _workoutRepo = WorkoutRepository(dbService: _dbService);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      final muscle = await _muscleRepo.getMuscleById(widget.muscleId);
      final exercises = await _exerciseRepo.getExercisesForMuscle(widget.muscleId);
      final perfMap = await _exerciseRepo.getLastPerformanceForExercises(
        exercises.map((e) => e.id).toList(),
      );

      if (mounted) {
        setState(() {
          _muscle = muscle;
          _exercises = exercises;
          _lastPerformance = perfMap;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addExerciseToWorkout(Exercise exercise) async {
    try {
      var activeSession = await _workoutRepo.getActiveSession();
      activeSession ??= await _workoutRepo.startSession();

      await _workoutRepo.addExerciseToSession(activeSession.id, exercise.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${exercise.name}" to active workout!'),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF14161F),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add exercise: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF090A0F);
    const cardDark = Color(0xFF14161F);
    const accentLime = Color(0xFFCCFF00);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          _muscle?.name ?? widget.muscleId,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentLime))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Muscle Overview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center, color: accentLime),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _muscle?.name ?? widget.muscleId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Region: ${_muscle?.anatomyRegion ?? "Target Area"} • ${_exercises.length} Exercises',
                              style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TARGETED EXERCISES',
                  style: TextStyle(
                    color: Color(0xFF8E9BAE),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (_exercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'No exercises found for this muscle group.',
                        style: TextStyle(color: Color(0xFF8E9BAE)),
                      ),
                    ),
                  )
                else
                  ..._exercises.map(
                    (ex) => _buildExerciseCard(
                      ex,
                      _lastPerformance[ex.id],
                      cardDark,
                      accentLime,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildExerciseCard(
    Exercise exercise,
    SetLog? lastSet,
    Color cardDark,
    Color accentLime,
  ) {
    return Container(
      key: Key('exercise_card_${exercise.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sports_gymnastics, color: Color(0xFF8E9BAE)),
          ),
          title: Text(
            exercise.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildPill(exercise.equipment, Colors.white.withValues(alpha: 0.08), Colors.white70),
                _buildPill(exercise.laterality, Colors.white.withValues(alpha: 0.08), Colors.white70),
                if (lastSet != null)
                  _buildPerformancePill(lastSet, accentLime)
                else
                  _buildPill('New (جديد)', Colors.white.withValues(alpha: 0.05), const Color(0xFF8E9BAE)),
              ],
            ),
          ),
          trailing: IconButton(
            key: Key('exercise_analytics_btn_${exercise.id}'),
            icon: const Icon(Icons.insights_rounded, color: Color(0xFF00E5FF), size: 20),
            tooltip: 'View Analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExerciseAnalyticsScreen(
                    exerciseId: exercise.id,
                    dbService: _dbService,
                  ),
                ),
              );
            },
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            _showExerciseDetailsSheet(exercise, lastSet, cardDark, accentLime);
          },
        ),
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildPerformancePill(SetLog set, Color accentLime) {
    String text;
    if (set.weightKg != null && set.reps != null) {
      final w = set.weightKg!;
      final wStr = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
      text = 'Last: $wStr kg × ${set.reps}';
    } else if (set.reps != null) {
      text = 'Last: ${set.reps} reps';
    } else if (set.durationSeconds != null) {
      text = 'Last: ${set.durationSeconds}s';
    } else {
      text = 'Logged';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentLime.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentLime.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: accentLime, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showExerciseDetailsSheet(
    Exercise exercise,
    SetLog? lastSet,
    Color cardDark,
    Color accentLime,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cardDark,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  exercise.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildPill(exercise.equipment, Colors.white.withValues(alpha: 0.1), Colors.white70),
                    _buildPill(exercise.laterality, Colors.white.withValues(alpha: 0.1), Colors.white70),
                    _buildPill(exercise.loggingType.name, Colors.white.withValues(alpha: 0.1), Colors.white70),
                  ],
                ),
                const SizedBox(height: 16),
                // Instructions / Technique Notes
                const Text(
                  'INSTRUCTIONS & FORM',
                  style: TextStyle(
                    color: Color(0xFF8E9BAE),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (exercise.instructions != null && exercise.instructions!.isNotEmpty)
                      ? exercise.instructions!
                      : 'Maintain strict posture, controlled eccentric tempo, and full range of motion.',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                // Last Performance Block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: accentLime, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lastSet != null
                              ? 'Last Performance: ${lastSet.weightKg != null ? "${lastSet.weightKg} kg" : ""} ${lastSet.reps != null ? "× ${lastSet.reps} reps" : ""}'
                              : 'No prior workouts recorded for this exercise yet.',
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // View Analytics & PRs Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    key: Key('view_exercise_analytics_${exercise.id}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00E5FF),
                      side: BorderSide(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    label: const Text(
                      'View Progression & PRs (التحليلات والأرقام)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseAnalyticsScreen(
                            exerciseId: exercise.id,
                            dbService: _dbService,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                // Add to Workout Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    key: const Key('add_exercise_to_workout_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentLime,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: const Text(
                      'Add to Workout (إضافة للتمرين)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addExerciseToWorkout(exercise);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
