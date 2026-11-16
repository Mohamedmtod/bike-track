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
                        child: Icon(_getMuscleIcon(widget.muscleId), color: theme.primary, size: 24),
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

  IconData _getMuscleIcon(String? muscleId) {
    if (muscleId == null) return Icons.fitness_center_rounded;
    final id = muscleId.toLowerCase();
    if (id.contains('chest') || id.contains('pec')) return Icons.view_sidebar_rounded;
    if (id.contains('back') || id.contains('lat') || id.contains('trap')) return Icons.layers_rounded;
    if (id.contains('shoulder') || id.contains('delt')) return Icons.accessibility_new_rounded;
    if (id.contains('bicep') || id.contains('arm') || id.contains('tricep')) return Icons.fitness_center_rounded;
    if (id.contains('quad') || id.contains('thigh') || id.contains('leg') || id.contains('ham') || id.contains('calf')) return Icons.directions_run_rounded;
    if (id.contains('core') || id.contains('ab')) return Icons.shield_rounded;
    return Icons.fitness_center_rounded;
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
            size: 52,
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
                if (ExerciseThumbnailWidget.getGuide(exercise.id) != null)
                  _buildPill(
                    isArabic ? '📸 دليل مصور' : '📸 Visual Guide',
                    theme.primary.withValues(alpha: 0.15),
                    theme.primary,
                  ),
                if (lastSet != null)
                  _buildPerformancePill(lastSet, theme.primary, isArabic)
                else
                  _buildPill(isArabic ? 'جديد' : 'New', theme.surfaceContainer, theme.textSecondary),
              ],
            ),
          ),
          trailing: SizedBox(
            width: 44,
            height: 44,
            child: IconButton(
              key: Key('exercise_analytics_btn_${exercise.id}'),
              icon: Icon(Icons.insights_rounded, color: theme.tertiary, size: 22),
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
    final anatomyPath = ExerciseThumbnailWidget.getIllustration(exercise.id);
    final guidePath = ExerciseThumbnailWidget.getGuide(exercise.id);
    final hasVisualGuide = anatomyPath != null || guidePath != null;
    int selectedGuideTab = guidePath != null ? 1 : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (bottomSheetContext, setSheetState) {
            final activeImagePath = selectedGuideTab == 1 ? (guidePath ?? anatomyPath) : (anatomyPath ?? guidePath);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        if (hasVisualGuide)
                                          _buildPill(
                                            isArabic ? '📸 دليل مصور' : '📸 Visual Guide',
                                            theme.primary.withValues(alpha: 0.15),
                                            theme.primary,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (hasVisualGuide && activeImagePath != null) ...[
                            const SizedBox(height: 16),
                            if (anatomyPath != null && guidePath != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: theme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.border),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() => selectedGuideTab = 0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selectedGuideTab == 0 ? theme.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.accessibility_new_rounded,
                                                size: 15,
                                                color: selectedGuideTab == 0 ? theme.onPrimary : theme.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  isArabic ? 'التشريح العضلي' : 'Anatomy',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: selectedGuideTab == 0 ? theme.onPrimary : theme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setSheetState(() => selectedGuideTab = 1),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          decoration: BoxDecoration(
                                            color: selectedGuideTab == 1 ? theme.primary : Colors.transparent,
                                            borderRadius: BorderRadius.circular(9),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.checklist_rounded,
                                                size: 15,
                                                color: selectedGuideTab == 1 ? theme.onPrimary : theme.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  isArabic ? 'دليل التكنيك' : 'Form Guide',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: selectedGuideTab == 1 ? theme.onPrimary : theme.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            GestureDetector(
                              onTap: () => _showFullScreenImage(
                                context: context,
                                imagePath: activeImagePath,
                                title: selectedGuideTab == 0
                                    ? (isArabic ? 'التشريح العضلي للتمرينة' : 'Exercise Anatomy')
                                    : (isArabic ? 'دليل التكنيك ونقاط الارتكاز الخمس' : 'Form Guide: 5 Points of Contact'),
                                theme: theme,
                                isArabic: isArabic,
                              ),
                              child: Container(
                                height: 215,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.primary.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.primary.withValues(alpha: 0.12),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Image.asset(
                                            activeImagePath,
                                            fit: BoxFit.contain,
                                            errorBuilder: (_, _, _) => Center(
                                              child: Text(
                                                isArabic ? 'تعذر تحميل الصورة' : 'Image unavailable',
                                                style: TextStyle(color: theme.textSecondary),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 14),
                                              const SizedBox(width: 4),
                                              Text(
                                                isArabic ? 'اضغط للتكبير' : 'Tap to Zoom',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (exercise.id == 'bench_press') ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.verified_rounded, size: 16, color: theme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isArabic ? 'نقاط الارتكاز الخمس للتكنيك الصحيح' : '5 POINTS OF CONTACT (PRO FORM)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: theme.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildContactPointItem(
                              number: '1',
                              title: isArabic ? 'الأرداف (Glutes)' : 'Glutes Firmly on Bench',
                              description: isArabic
                                  ? 'ملاصقة للمقعد طوال التمرين بدون رفع لتثبيت الجذع وتجنب تقوس الظهر المفرط.'
                                  : 'Glutes remaining firmly on the bench throughout the lift to anchor the core.',
                              theme: theme,
                            ),
                            _buildContactPointItem(
                              number: '2',
                              title: isArabic ? 'لوحا الكتف (Shoulder Blades)' : 'Shoulder Blades Retracted',
                              description: isArabic
                                  ? 'مرتدة ومضغوطة للخلف والأسفل بإحكام على المقعد لثبات مفصل الكتف وتوليد القوة.'
                                  : 'Shoulder blades pinned firmly and retracted to protect joints and drive power.',
                              theme: theme,
                            ),
                            _buildContactPointItem(
                              number: '3',
                              title: isArabic ? 'القدمان (Foot Planted)' : 'Feet Planted on Floor',
                              description: isArabic
                                  ? 'مسطحتان ومثبتتان بالكامل على الأرض لدفع الساقين (Leg Drive) ومنع أي انزلاق.'
                                  : 'Feet planted firmly flat on the floor to generate leg drive and stability.',
                              theme: theme,
                            ),
                            _buildContactPointItem(
                              number: '4',
                              title: isArabic ? 'الرأس (Head Firm)' : 'Head Firmly on Bench',
                              description: isArabic
                                  ? 'مستقرة تماماً على المقعد طوال الحركة لمنع أي إجهاد لعضلات الرقبة والعمود الفقري.'
                                  : 'Head resting firmly on the bench without strain on cervical spine.',
                              theme: theme,
                            ),
                            _buildContactPointItem(
                              number: '5',
                              title: isArabic ? 'الكوعان (Elbows 45°)' : 'Elbows at 45° Angle',
                              description: isArabic
                                  ? 'بزاوية 45 درجة تقريباً من الجذع لتفادي إجهاد أوتار الكتف وحفظ مسار البار السليم.'
                                  : 'Tucked at roughly 45 degrees from the torso to protect rotator cuffs and maximize chest load.',
                              theme: theme,
                            ),
                          ],
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
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  // Sticky Action Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border(
                        top: BorderSide(color: theme.border.withValues(alpha: 0.5)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // View Analytics & PRs Button
                        SizedBox(
                          width: double.infinity,
                          height: 42,
                          child: OutlinedButton.icon(
                            key: Key('view_exercise_analytics_${exercise.id}'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.tertiary,
                              side: BorderSide(color: theme.tertiary.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.analytics_outlined, size: 18),
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
                        const SizedBox(height: 8),
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildContactPointItem({
    required String number,
    required String title,
    required String description,
    required AppThemeTokens theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: TextStyle(
                color: theme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenImage({
    required BuildContext context,
    required String imagePath,
    required String title,
    required AppThemeTokens theme,
    required bool isArabic,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: const Color(0xFF12141A),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      border: Border(bottom: BorderSide(color: theme.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          color: theme.textSecondary,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Container(
                      color: Colors.white,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.65,
                      ),
                      child: InteractiveViewer(
                        panEnabled: true,
                        scaleEnabled: true,
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.asset(
                            imagePath,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: theme.surface,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pinch_rounded, size: 14, color: theme.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          isArabic
                              ? 'استخدم إصبعين للتقريب والتحريك (Pinch to Zoom)'
                              : 'Pinch with 2 fingers to zoom & pan',
                          style: TextStyle(color: theme.textSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
