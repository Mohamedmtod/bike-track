import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/map_config.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../models/ride_model.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class RideDetailsScreen extends StatelessWidget {
  final RideModel ride;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const RideDetailsScreen({
    super.key,
    required this.ride,
    this.themeController,
    this.localeController,
  });

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = themeController?.currentTheme ?? AppTheme.galaxyRl600h;
    final effectiveLocaleController = localeController ?? LocaleController();
    final AppStrings strings = effectiveLocaleController.strings;
    final oledBlack = theme.background;
    final cardSurface = theme.surface;
    final neonLime = theme.primary;
    final stopRed = theme.error;
    final cardBorder = theme.cardBorder;
    final textPrimary = theme.textPrimary;
    final textSecondary = theme.textSecondary;

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final hasRoute = ride.routePoints.isNotEmpty;

    // Compute initial camera options
    final MapOptions mapOptions;
    if (ride.routePoints.length >= 2) {
      mapOptions = MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(ride.routePoints),
          padding: const EdgeInsets.all(48),
        ),
        backgroundColor: theme.background,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      );
    } else if (ride.routePoints.length == 1) {
      mapOptions = MapOptions(
        initialCenter: ride.routePoints.first,
        initialZoom: 16.0,
        backgroundColor: theme.background,
      );
    } else {
      mapOptions = MapOptions(
        initialCenter: const LatLng(30.0444, 31.2357),
        initialZoom: 13.0,
        backgroundColor: theme.background,
      );
    }

    final distanceKm = ride.distanceMeters / 1000.0;
    final dateFormatted = strings.formatDateTime(ride.startTime);
    final isSynced = ride.syncStatus == SyncStatus.synced;

    return Directionality(
      textDirection: effectiveLocaleController.textDirection,
      child: Scaffold(
        backgroundColor: oledBlack,
        extendBodyBehindAppBar: true,
        body: Stack(
        children: [
          // 1. TOP 50%: Dark Stadia Alidade Smooth Dark Map with Glowing Neon Polyline
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.50,
            child: Stack(
              children: [
                FlutterMap(
                  options: mapOptions,
                  children: [
                    // Native Dark Stadia Tile Layer with keepBuffer: 4 and panBuffer: 2
                    StadiaMapConfig.buildTileLayer(),

                    // Multi-layer glowing theme polyline
                    if (hasRoute) ...[
                      // Glow outer polyline
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: ride.routePoints,
                            strokeWidth: 8.0,
                            color: theme.polylineGlow,
                          ),
                          // Core sharp polyline
                          Polyline(
                            points: ride.routePoints,
                            strokeWidth: 4.0,
                            color: theme.polylineCore,
                          ),
                        ],
                      ),

                      // Start and End Point Markers
                      MarkerLayer(
                        markers: [
                          // Start marker (Theme Primary / Green dot)
                          Marker(
                            point: ride.routePoints.first,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.primary.withValues(alpha: 0.6),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Finish marker (Red dot if more than 1 point)
                          if (ride.routePoints.length > 1)
                            Marker(
                              point: ride.routePoints.last,
                              width: 22,
                              height: 22,
                              child: Container(
                              decoration: BoxDecoration(
                                  color: stopRed,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: stopRed.withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const StadiaAttributionWidget(
                      alignment: Alignment.bottomRight,
                      margin: EdgeInsets.only(bottom: 40, right: 8),
                    ),
                  ],
                ),

                // Subtle fallback badge if no GPS route points exist
                if (!hasRoute)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        color: cardSurface.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 16,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ride.isManual ? Icons.edit_note_rounded : Icons.location_off_outlined,
                            color: neonLime,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              ride.isManual
                                  ? strings.manualRideNoMap
                                  : strings.noRoutePointsNotice,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom gradient fading into lower container
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 36,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          oledBlack.withValues(alpha: 0.0),
                          oledBlack,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. BOTTOM 50%: Glassmorphic Metrics Cockpit
          Positioned(
            top: MediaQuery.of(context).size.height * 0.48,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: oledBlack,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: cardBorder),
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(16, 18, 16, bottomInset + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Pull indicator bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Date & Sync Status Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, color: textSecondary.withValues(alpha: 0.6), size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dateFormatted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
                              if (ride.isOvernight) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: Text(
                                    strings.overnightRideBadge,
                                    style: const TextStyle(
                                      color: Color(0xFFA5B4FC),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSynced
                                ? const Color(0xFF0D381E)
                                : Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSynced
                                  ? const Color(0xFF1B5E20)
                                  : Colors.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSynced ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined,
                                color: isSynced ? const Color(0xFF00E676) : Colors.amber,
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSynced ? strings.syncStatusSynced : strings.syncStatusPending,
                                style: TextStyle(
                                  color: isSynced ? const Color(0xFF00E676) : Colors.amber,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Hero Distance Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardSurface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.heroDistanceTitle,
                                style: TextStyle(
                                  color: textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    distanceKm.toStringAsFixed(2),
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      fontFeatures: const [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.kmUnit,
                                    style: TextStyle(
                                      color: neonLime,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: neonLime.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: neonLime.withValues(alpha: 0.3)),
                            ),
                            child: Icon(
                              Icons.directions_bike_rounded,
                              color: neonLime,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Cockpit Grid: 4 Metric Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.timer_outlined,
                            iconColor: const Color(0xFF00E676),
                            label: strings.metricTotalTime,
                            value: _formatDuration(ride.durationSeconds),
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.speed_rounded,
                            iconColor: const Color(0xFF29B6F6),
                            label: strings.metricAvgSpeed,
                            value: strings.speedValue(ride.avgSpeedKmh),
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.bolt_rounded,
                            iconColor: neonLime,
                            label: strings.metricMaxSpeed,
                            value: strings.speedValue(ride.maxSpeedKmh),
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.arrow_downward_rounded,
                            iconColor: const Color(0xFFFFB74D),
                            label: strings.metricMinSpeed,
                            value: strings.speedValue(ride.minSpeedKmh),
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                      ],
                    ),

                    if (ride.isManual) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: neonLime, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                strings.manualRideNotice,
                                style: TextStyle(color: textSecondary, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // 3. TOP APP BAR: Glassmorphic Floating Header with Back Button
          Positioned(
            top: topInset + 8,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Frosted Glass Back Button
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cardSurface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: IconButton(
                        icon: Transform.flip(
                          flipX: Directionality.of(context) == TextDirection.rtl,
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: textPrimary,
                            size: 18,
                          ),
                        ),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ),
                ),

                // Floating Title Pill
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: cardSurface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Text(
                        strings.rideDetailsTitle,
                        style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),

                // Spacer balance for symmetric centering
                const SizedBox(width: 48),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color cardSurface,
    required Color cardBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
