import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/models/analytics_models.dart';
import 'package:bike_track/screens/daily_stats_screen.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';

class OverallStatsScreen extends StatefulWidget {
  final RideController controller;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const OverallStatsScreen({
    super.key,
    required this.controller,
    this.themeController,
    this.localeController,
  });

  @override
  State<OverallStatsScreen> createState() => _OverallStatsScreenState();
}

class _OverallStatsScreenState extends State<OverallStatsScreen> {
  AnalyticsPeriod _selectedPeriod = AnalyticsPeriod.week;
  AnalyticsMetric _selectedMetric = AnalyticsMetric.distance;
  late DateTime _referenceDate;

  @override
  void initState() {
    super.initState();
    _referenceDate = DateTime.now();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
  }

  void _previousPeriod() {
    HapticFeedback.lightImpact();
    setState(() {
      switch (_selectedPeriod) {
        case AnalyticsPeriod.day:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day - 1, 12);
          break;
        case AnalyticsPeriod.week:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day - 7, 12);
          break;
        case AnalyticsPeriod.month:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month - 1, _referenceDate.day, 12);
          break;
        case AnalyticsPeriod.year:
          _referenceDate = DateTime(_referenceDate.year - 1, _referenceDate.month, _referenceDate.day, 12);
          break;
        case AnalyticsPeriod.all:
          break;
      }
    });
  }

  void _nextPeriod() {
    if (_isCurrentPeriod) return;
    HapticFeedback.lightImpact();
    setState(() {
      switch (_selectedPeriod) {
        case AnalyticsPeriod.day:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day + 1, 12);
          break;
        case AnalyticsPeriod.week:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day + 7, 12);
          break;
        case AnalyticsPeriod.month:
          _referenceDate = DateTime(_referenceDate.year, _referenceDate.month + 1, _referenceDate.day, 12);
          break;
        case AnalyticsPeriod.year:
          _referenceDate = DateTime(_referenceDate.year + 1, _referenceDate.month, _referenceDate.day, 12);
          break;
        case AnalyticsPeriod.all:
          break;
      }
    });
  }

  bool get _isCurrentPeriod {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case AnalyticsPeriod.day:
        return _referenceDate.year == now.year &&
            _referenceDate.month == now.month &&
            _referenceDate.day == now.day;
      case AnalyticsPeriod.week:
        final nowDaysFromMonday = (now.weekday - DateTime.monday) % 7;
        final nowMonday = DateTime(now.year, now.month, now.day - nowDaysFromMonday);
        final refDaysFromMonday = (_referenceDate.weekday - DateTime.monday) % 7;
        final refMonday = DateTime(_referenceDate.year, _referenceDate.month, _referenceDate.day - refDaysFromMonday);
        return nowMonday.year == refMonday.year &&
            nowMonday.month == refMonday.month &&
            nowMonday.day == refMonday.day;
      case AnalyticsPeriod.month:
        return _referenceDate.year == now.year && _referenceDate.month == now.month;
      case AnalyticsPeriod.year:
        return _referenceDate.year == now.year;
      case AnalyticsPeriod.all:
        return true;
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPeriodRange(PeriodSummary summary, AppStrings strings) {
    switch (summary.period) {
      case AnalyticsPeriod.day:
        return strings.formatDateFull(summary.referenceDate);
      case AnalyticsPeriod.week:
        final start = summary.startDate.toLocal();
        final end = summary.endDate.toLocal();
        return '${start.day}/${start.month} - ${end.day}/${end.month}/${end.year}';
      case AnalyticsPeriod.month:
        return strings.formatMonthYear(summary.referenceDate);
      case AnalyticsPeriod.year:
        return '${summary.referenceDate.toLocal().year}';
      case AnalyticsPeriod.all:
        return strings.periodAll;
    }
  }

  String _formatMetricValue(double value, AnalyticsMetric metric, AppStrings strings) {
    switch (metric) {
      case AnalyticsMetric.distance:
        return value >= 10 ? value.toStringAsFixed(1) : value.toStringAsFixed(2);
      case AnalyticsMetric.duration:
        final int mins = value.round();
        if (mins >= 60) {
          final hrs = mins ~/ 60;
          final m = mins % 60;
          return '${hrs}h ${m}m';
        }
        return '${mins}m';
      case AnalyticsMetric.averageSpeed:
        return value.toStringAsFixed(1);
      case AnalyticsMetric.rideCount:
        return value.round().toString();
    }
  }

  String _getMetricUnit(AnalyticsMetric metric, AppStrings strings) {
    switch (metric) {
      case AnalyticsMetric.distance:
        return strings.kmUnit;
      case AnalyticsMetric.duration:
        return '';
      case AnalyticsMetric.averageSpeed:
        return strings.kmhUnit;
      case AnalyticsMetric.rideCount:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveThemeController = widget.themeController ?? ThemeController();
    final effectiveLocaleController = widget.localeController ?? LocaleController();
    final theme = effectiveThemeController.currentTheme;
    final strings = effectiveLocaleController.strings;

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final summary = widget.controller.getPeriodSummary(
      period: _selectedPeriod,
      metric: _selectedMetric,
      referenceDate: _referenceDate,
    );

    final records = widget.controller.getPersonalRecords();

    return Directionality(
      textDirection: effectiveLocaleController.textDirection,
      child: Scaffold(
        backgroundColor: theme.background,
        body: Stack(
          children: [
            // Scrollable Content
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, topInset + 88, 16, bottomInset + 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Period Selector Tabs
                  _buildPeriodSelector(theme, strings),

                  const SizedBox(height: 16),

                  // 2. Period Navigation & Range
                  _buildPeriodNavigation(summary, theme, strings),

                  const SizedBox(height: 16),

                  // 3. Hero Period Metrics Cards
                  _buildHeroSummaryCards(summary, theme, strings),

                  const SizedBox(height: 20),

                  // 4. Metric Switcher Pills
                  _buildMetricSwitcher(theme, strings),

                  const SizedBox(height: 14),

                  // 5. Dynamic Chart Breakdown Card
                  _buildChartCard(summary, theme, strings, effectiveThemeController, effectiveLocaleController),

                  const SizedBox(height: 24),

                  // 6. Personal Records Section
                  _buildPersonalRecordsCard(records, theme, strings, effectiveThemeController, effectiveLocaleController),

                  const SizedBox(height: 20),

                  // 7. All-Time Odometer
                  _buildAllTimeOdometerCard(theme, strings),
                ],
              ),
            ),

            // Floating Header
            Positioned(
              top: topInset + 8,
              left: 16,
              right: 16,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const Key('overall_stats_back_button'),
                          icon: Transform.flip(
                            flipX: Directionality.of(context) == TextDirection.rtl,
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: theme.textPrimary,
                              size: 18,
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).pop();
                          },
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                strings.overallStatsTitle,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                strings.periodBreakdownTitle,
                                style: TextStyle(
                                  color: theme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.primary.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.insights_rounded, color: theme.primary, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.controller.ridesHistory.length}',
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(AppThemeTokens theme, AppStrings strings) {
    const periods = [
      AnalyticsPeriod.day,
      AnalyticsPeriod.week,
      AnalyticsPeriod.month,
      AnalyticsPeriod.year,
      AnalyticsPeriod.all,
    ];

    String labelFor(AnalyticsPeriod p) {
      switch (p) {
        case AnalyticsPeriod.day:
          return strings.periodDay;
        case AnalyticsPeriod.week:
          return strings.periodWeek;
        case AnalyticsPeriod.month:
          return strings.periodMonth;
        case AnalyticsPeriod.year:
          return strings.periodYear;
        case AnalyticsPeriod.all:
          return strings.periodAll;
      }
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (_selectedPeriod != period) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedPeriod = period;
                    if (period == AnalyticsPeriod.all) {
                      _referenceDate = DateTime.now();
                    }
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? theme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: theme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    labelFor(period),
                    style: TextStyle(
                      color: isSelected ? theme.onPrimary : theme.textSecondary,
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodNavigation(PeriodSummary summary, AppThemeTokens theme, AppStrings strings) {
    final canGoNext = !_isCurrentPeriod && _selectedPeriod != AnalyticsPeriod.all;
    final canGoPrev = _selectedPeriod != AnalyticsPeriod.all;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: Icon(
                Icons.chevron_left_rounded,
                color: canGoPrev ? theme.textPrimary : theme.textSecondary.withValues(alpha: 0.3),
                size: 24,
              ),
            ),
            tooltip: strings.previousPeriodTooltip,
            onPressed: canGoPrev ? _previousPeriod : null,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _formatPeriodRange(summary, strings),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (!_isCurrentPeriod && _selectedPeriod != AnalyticsPeriod.all) ...[
                  const SizedBox(height: 2),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _referenceDate = DateTime.now();
                      });
                    },
                    child: Text(
                      strings.metricToday,
                      style: TextStyle(
                        color: theme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: Icon(
                Icons.chevron_right_rounded,
                color: canGoNext ? theme.textPrimary : theme.textSecondary.withValues(alpha: 0.3),
                size: 24,
              ),
            ),
            tooltip: strings.nextPeriodTooltip,
            onPressed: canGoNext ? _nextPeriod : null,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSummaryCards(PeriodSummary summary, AppThemeTokens theme, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: theme.isDark ? 0.08 : 0.03),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.straighten_rounded,
                  label: strings.dayTotalDistance,
                  value: summary.totalDistanceKm >= 10
                      ? summary.totalDistanceKm.toStringAsFixed(1)
                      : summary.totalDistanceKm.toStringAsFixed(2),
                  unit: strings.kmUnit,
                  theme: theme,
                  accentColor: theme.primary,
                ),
              ),
              Container(width: 1, height: 48, color: theme.cardBorder),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.timer_outlined,
                  label: strings.dayMovingTime,
                  value: _formatDuration(summary.totalDurationSeconds),
                  unit: '',
                  theme: theme,
                  accentColor: const Color(0xFF06B6D4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.cardBorder),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.speed_rounded,
                  label: strings.dayAvgSpeed,
                  value: summary.avgSpeedKmh.toStringAsFixed(1),
                  unit: strings.kmhUnit,
                  theme: theme,
                  accentColor: const Color(0xFFF59E0B),
                ),
              ),
              Container(width: 1, height: 48, color: theme.cardBorder),
              Expanded(
                child: _buildMetricTile(
                  icon: Icons.directions_bike_rounded,
                  label: strings.metricRideCount,
                  value: '${summary.rideCount}',
                  unit: strings.dayRidesCountText(summary.rideCount).replaceAll('${summary.rideCount}', '').trim(),
                  theme: theme,
                  accentColor: const Color(0xFFA855F7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required AppThemeTokens theme,
    required Color accentColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: accentColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -0.5,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Text(
                  unit,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricSwitcher(AppThemeTokens theme, AppStrings strings) {
    final metrics = [
      (AnalyticsMetric.distance, strings.metricDistance, Icons.straighten_rounded),
      (AnalyticsMetric.duration, strings.metricDuration, Icons.timer_outlined),
      (AnalyticsMetric.averageSpeed, strings.metricSpeed, Icons.speed_rounded),
      (AnalyticsMetric.rideCount, strings.metricRideCount, Icons.tag_rounded),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: metrics.map((item) {
          final isSelected = _selectedMetric == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                if (_selectedMetric != item.$1) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedMetric = item.$1;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.primary.withValues(alpha: 0.18)
                      : theme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? theme.primary : theme.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$3,
                      size: 13,
                      color: isSelected ? theme.primary : theme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: isSelected ? theme.primary : theme.textSecondary,
                        fontSize: 11,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartCard(
    PeriodSummary summary,
    AppThemeTokens theme,
    AppStrings strings,
    ThemeController themeController,
    LocaleController localeController,
  ) {
    final buckets = summary.buckets;
    double maxVal = 0.0;
    for (final b in buckets) {
      if (b.value > maxVal) maxVal = b.value;
    }
    if (maxVal <= 0.0) maxVal = 1.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  strings.periodBreakdownTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getMetricUnit(_selectedMetric, strings),
                style: TextStyle(
                  color: theme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (buckets.isEmpty || summary.rideCount == 0) ...[
            Container(
              height: 140,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 36,
                    color: theme.textSecondary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    strings.noDataForPeriod,
                    style: TextStyle(
                      color: theme.textSecondary.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: buckets.map((bucket) {
                  final ratio = (bucket.value / maxVal).clamp(0.04, 1.0);
                  final hasValue = bucket.value > 0;

                  return Expanded(
                    child: Semantics(
                      button: true,
                      label: '${bucket.label}: ${_formatMetricValue(bucket.value, _selectedMetric, strings)}',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          // If week, month, or day view, tapping navigates to that day's DailyStatsScreen
                          if (_selectedPeriod == AnalyticsPeriod.day ||
                              _selectedPeriod == AnalyticsPeriod.week ||
                              _selectedPeriod == AnalyticsPeriod.month) {
                            HapticFeedback.lightImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DailyStatsScreen(
                                  controller: widget.controller,
                                  date: bucket.date,
                                  themeController: themeController,
                                  localeController: localeController,
                                ),
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (hasValue)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _formatMetricValue(bucket.value, _selectedMetric, strings),
                                    style: TextStyle(
                                      color: bucket.isHighlighted ? theme.primary : theme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                )
                              else
                                const SizedBox(height: 12),
                              const SizedBox(height: 4),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 110 * ratio,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: hasValue
                                          ? (bucket.isHighlighted
                                              ? theme.primary
                                              : theme.primary.withValues(alpha: 0.6))
                                          : theme.surfaceContainer,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                                      boxShadow: hasValue && bucket.isHighlighted
                                          ? [
                                              BoxShadow(
                                                color: theme.primary.withValues(alpha: 0.4),
                                                blurRadius: 8,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  bucket.label,
                                  style: TextStyle(
                                    color: bucket.isHighlighted ? theme.primary : theme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: bucket.isHighlighted ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalRecordsCard(
    PersonalRecords records,
    AppThemeTokens theme,
    AppStrings strings,
    ThemeController themeController,
    LocaleController localeController,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                strings.recordsSectionTitle,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Longest Ride
          _buildRecordItem(
            title: strings.recordLongestRide,
            icon: Icons.straighten_rounded,
            accentColor: theme.primary,
            value: records.longestRide != null
                ? '${records.longestRide!.distanceKm.toStringAsFixed(1)} ${strings.kmUnit}'
                : '--',
            subtitle: records.longestRide != null
                ? strings.formatDateShort(records.longestRide!.startTime)
                : strings.noDataForPeriod,
            theme: theme,
            strings: strings,
            onTap: records.longestRide != null
                ? () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RideDetailsScreen(
                          ride: records.longestRide!,
                          themeController: themeController,
                          localeController: localeController,
                        ),
                      ),
                    );
                  }
                : null,
          ),

          const SizedBox(height: 10),

          // 2. Fastest Ride
          _buildRecordItem(
            title: strings.recordFastestRide,
            icon: Icons.speed_rounded,
            accentColor: const Color(0xFF06B6D4),
            value: records.fastestRide != null
                ? '${records.fastestRide!.avgSpeedKmh.toStringAsFixed(1)} ${strings.kmhUnit}'
                : '--',
            subtitle: records.fastestRide != null
                ? '${strings.formatDateShort(records.fastestRide!.startTime)} (${records.fastestRide!.distanceKm.toStringAsFixed(1)} ${strings.kmUnit})'
                : strings.noDataForPeriod,
            theme: theme,
            strings: strings,
            onTap: records.fastestRide != null
                ? () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RideDetailsScreen(
                          ride: records.fastestRide!,
                          themeController: themeController,
                          localeController: localeController,
                        ),
                      ),
                    );
                  }
                : null,
          ),

          const SizedBox(height: 10),

          // 3. Most Active Day
          _buildRecordItem(
            title: strings.recordMostActiveDay,
            icon: Icons.local_fire_department_rounded,
            accentColor: const Color(0xFFF43F5E),
            value: records.mostActiveDayDistanceKm > 0
                ? '${records.mostActiveDayDistanceKm.toStringAsFixed(1)} ${strings.kmUnit}'
                : '--',
            subtitle: records.mostActiveDayDate != null
                ? strings.formatDateShort(records.mostActiveDayDate!)
                : strings.noDataForPeriod,
            theme: theme,
            strings: strings,
            onTap: records.mostActiveDayDate != null
                ? () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DailyStatsScreen(
                          controller: widget.controller,
                          date: records.mostActiveDayDate!,
                          themeController: themeController,
                          localeController: localeController,
                        ),
                      ),
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildRecordItem({
    required String title,
    required IconData icon,
    required Color accentColor,
    required String value,
    required String subtitle,
    required AppThemeTokens theme,
    required AppStrings strings,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (onTap != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.isArabic ? 'عرض' : 'View',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_ios_rounded, size: 8, color: theme.textSecondary),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTimeOdometerCard(AppThemeTokens theme, AppStrings strings) {
    final double totalKm = widget.controller.totalKilometers;
    final int totalRides = widget.controller.ridesHistory.length;
    final int totalSeconds = widget.controller.ridesHistory.fold<int>(0, (s, r) => s + r.durationSeconds);
    final int totalHours = totalSeconds ~/ 3600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: theme.isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
              : [theme.surface, theme.surfaceContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.primary.withValues(alpha: 0.1),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.av_timer_rounded, color: theme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.allTimeOdometer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'LIFETIME',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Digital Odometer Readout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ODO',
                  style: TextStyle(
                    color: theme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  '${totalKm.toStringAsFixed(1)} ${strings.kmUnit}',
                  style: TextStyle(
                    color: theme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text(
                    '$totalRides',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    strings.metricRideCount,
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              Container(width: 1, height: 24, color: theme.cardBorder),
              Column(
                children: [
                  Text(
                    '$totalHours',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    strings.isArabic ? 'ساعات ركوب' : 'Riding Hours',
                    style: TextStyle(color: theme.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
