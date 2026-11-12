import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/presentation/screens/exercise_analytics_screen.dart';
import 'package:bike_track/features/gym/presentation/widgets/exercise_thumbnail_widget.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MuscleDetailScreen extends StatefulWidget {
  final String muscleId;
  final GymDatabaseService? dbService;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const MuscleDetailScreen({
    super.key,
    required this.muscleId,
    this.dbService,
    this.themeController,
    this.localeController,
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

  Future<void> _addExerciseToWorkout(Exercise exercise, AppThemeTokens theme, bool isArabic) async {
    try {
      var activeSession = await _workoutRepo.getActiveSession();
      activeSession ??= await _workoutRepo.startSession();

      await _workoutRepo.addExerciseToSession(activeSession.id, exercise.id);

      if (mounted) {
        final message = isArabic
            ? 'تمت إضافة "${exercise.name}" إلى التمرين الحالي!'
            : 'Added "${exercise.name}" to active workout!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message, style: TextStyle(color: theme.textPrimary)),
            duration: const Duration(seconds: 2),
            backgroundColor: theme.surface,
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
    final Listenable? notifier = widget.themeController != null && widget.localeController != null
        ? Listenable.merge([widget.themeController!, widget.localeController!])
        : (widget.themeController ?? widget.localeController);

    if (notifier != null) {
      return ListenableBuilder(
        listenable: notifier,
        builder: (context, _) => _buildScaffold(context),
      );
    }
    return _buildScaffold(context);
  }

  Widget _buildScaffold(BuildContext context) {
    final isArabic = widget.localeController?.isArabic ??
        (Localizations.maybeLocaleOf(context)?.languageCode == 'ar');
    final strings = widget.localeController?.strings ?? AppStrings.fromIsArabic(isArabic);
    final theme = widget.themeController?.tokens ?? AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        title: Text(
          _muscle != null ? strings.muscleName(_muscle!.id) : widget.muscleId,
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold),
        ),
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Muscle Overview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.fitness_center, color: theme.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _muscle != null ? strings.muscleName(_muscle!.id) : widget.muscleId,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'المنطقة: ${_muscle?.anatomyRegion ?? "مستهدفة"} • ${_exercises.length} تمارين'
                                  : 'Region: ${_muscle?.anatomyRegion ?? "Target Area"} • ${_exercises.length} Exercises',
                              style: TextStyle(color: theme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? 'التمارين المستهدفة' : 'TARGETED EXERCISES',
                  style: TextStyle(
                    color: theme.textSecondary,
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
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        isArabic
                            ? 'لا توجد تمارين مسجلة لهذه المجموعة العضلية.'
                            : 'No exercises found for this muscle group.',
                        style: TextStyle(color: theme.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._exercises.map(
                    (ex) => _buildExerciseCard(
                      ex,
                      _lastPerformance[ex.id],
                      theme,
                      isArabic,
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildExerciseCard(
    Exercise exercise,
    SetLog? lastSet,
    AppThemeTokens theme,
    bool isArabic,
  ) {
    return Container(
      key: Key('exercise_card_${exercise.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: ExerciseThumbnailWidget(
            exercise: exercise,
            size: 46,
            primaryMuscleGroup: widget.muscleId,
          ),
          title: Text(
            exercise.name,
            style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildPill(exercise.equipment, theme.surfaceContainer, theme.textSecondary),
                _buildPill(exercise.laterality, theme.surfaceContainer, theme.textSecondary),
                if (lastSet != null)
                  _buildPerformancePill(lastSet, theme.primary, isArabic)
                else
                  _buildPill(isArabic ? 'جديد' : 'New', theme.surfaceContainer, theme.textSecondary),
              ],
            ),
          ),
          trailing: IconButton(
            key: Key('exercise_analytics_btn_${exercise.id}'),
            icon: Icon(Icons.insights_rounded, color: theme.tertiary, size: 20),
            tooltip: isArabic ? 'عرض التحليلات' : 'View Analytics',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExerciseAnalyticsScreen(
                    exerciseId: exercise.id,
                    dbService: _dbService,
                    themeController: widget.themeController,
                    localeController: widget.localeController,
                  ),
                ),
              );
            },
          ),
          onTap: () {
            HapticFeedback.lightImpact();
            _showExerciseDetailsSheet(exercise, lastSet, theme, isArabic);
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

  Widget _buildPerformancePill(SetLog set, Color accentColor, bool isArabic) {
    String text;
    final prefix = isArabic ? 'آخر أداء: ' : 'Last: ';
    if (set.weightKg != null && set.reps != null) {
      final w = set.weightKg!;
      final wStr = w % 1 == 0 ? w.toInt().toString() : w.toStringAsFixed(1);
      text = '$prefix$wStr kg × ${set.reps}';
    } else if (set.reps != null) {
      text = '$prefix${set.reps} reps';
    } else if (set.durationSeconds != null) {
      text = '$prefix${set.durationSeconds}s';
    } else {
      text = isArabic ? 'مسجل' : 'Logged';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: accentColor, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showExerciseDetailsSheet(
    Exercise exercise,
    SetLog? lastSet,
    AppThemeTokens theme,
    bool isArabic,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
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
                      color: theme.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ExerciseThumbnailWidget(
                      exercise: exercise,
                      size: 54,
                      primaryMuscleGroup: widget.muscleId,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            exercise.name,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _buildPill(exercise.equipment, theme.surfaceContainer, theme.textSecondary),
                              _buildPill(exercise.laterality, theme.surfaceContainer, theme.textSecondary),
                              _buildPill(exercise.loggingType.name, theme.surfaceContainer, theme.textSecondary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Instructions / Technique Notes
                Text(
                  isArabic ? 'تعليمات الأداء' : 'INSTRUCTIONS & FORM',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (exercise.instructions != null && exercise.instructions!.isNotEmpty)
                      ? exercise.instructions!
                      : (isArabic
                          ? 'حافظ على استقامة العمود الفقري والتحكم الكامل في وتيرة النزول ومدى الحركة.'
                          : 'Maintain strict posture, controlled eccentric tempo, and full range of motion.'),
                  style: TextStyle(
                    color: theme.textPrimary.withValues(alpha: 0.8),
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
                    color: theme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history_rounded, color: theme.primary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          lastSet != null
                              ? (isArabic
                                  ? 'آخر أداء: ${lastSet.weightKg != null ? "${lastSet.weightKg} كجم" : ""} ${lastSet.reps != null ? "× ${lastSet.reps} تكرار" : ""}'
                                  : 'Last Performance: ${lastSet.weightKg != null ? "${lastSet.weightKg} kg" : ""} ${lastSet.reps != null ? "× ${lastSet.reps} reps" : ""}')
                              : (isArabic
                                  ? 'لا توجد سجلات أداء سابقة لهذا التمرين.'
                                  : 'No prior workouts recorded for this exercise yet.'),
                          style: TextStyle(color: theme.textSecondary, fontSize: 13),
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
                      foregroundColor: theme.tertiary,
                      side: BorderSide(color: theme.tertiary.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.analytics_outlined, size: 20),
                    label: Text(
                      isArabic ? 'التحليلات والأرقام القياسية' : 'View Progression & PRs',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciseAnalyticsScreen(
                            exerciseId: exercise.id,
                            dbService: _dbService,
                            themeController: widget.themeController,
                            localeController: widget.localeController,
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
                      backgroundColor: theme.primary,
                      foregroundColor: theme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 22),
                    label: Text(
                      isArabic ? 'إضافة إلى التمرين' : 'Add to Workout',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _addExerciseToWorkout(exercise, theme, isArabic);
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
