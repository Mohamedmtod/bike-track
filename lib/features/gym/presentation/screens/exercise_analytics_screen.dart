import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/gym_analytics_repository.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/exercise_analytics.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

enum ChartMetric { maxWeight, estimated1RM, volume }

class ExerciseAnalyticsScreen extends StatefulWidget {
  final String exerciseId;
  final GymDatabaseService? dbService;

  const ExerciseAnalyticsScreen({
    super.key,
    required this.exerciseId,
    this.dbService,
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
    const bgDark = Color(0xFF090A0F);
    const cardDark = Color(0xFF14161F);
    const accentLime = Color(0xFFCCFF00);
    const accentCyan = Color(0xFF00E5FF);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          _exercise?.name ?? 'Exercise Analytics',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentLime))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PR Cards Header
                  _buildPRCardsGrid(cardDark, accentLime, accentCyan),
                  const SizedBox(height: 24),

                  // Chart Section
                  _buildChartSection(cardDark, accentLime),
                  const SizedBox(height: 24),

                  // Session History Section
                  const Text(
                    'Workout History (سجل الجلسات)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _buildHistoryList(cardDark, accentLime),
                ],
              ),
            ),
    );
  }

  Widget _buildPRCardsGrid(Color cardDark, Color accentLime, Color accentCyan) {
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
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          key: const Key('pr_max_weight_card'),
          title: 'MAX WEIGHT (الوزن الأقصى)',
          value: weightStr,
          cardDark: cardDark,
          accentColor: accentLime,
          icon: Icons.emoji_events_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_1rm_card'),
          title: 'EST. 1RM (التكرار الأقصى)',
          value: oneRmStr,
          cardDark: cardDark,
          accentColor: accentCyan,
          icon: Icons.flash_on_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_volume_card'),
          title: 'MAX VOLUME (الحجم الأقصى)',
          value: volStr,
          cardDark: cardDark,
          accentColor: const Color(0xFFFFB300),
          icon: Icons.stacked_line_chart_rounded,
        ),
        _buildStatCard(
          key: const Key('pr_sessions_card'),
          title: 'SESSIONS (عدد الجلسات)',
          value: '${_prs.totalSessions}',
          cardDark: cardDark,
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
    required Color cardDark,
    required Color accentColor,
    required IconData icon,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                  style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 10, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: accentColor, size: 16),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              color: accentColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(Color cardDark, Color accentLime) {
    return Container(
      key: const Key('exercise_progression_chart_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Progression (منحنى التطور)',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 10),
              // Metric Selector
              Row(
                children: [
                  _buildMetricButton('Weight', ChartMetric.maxWeight, accentLime),
                  const SizedBox(width: 8),
                  _buildMetricButton('1RM', ChartMetric.estimated1RM, accentLime),
                  const SizedBox(width: 8),
                  _buildMetricButton('Volume', ChartMetric.volume, accentLime),
                ],
              ),
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
                          ? 'No session history recorded yet.'
                          : 'Log one more session to render your progression graph! 💪',
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : CustomPaint(
                    painter: _ProgressionChartPainter(
                      dataPoints: _dataPoints,
                      metric: _activeMetric,
                      lineColor: accentLime,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricButton(String label, ChartMetric metric, Color accentColor) {
    final isSelected = _activeMetric == metric;
    return InkWell(
      key: Key('metric_btn_${metric.name}'),
      onTap: () => setState(() => _activeMetric = metric),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white12,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? accentColor : const Color(0xFF8E9BAE),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(Color cardDark, Color accentLime) {
    if (_sessionHistories.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text('No workout history yet.', style: TextStyle(color: Color(0xFF8E9BAE))),
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
            color: cardDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    dateFormat.format(session.date.toLocal()),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    'Max: ${session.maxWeightKg.toStringAsFixed(session.maxWeightKg % 1 == 0 ? 0 : 1)} kg',
                    style: TextStyle(color: accentLime, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: session.sets.map((s) {
                  final text = s.durationSeconds != null
                      ? 'S${s.setNumber}: ${s.durationSeconds}s'
                      : 'S${s.setNumber}: ${s.weightKg?.toStringAsFixed(0) ?? 0}k × ${s.reps ?? 0}';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
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

  _ProgressionChartPainter({
    required this.dataPoints,
    required this.metric,
    required this.lineColor,
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

    final double paddingLeft = 32.0;
    final double paddingBottom = 24.0;
    final double chartWidth = size.width - paddingLeft;
    final double chartHeight = size.height - paddingBottom;

    // Draw Grid Lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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

    // Draw Gradient Area below line
    final path = Path()..moveTo(points.first.dx, chartHeight);
    for (final pt in points) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.lineTo(points.last.dx, chartHeight);
    path.close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight));
    canvas.drawPath(path, areaPaint);

    // Draw Progression Line
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Draw Data Point Circles
    final dotPaint = Paint()..color = lineColor;
    final dotInner = Paint()..color = const Color(0xFF090A0F);
    for (final pt in points) {
      canvas.drawCircle(pt, 4.0, dotPaint);
      canvas.drawCircle(pt, 2.0, dotInner);
    }

    // Draw Min/Max Labels
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    textPainter.text = TextSpan(
      text: maxVal.toStringAsFixed(0),
      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, 0));

    textPainter.text = TextSpan(
      text: minVal.toStringAsFixed(0),
      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(0, chartHeight - 12));
  }

  @override
  bool shouldRepaint(covariant _ProgressionChartPainter oldDelegate) {
    return oldDelegate.metric != metric || oldDelegate.dataPoints != dataPoints;
  }
}
