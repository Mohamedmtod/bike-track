import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../models/ride_model.dart';

class RideDetailsScreen extends StatelessWidget {
  final RideModel ride;

  const RideDetailsScreen({super.key, required this.ride});

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
    const oledBlack = Color(0xFF090A0F);
    const cardSurface = Color(0xFF14161F);
    const neonLime = Color(0xFFCCFF00);
    const stopRed = Color(0xFFFF2D55);
    final cardBorder = Colors.white.withValues(alpha: 0.08);

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
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all,
        ),
      );
    } else if (ride.routePoints.length == 1) {
      mapOptions = MapOptions(
        initialCenter: ride.routePoints.first,
        initialZoom: 16.0,
      );
    } else {
      mapOptions = const MapOptions(
        initialCenter: LatLng(30.0444, 31.2357),
        initialZoom: 13.0,
      );
    }

    final distanceKm = ride.distanceMeters / 1000.0;
    final dateFormatted = DateFormat('yyyy/MM/dd • hh:mm a').format(ride.startTime.toLocal());
    final isSynced = ride.syncStatus == SyncStatus.synced;

    return Scaffold(
      backgroundColor: oledBlack,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. TOP 50%: Dark OLED OpenStreetMap with Glowing Neon Polyline
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
                    // High-contrast Dark OLED Tile Layer
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        -0.85,  0.0,   0.0,   0.0, 215.0,
                         0.0,  -0.85,  0.0,   0.0, 220.0,
                         0.0,   0.0,  -0.80,  0.0, 235.0,
                         0.0,   0.0,   0.0,   1.0,   0.0,
                      ]),
                      child: TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png?v=probike2',
                        subdomains: const [],
                        userAgentPackageName: 'com.probike.tracker',
                        errorTileCallback: (tile, error, stackTrace) {},
                      ),
                    ),

                    // Multi-layer glowing neon polyline
                    if (hasRoute) ...[
                      // Glow outer polyline
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: ride.routePoints,
                            strokeWidth: 7.0,
                            color: neonLime.withValues(alpha: 0.35),
                          ),
                          // Core sharp polyline
                          Polyline(
                            points: ride.routePoints,
                            strokeWidth: 3.5,
                            color: neonLime,
                          ),
                        ],
                      ),

                      // Start and End Point Markers
                      MarkerLayer(
                        markers: [
                          // Start marker (Green dot)
                          Marker(
                            point: ride.routePoints.first,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E676).withValues(alpha: 0.6),
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
                            color: Colors.black.withValues(alpha: 0.5),
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
                          Text(
                            ride.isManual
                                ? 'رحلة يدوية - لا توجد بيانات مسار خريطة'
                                : 'لا تتوفر إحداثيات خريطة لهذه الرحلة',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
                          color: Colors.white.withValues(alpha: 0.2),
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
                              Icon(Icons.calendar_today_rounded, color: Colors.white38, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  dateFormatted,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ),
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
                                isSynced ? 'متزامن سحابياً' : 'قيد المزامنة',
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
                            color: Colors.black.withValues(alpha: 0.4),
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
                              const Text(
                                'إجمالي المسافة',
                                style: TextStyle(
                                  color: Colors.white54,
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1.0,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'كم',
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
                            label: 'الوقت الإجمالي',
                            value: _formatDuration(ride.durationSeconds),
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.speed_rounded,
                            iconColor: const Color(0xFF29B6F6),
                            label: 'متوسط السرعة',
                            value: '${ride.avgSpeedKmh.toStringAsFixed(1)} كم/س',
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
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
                            label: 'أقصى سرعة',
                            value: '${ride.maxSpeedKmh.toStringAsFixed(1)} كم/س',
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricTile(
                            icon: Icons.arrow_downward_rounded,
                            iconColor: const Color(0xFFFFB74D),
                            label: 'أدنى سرعة',
                            value: '${ride.minSpeedKmh.toStringAsFixed(1)} كم/س',
                            cardSurface: cardSurface,
                            cardBorder: cardBorder,
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
                            const Expanded(
                              child: Text(
                                'تمت إضافة هذه الرحلة يدوياً كتعويض عن رحلة سابقة غير مسجلة.',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
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
                        color: const Color(0xFF14161F).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 18,
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
                        color: const Color(0xFF14161F).withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Text(
                        'تفاصيل الرحلة',
                        style: TextStyle(
                          color: Colors.white,
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
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required Color cardSurface,
    required Color cardBorder,
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
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
