import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/gym_analytics_repository.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/exercise_analytics.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

enum ChartMetric { maxWeight, estimated1RM, volume }

class ExerciseAnalyticsScreen extends StatefulWidget {
  final String exerciseId;
  final GymDatabaseService? dbService;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const ExerciseAnalyticsScreen({
    super.key,
    required this.exerciseId,
    this.dbService,
    this.themeController,
    this.localeController,
  });

  @override
  State<ExerciseAnalyticsScreen> createState() => _ExerciseAnalyticsScreenState();
}

class _ExerciseAnalyticsScreenState extends State<ExerciseAnalyticsScreen> {
  late final GymDatabaseService _dbService;
  late final GymAnalyticsRepository _analyticsRepo;
  late final ExerciseRepository _exerciseRepo;

  Exercise? _exercise;
  ExercisePRs _prs = ExercisePRs.empty;
  List<ExerciseDataPoint> _dataPoints = [];
  List<ExerciseSessionHistory> _sessionHistories = [];
  bool _isLoading = true;
  int? _scrubIndex;

  ChartMetric _activeMetric = ChartMetric.maxWeight;

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _analyticsRepo = GymAnalyticsRepository(dbService: _dbService);
    _exerciseRepo = ExerciseRepository(dbService: _dbService);
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }

      final ex = await _exerciseRepo.getExerciseById(widget.exerciseId);
      final prs = await _analyticsRepo.getExercisePRs(widget.exerciseId);
      final points = await _analyticsRepo.getExerciseDataPoints(widget.exerciseId);
      final history = await _analyticsRepo.getExerciseSessionHistory(widget.exerciseId);

      if (mounted) {
        setState(() {
          _exercise = ex;
          _prs = prs;
          _dataPoints = points;
          _sessionHistories = history;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    final theme = widget.themeController?.tokens ?? AppTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        elevation: 0,
        title: Text(
          _exercise?.name ?? (isArabic ? 'تحليلات التمرين' : 'Exercise Analytics'),
          style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PR Cards Header
                  _buildPRCardsGrid(theme, isArabic),
                  const SizedBox(height: 24),

                  // Chart Section
                  _buildChartSection(theme, isArabic),
                  const SizedBox(height: 24),

                  // Session History Section
                  Text(
                    isArabic ? 'سجل الجلسات' : 'Workout History',
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(theme, isArabic),
                ],
              ),
            ),
    );
  }

  String _formatMetricPoint(ExerciseDataPoint point) {
    switch (_activeMetric) {
      case ChartMetric.maxWeight:
        return '${point.maxWeightKg.toStringAsFixed(point.maxWeightKg % 1 == 0 ? 0 : 1)} kg';
      case ChartMetric.estimated1RM:
        return '1RM: ${point.estimated1RM.toStringAsFixed(1)} kg';
      case ChartMetric.volume:
        return 'Vol: ${point.totalVolumeKg.toStringAsFixed(0)} kg';
    }
  }

  void _updateScrub(double dx, double totalWidth) {
    if (_dataPoints.length < 2) return;
    const paddingLeft = 32.0;
    final chartWidth = totalWidth - paddingLeft;
    if (chartWidth <= 0) return;
    final relativeX = (dx - paddingLeft).clamp(0.0, chartWidth);
    final ratio = relativeX / chartWidth;
    final index = (ratio * (_dataPoints.length - 1)).round().clamp(0, _dataPoints.length - 1);
    if (_scrubIndex != index) {
      HapticFeedback.selectionClick();
      setState(() => _scrubIndex = index);
    }
  }

  Widget _buildPRCardsGrid(AppThemeTokens theme, bool isArabic) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final weightStr = _prs.maxWeightKg > 0
        ? '${_prs.maxWeightKg.toStringAsFixed(_prs.maxWeightKg % 1 == 0 ? 0 : 1)} kg'
        : '--';
    final oneRmStr = _prs.bestEstimated1RM > 0
        ? '${_prs.bestEstimated1RM.toStringAsFixed(1)} kg'
        : '--';
    final volStr = _prs.maxSessionVolumeKg > 0
        ? '${_prs.maxSessionVolumeKg.toStringAsFixed(0)} kg'
        : '--';

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          key: const Key('pr_max_weight_card'),
          title: isArabic ? 'أقصى وزن' : 'MAX WEIGHT',
          value: weightStr,
          subtitle: _prs.maxWeightDate != null ? dateFormat.format(_prs.maxWeightDate!.toLocal()) : null,
          theme: theme,
          accentColor: theme.primary,
          icon: Icons.emoji_events_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_1rm_card'),
          title: isArabic ? 'أقصى تكرار (1RM)' : 'EST. 1RM',
          value: oneRmStr,
          subtitle: _prs.best1RMDate != null ? dateFormat.format(_prs.best1RMDate!.toLocal()) : null,
          theme: theme,
          accentColor: theme.tertiary,
          icon: Icons.flash_on_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_volume_card'),
          title: isArabic ? 'أقصى حجم تدريبي' : 'MAX VOLUME',
          value: volStr,
          subtitle: _prs.maxVolumeDate != null ? dateFormat.format(_prs.maxVolumeDate!.toLocal()) : null,
          theme: theme,
          accentColor: const Color(0xFFFFB300),
          icon: Icons.stacked_line_chart_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_sessions_card'),
          title: isArabic ? 'الجلسات المسجلة' : 'SESSIONS',
          value: '${_prs.totalSessions}',
          subtitle: isArabic ? 'مجموع التمارين' : 'Logged Workouts',
          theme: theme,
          accentColor: const Color(0xFFBA68C8),
          icon: Icons.event_repeat_rounded,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required Key key,
    required String title,
    required String value,
    String? subtitle,
    required AppThemeTokens theme,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(color: theme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(AppThemeTokens theme, bool isArabic) {
    return Container(
      key: const Key('exercise_progression_chart_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic ? 'منحنى التطور' : 'Progression',
                style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (_scrubIndex != null && _scrubIndex! < _dataPoints.length)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${DateFormat('MMM d').format(_dataPoints[_scrubIndex!].date.toLocal())}: ${_formatMetricPoint(_dataPoints[_scrubIndex!])}',
                    style: TextStyle(
                      color: theme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Metric Selector
          Row(
            children: [
              _buildMetricButton(isArabic ? 'الوزن' : 'Weight', ChartMetric.maxWeight, theme),
              const SizedBox(width: 8),
              _buildMetricButton('1RM', ChartMetric.estimated1RM, theme),
              const SizedBox(width: 8),
              _buildMetricButton(isArabic ? 'الحجم' : 'Volume', ChartMetric.volume, theme),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            width: double.infinity,
            child: _dataPoints.length < 2
                ? Center(
                    child: Text(
                      _dataPoints.isEmpty
                          ? (isArabic ? 'لا توجد جلسات مسجلة بعد.' : 'No session history recorded yet.')
                          : (isArabic
                              ? 'سجّل جلسة واحدة إضافية لرسم منحنى التطور! 💪'
                              : 'Log one more session to render your progression graph! 💪'),
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanDown: (details) => _updateScrub(details.localPosition.dx, constraints.maxWidth),
                        onPanUpdate: (details) => _updateScrub(details.localPosition.dx, constraints.maxWidth),
                        onPanEnd: (_) => setState(() => _scrubIndex = null),
                        onPanCancel: () => setState(() => _scrubIndex = null),
                        child: CustomPaint(
                          painter: _ProgressionChartPainter(
                            dataPoints: _dataPoints,
                            metric: _activeMetric,
                            lineColor: theme.primary,
                            backgroundColor: theme.background,
                            gridColor: theme.border,
                            textColor: theme.textSecondary,
                            scrubIndex: _scrubIndex,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricButton(String label, ChartMetric metric, AppThemeTokens theme) {
    final isSelected = _activeMetric == metric;
    final accent = theme.primary;
    return InkWell(
      key: Key('metric_btn_${metric.name}'),
      onTap: () => setState(() => _activeMetric = metric),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accent : theme.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accent : theme.textSecondary,
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(AppThemeTokens theme, bool isArabic) {
    if (_sessionHistories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Center(
          child: Text(
            isArabic ? 'لا توجد جلسات مسجلة بعد.' : 'No workout history yet.',
            style: TextStyle(color: theme.textSecondary),
          ),
        ),
      );
    }

    final dateFormat = DateFormat('MMM d, yyyy');

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _sessionHistories.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = _sessionHistories[index];
        return Container(
          key: Key('history_session_${session.sessionId}'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(session.date.toLocal()),
                    style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${isArabic ? "أقصى: " : "Max: "}${session.maxWeightKg.toStringAsFixed(session.maxWeightKg % 1 == 0 ? 0 : 1)} kg',
                    style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: session.sets.map((s) {
                  final text = s.durationSeconds != null
                      ? (isArabic ? 'م${s.setNumber}: ${s.durationSeconds}ث' : 'S${s.setNumber}: ${s.durationSeconds}s')
                      : (isArabic
                          ? 'م${s.setNumber}: ${s.weightKg?.toStringAsFixed(0) ?? 0}ك × ${s.reps ?? 0}'
                          : 'S${s.setNumber}: ${s.weightKg?.toStringAsFixed(0) ?? 0}k × ${s.reps ?? 0}');
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.surfaceContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(color: theme.textSecondary, fontSize: 11),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressionChartPainter extends CustomPainter {
  final List<ExerciseDataPoint> dataPoints;
  final ChartMetric metric;
  final Color lineColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color textColor;
  final int? scrubIndex;

  _ProgressionChartPainter({
    required this.dataPoints,
    required this.metric,
    required this.lineColor,
    required this.backgroundColor,
    required this.gridColor,
    required this.textColor,
    this.scrubIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.length < 2) return;

    final values = dataPoints.map((p) {
      switch (metric) {
        case ChartMetric.maxWeight:
          return p.maxWeightKg;
        case ChartMetric.estimated1RM:
          return p.estimated1RM;
        case ChartMetric.volume:
          return p.totalVolumeKg;
      }
    }).toList();

    double minVal = values.reduce((a, b) => a < b ? a : b);
    double maxVal = values.reduce((a, b) => a > b ? a : b);

    if (maxVal == minVal) {
      maxVal += 10.0;
      minVal = (minVal - 10.0).clamp(0.0, double.infinity);
    }

    const double paddingLeft = 32.0;
    const double paddingBottom = 24.0;
    final double chartWidth = size.width - paddingLeft;
    final double chartHeight = size.height - paddingBottom;

    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * (i / 3);
      canvas.drawLine(Offset(paddingLeft, y), Offset(size.width, y), gridPaint);
    }

    // Compute point offsets
    final points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final x = paddingLeft + (chartWidth / (values.length - 1)) * i;
      final normalizedY = (values[i] - minVal) / (maxVal - minVal);
      final y = chartHeight - (normalizedY * chartHeight);
      points.add(Offset(x, y));
    }

    // Draw Smooth Cubic Bezier Line and Gradient Area
    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final cp1 = Offset(prev.dx + (curr.dx - prev.dx) / 2, prev.dy);
      final cp2 = Offset(prev.dx + (curr.dx - prev.dx) / 2, curr.dy);
      linePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, curr.dx, curr.dy);
    }

    final areaPath = Path.from(linePath)
      ..lineTo(points.last.dx, chartHeight)
      ..lineTo(points.first.dx, chartHeight)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.28), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(areaPath, areaPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // Draw Scrub crosshair indicator
    if (scrubIndex != null && scrubIndex! < points.length) {
      final scrubPt = points[scrubIndex!];
      final scrubPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.45)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(scrubPt.dx, 0), Offset(scrubPt.dx, chartHeight), scrubPaint);

      final outerRing = Paint()..color = lineColor.withValues(alpha: 0.25);
      canvas.drawCircle(scrubPt, 9.0, outerRing);
    }

    // Draw Data Point Circles
    final dotPaint = Paint()..color = lineColor;
    final dotInner = Paint()..color = backgroundColor;
    for (int i = 0; i < points.length; i++) {
      final pt = points[i];
      final isHovered = scrubIndex == i;
      canvas.drawCircle(pt, isHovered ? 5.5 : 4.0, dotPaint);
      canvas.drawCircle(pt, isHovered ? 2.5 : 2.0, dotInner);
    }

    // Draw Min/Max Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: maxVal.toStringAsFixed(0),
      style: TextStyle(color: textColor, fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    textPainter.text = TextSpan(
      text: minVal.toStringAsFixed(0),
      style: TextStyle(color: textColor, fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, chartHeight - 12));
  }

  @override
  bool shouldRepaint(covariant _ProgressionChartPainter oldDelegate) {
    return oldDelegate.metric != metric ||
        oldDelegate.dataPoints != dataPoints ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.scrubIndex != scrubIndex;
  }
}
