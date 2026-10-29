import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:bike_track/config/map_config.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/models/analytics_models.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/screens/ride_details_screen.dart';
import 'package:bike_track/services/ride_controller.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:bike_track/widgets/daily_share_card.dart';

class DailyStatsScreen extends StatefulWidget {
  final RideController controller;
  final DateTime date;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const DailyStatsScreen({
    super.key,
    required this.controller,
    required this.date,
    this.themeController,
    this.localeController,
  });

  @override
  State<DailyStatsScreen> createState() => _DailyStatsScreenState();
}

class _DailyStatsScreenState extends State<DailyStatsScreen> {
  final MapController _mapController = MapController();
  final GlobalKey _shareKey = GlobalKey();
  int? _selectedRideIndex;
  bool _isSharing = false;

  static const List<Color> _routeColors = [
    Color(0xFF10B981), // Emerald Neon
    Color(0xFF06B6D4), // Cyan
    Color(0xFFA855F7), // Violet
    Color(0xFFF59E0B), // Amber
    Color(0xFFF43F5E), // Coral
    Color(0xFF3B82F6), // Blue
  ];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _mapController.dispose();
    super.dispose();
  }

  void _onControllerUpdate() {
    if (mounted) setState(() {});
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

  void _fitRouteBounds(DaySummary summary) {
    if (!summary.hasGpsRoutes) return;

    final List<LatLng> targetPoints;
    if (_selectedRideIndex != null &&
        _selectedRideIndex! < summary.rides.length) {
      targetPoints = summary.rides[_selectedRideIndex!].routePoints;
    } else {
      targetPoints = [
        for (final r in summary.rides) ...r.routePoints,
      ];
    }

    if (targetPoints.length >= 2) {
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(targetPoints),
            padding: const EdgeInsets.all(40),
          ),
        );
      } catch (_) {}
    } else if (targetPoints.length == 1) {
      try {
        _mapController.move(targetPoints.first, 15.0);
      } catch (_) {}
    }
  }

  Future<void> _shareDaySummary(DaySummary summary, AppStrings strings) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    HapticFeedback.lightImpact();

    try {
      final pngBytes = await capturePngFromRepaintBoundary(_shareKey);
      if (pngBytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.shareFailedSnackbar),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        return;
      }

      final durMinutes = (summary.totalDurationSeconds / 60).round();
      final shareText = strings.shareDaySummaryText(
        strings.formatDateFull(summary.date),
        summary.totalDistanceKm.toStringAsFixed(1),
        '$durMinutes دقيقة',
      );

      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;

      final success = await widget.controller.shareService.shareImage(
        pngBytes: pngBytes,
        subject: strings.shareDaySummarySubject,
        text: shareText,
        sharePositionOrigin: origin,
      );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.shareFailedSnackbar),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.shareFailedSnackbar),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.themeController?.currentTheme ?? AppTheme.galaxyRl600h;
    final effectiveLocale = widget.localeController ?? LocaleController();
    final strings = effectiveLocale.strings;

    final summary = widget.controller.getDaySummary(
      widget.date,
      includeActiveRide: true,
    );

    // Initial map camera fit
    final MapOptions mapOptions;
    final allGpsPoints = [
      for (final r in summary.rides) ...r.routePoints,
    ];
    if (allGpsPoints.length >= 2) {
      mapOptions = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(allGpsPoints),
          padding: const EdgeInsets.all(40),
        ),
        backgroundColor: theme.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      );
    } else if (allGpsPoints.length == 1) {
      mapOptions = MapOptions(
        initialCenter: allGpsPoints.first,
        initialZoom: 15.0,
        backgroundColor: theme.background,
      );
    } else {
      mapOptions = MapOptions(
        initialCenter: const LatLng(30.0444, 31.2357),
        initialZoom: 13.0,
        backgroundColor: theme.background,
      );
    }

    return Directionality(
      textDirection: effectiveLocale.textDirection,
      child: Scaffold(
        backgroundColor: theme.background,
        appBar: AppBar(
          backgroundColor: theme.surface,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.textPrimary, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.dailyStatsTitle,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                strings.formatDateFull(widget.date),
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              key: const Key('daily_stats_share_button'),
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.ios_share_rounded, color: theme.primary, size: 22),
              tooltip: strings.shareDaySummaryTooltip,
              onPressed: () => _shareDaySummary(summary, strings),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            // Offscreen renderable share card for instant PNG export
            Positioned(
              left: -9999,
              top: -9999,
              child: RepaintBoundary(
                key: _shareKey,
                child: DailyShareCard(
                  summary: summary,
                  strings: strings,
                ),
              ),
            ),

            // Scrollable Content
            ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                // 1. Live Ride Ongoing Notice (if active)
                if (summary.includesActiveRide) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.liveRideIncludedNotice,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // 2. Day Summary Hero Grid
                _buildHeroMetricsGrid(theme, strings, summary),

                const SizedBox(height: 20),

                // 3. Unified Map Section (or Rest/Manual card if no GPS points)
                if (summary.hasGpsRoutes) ...[
                  _buildUnifiedMapCard(theme, strings, summary, mapOptions),
                ] else ...[
                  _buildRestOrManualCard(theme, strings, summary),
                ],

                const SizedBox(height: 24),

                // 4. Day's Rides List
                Row(
                  children: [
                    Icon(Icons.directions_bike_rounded, color: theme.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.dayRidesListTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.cardBorder),
                      ),
                      child: Text(
                        strings.dayRidesCountText(summary.rideCount),
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                if (summary.rides.isEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.cardBorder),
                    ),
                    child: Center(
                      child: Text(
                        strings.noDataForPeriod,
                        style: TextStyle(color: theme.textSecondary, fontSize: 13),
                      ),
                    ),
                  ),
                ] else ...[
                  for (int i = 0; i < summary.rides.length; i++) ...[
                    _buildRideCard(
                      context,
                      theme,
                      strings,
                      summary.rides[i],
                      i,
                      _routeColors[i % _routeColors.length],
                    ),
                    const SizedBox(height: 10),
                  ],
                ],

                const SizedBox(height: 32),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroMetricsGrid(AppThemeTokens theme, AppStrings strings, DaySummary summary) {
    final durString = _formatDuration(summary.totalDurationSeconds);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            strings.dayHeroSummary,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHeroStatItem(
                  icon: Icons.straighten_rounded,
                  label: strings.dayTotalDistance,
                  value: '${summary.totalDistanceKm.toStringAsFixed(1)} ${strings.kmUnit}',
                  color: theme.primary,
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroStatItem(
                  icon: Icons.timer_outlined,
                  label: strings.dayMovingTime,
                  value: durString,
                  color: const Color(0xFF38BDF8),
                  theme: theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildHeroStatItem(
                  icon: Icons.speed_rounded,
                  label: strings.dayAvgSpeed,
                  value: summary.avgSpeedKmh > 0
                      ? '${summary.avgSpeedKmh.toStringAsFixed(1)} ${strings.kmhUnit}'
                      : '—',
                  color: const Color(0xFFA855F7),
                  theme: theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildHeroStatItem(
                  icon: Icons.bolt_rounded,
                  label: strings.dayMaxSpeed,
                  value: (summary.maxSpeedKmh != null && summary.maxSpeedKmh! > 0)
                      ? '${summary.maxSpeedKmh!.toStringAsFixed(1)} ${strings.kmhUnit}'
                      : '—',
                  color: const Color(0xFFF59E0B),
                  theme: theme,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required AppThemeTokens theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                fontFeatures: const [ui.FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnifiedMapCard(
    AppThemeTokens theme,
    AppStrings strings,
    DaySummary summary,
    MapOptions mapOptions,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Header & Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.map_rounded, color: theme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  strings.dayUnifiedMapTitle,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          // Route Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // "All Routes" Chip
                FilterChip(
                  label: Text('${strings.allRoutesChip} (${summary.allPolylines.length})'),
                  selected: _selectedRideIndex == null,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedRideIndex = null);
                    _fitRouteBounds(summary);
                  },
                  backgroundColor: theme.surfaceContainer,
                  selectedColor: theme.primary.withValues(alpha: 0.2),
                  checkmarkColor: theme.primary,
                  labelStyle: TextStyle(
                    color: _selectedRideIndex == null ? theme.primary : theme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(
                    color: _selectedRideIndex == null ? theme.primary : theme.cardBorder,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                const SizedBox(width: 8),

                // Individual Ride Chips
                for (int i = 0; i < summary.rides.length; i++) ...[
                  if (summary.rides[i].routePoints.length >= 2) ...[
                    FilterChip(
                      avatar: CircleAvatar(
                        backgroundColor: _routeColors[i % _routeColors.length],
                        radius: 5,
                      ),
                      label: Text(
                        strings.rideChipLabel(
                          i + 1,
                          '${summary.rides[i].startTime.toLocal().hour}:${summary.rides[i].startTime.toLocal().minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      selected: _selectedRideIndex == i,
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedRideIndex = i);
                        _fitRouteBounds(summary);
                      },
                      backgroundColor: theme.surfaceContainer,
                      selectedColor: _routeColors[i % _routeColors.length].withValues(alpha: 0.2),
                      checkmarkColor: _routeColors[i % _routeColors.length],
                      labelStyle: TextStyle(
                        color: _selectedRideIndex == i
                            ? _routeColors[i % _routeColors.length]
                            : theme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      side: BorderSide(
                        color: _selectedRideIndex == i
                            ? _routeColors[i % _routeColors.length]
                            : theme.cardBorder,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Map Widget Viewport
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: mapOptions,
                    children: [
                      StadiaMapConfig.buildTileLayer(),

                      // Polylines Layer
                      PolylineLayer(
                        polylines: [
                          for (int i = 0; i < summary.rides.length; i++) ...[
                            if (summary.rides[i].routePoints.length >= 2) ...[
                              _buildMapPolyline(summary.rides[i], i),
                            ],
                          ],
                        ],
                      ),

                      // Markers Layer
                      MarkerLayer(
                        markers: [
                          for (int i = 0; i < summary.rides.length; i++) ...[
                            if (summary.rides[i].routePoints.isNotEmpty) ...[
                              // Start marker
                              Marker(
                                point: summary.rides[i].routePoints.first,
                                width: 18,
                                height: 18,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                              // End marker
                              Marker(
                                point: summary.rides[i].routePoints.last,
                                width: 18,
                                height: 18,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),

                  // Legal Stadia Map Attribution
                  const Positioned(
                    bottom: 6,
                    left: 6,
                    child: StadiaAttributionWidget(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Polyline _buildMapPolyline(RideModel ride, int index) {
    final color = _routeColors[index % _routeColors.length];
    final isSelected = _selectedRideIndex == index;
    final isAnySelected = _selectedRideIndex != null;

    if (isAnySelected && !isSelected) {
      // Dim non-selected polylines
      return Polyline(
        points: ride.routePoints,
        strokeWidth: 2.5,
        color: color.withValues(alpha: 0.25),
      );
    }

    return Polyline(
      points: ride.routePoints,
      strokeWidth: isSelected ? 5.0 : 4.0,
      color: color,
    );
  }

  Widget _buildRestOrManualCard(AppThemeTokens theme, AppStrings strings, DaySummary summary) {
    final isRestDay = summary.rideCount == 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.cardBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isRestDay
                  ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                  : theme.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRestDay ? Icons.self_improvement_rounded : Icons.edit_note_rounded,
              color: isRestDay ? const Color(0xFF38BDF8) : theme.primary,
              size: 38,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            isRestDay ? strings.restDayTitle : strings.noGpsRoutesDayNotice,
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (isRestDay) ...[
            const SizedBox(height: 8),
            Text(
              strings.restDaySubtitle,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRideCard(
    BuildContext context,
    AppThemeTokens theme,
    AppStrings strings,
    RideModel ride,
    int index,
    Color accentColor,
  ) {
    final startTimeLocal = ride.startTime.toLocal();
    final timeStr =
        '${startTimeLocal.hour}:${startTimeLocal.minute.toString().padLeft(2, '0')}';
    final durString = _formatDuration(ride.durationSeconds);
    final distKm = (ride.distanceMeters / 1000.0).toStringAsFixed(1);
    final hasRoute = ride.routePoints.isNotEmpty;

    return GestureDetector(
      key: Key('daily_ride_item_$index'),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RideDetailsScreen(
              ride: ride,
              themeController: widget.themeController,
              localeController: widget.localeController,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.cardBorder),
        ),
        child: Row(
          children: [
            // Left color pill indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 14),

            // Time & Ride #
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '#${index + 1} • $timeStr',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (ride.isOvernight) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            strings.overnightRideBadge,
                            style: const TextStyle(
                              color: Color(0xFFA5B4FC),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (!hasRoute) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'يدوية',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$distKm ${strings.kmUnit} • $durString',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Avg Speed
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ride.avgSpeedKmh > 0
                      ? '${ride.avgSpeedKmh.toStringAsFixed(1)} ${strings.kmhUnit}'
                      : '—',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: theme.textSecondary.withValues(alpha: 0.6),
                  size: 14,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
