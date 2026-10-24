import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/ride_controller.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class LiveRideScreen extends StatefulWidget {
  final RideController controller;
  final ThemeController? themeController;

  const LiveRideScreen({
    super.key,
    required this.controller,
    this.themeController,
  });

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  LatLng? _lastCenteredPoint;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerUpdate);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Run 120Hz smooth pulsing animation on real devices, static value in test suite
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerUpdate);
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _recenterMap({LatLng? point, double? zoom}) {
    if (!mounted || !_isMapReady) return;
    final pos = widget.controller.currentPosition;
    final target = point ??
        (pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : (widget.controller.routePoints.isNotEmpty
                ? widget.controller.routePoints.last
                : null));

    if (target != null) {
      if (_lastCenteredPoint == null ||
          _lastCenteredPoint!.latitude != target.latitude ||
          _lastCenteredPoint!.longitude != target.longitude ||
          zoom != null) {
        _lastCenteredPoint = target;
        try {
          _mapController.move(target, zoom ?? _mapController.camera.zoom);
        } catch (_) {}
      }
    }
  }

  void _onControllerUpdate() {
    if (!mounted || !_isMapReady) return;
    _recenterMap();
  }

  String _formatTimer(int totalSeconds) {
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
    final theme =
        widget.themeController?.currentTheme ?? AppTheme.galaxyRl600h;
    final oledBlack = theme.background;
    final cardSurface = theme.surface;
    final neonLime = theme.primary;
    final stopRed = theme.error;

    final topInset = MediaQuery.of(context).padding.top;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final pos = widget.controller.currentPosition;
        final currentLatLng = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : (widget.controller.routePoints.isNotEmpty
                ? widget.controller.routePoints.last
                : const LatLng(30.0444, 31.2357));

        return Scaffold(
          backgroundColor: oledBlack,
          extendBodyBehindAppBar: true,
          body: Stack(
            children: [
              // 1. TOP 55%: Live Dark Radar Map bleeding behind Dynamic Island
              Positioned.fill(
                bottom: MediaQuery.of(context).size.height * 0.44,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: currentLatLng,
                    initialZoom: 16.5,
                    onMapReady: () {
                      setState(() {
                        _isMapReady = true;
                      });
                      _recenterMap();
                    },
                  ),
                  children: [
                    // OpenStreetMap Tile Layer with dark ColorFilter.matrix provided via theme.mapColorFilter (no API key needed)
                    ColorFiltered(
                      colorFilter: theme.mapColorFilter,
                      child: TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png?v=probike2',
                        subdomains: const [],
                        userAgentPackageName: 'com.probike.tracker',
                        errorTileCallback: (tile, error, stackTrace) {
                          // Silently handle tile loading errors (no misleading messages)
                        },
                      ),
                    ),
                    // Two-layer neon route rendered only after two accepted points
                    if (widget.controller.routePoints.length >= 2)
                      PolylineLayer(
                        polylines: [
                          // Background glow layer
                          Polyline(
                            points: widget.controller.routePoints,
                            strokeWidth: 8.0,
                            color: theme.polylineGlow,
                          ),
                          // Foreground crisp core layer
                          Polyline(
                            points: widget.controller.routePoints,
                            strokeWidth: 4.0,
                            color: theme.polylineCore,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // 12x12 Start dot marker (rendered when at least 1 route point exists)
                        if (widget.controller.routePoints.isNotEmpty)
                          Marker(
                            point: widget.controller.routePoints.first,
                            width: 12,
                            height: 12,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: neonLime,
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: neonLime.withValues(alpha: 0.8),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Compact 42x42 dark navigation puck with lime border/pulse for live position
                        if (pos != null)
                          Marker(
                            point: currentLatLng,
                            width: 42,
                            height: 42,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: cardSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: neonLime,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: neonLime.withValues(
                                          alpha: _pulseAnimation.value * 0.6,
                                        ),
                                        blurRadius: 12 * _pulseAnimation.value,
                                        spreadRadius: 2 * _pulseAnimation.value,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.directions_bike,
                                      size: 20,
                                      color: neonLime,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    RichAttributionWidget(
                      animationConfig: const ScaleRAWA(),
                      attributions: [
                        TextSourceAttribution(
                          '© OpenStreetMap contributors',
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Floating Top Controls (Dynamic Island Safe: topInset + 10)
              Positioned(
                top: topInset + 10,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Glass Back Button
                    _buildGlassCircleButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                    ),

                    // Pill-shaped Dynamic Island Clearance Badge (Responsive & Overflow-proof)
                    Flexible(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0D0F17).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: neonLime.withValues(alpha: 0.35),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (context, _) {
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: neonLime.withValues(
                                          alpha: _pulseAnimation.value),
                                      boxShadow: [
                                        BoxShadow(
                                          color: neonLime.withValues(
                                              alpha:
                                                  _pulseAnimation.value * 0.8),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                '🟢 LIVE GPS TRACKING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Glass Recenter Button
                    _buildGlassCircleButton(
                      icon: Icons.my_location_rounded,
                      iconColor: neonLime,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (_isMapReady) {
                          _recenterMap(zoom: 17.0);
                        }
                      },
                    ),
                  ],
                ),
              ),

              // 3. BOTTOM 45%: Glassmorphic Cockpit Panel overlapping the map
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height * 0.46,
                    maxHeight: MediaQuery.of(context).size.height * 0.58,
                  ),
                  decoration: BoxDecoration(
                    color: oledBlack,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: neonLime.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.8),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.fromLTRB(
                    18,
                    14,
                    18,
                    bottomInset + 16, // Home Indicator safe
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      // Subtitle & Grab Handle
                      Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Giant Digital Timer with Tabular Figures
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _formatTimer(widget.controller.durationSeconds),
                              style: TextStyle(
                                color: neonLime,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                                letterSpacing: 2.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          Text(
                            'مدة الرحلة الحالية',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),

                      // 4 Metric Boxes Grid (FittedBox & Tabular Figures)
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              label: 'المسافة',
                              value: (widget.controller.distanceMeters / 1000.0)
                                  .toStringAsFixed(2),
                              unit: 'كم',
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              label: 'السرعة الآن',
                              value: widget.controller.currentSpeedKmh
                                  .toStringAsFixed(1),
                              unit: 'كم/س',
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                              isHighlighted: true,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              label: 'أقصى سرعة',
                              value: widget.controller.maxSpeedKmh
                                  .toStringAsFixed(1),
                              unit: 'كم/س',
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              label: 'أدنى سرعة',
                              value: widget.controller.minSpeedKmh
                                  .toStringAsFixed(1),
                              unit: 'كم/س',
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                        ],
                      ),

                      // Massive Crimson Red STOP RIDE button
                      ElevatedButton(
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          HapticFeedback.vibrate();
                          await widget.controller.stopRide();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: stopRed,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(56),
                          elevation: 10,
                          shadowColor: stopRed.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.stop_circle_rounded,
                                  color: Colors.white, size: 28),
                              SizedBox(width: 10),
                              Text(
                                'إيقاف الرحلة (STOP RIDE)',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
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
          ),
        );
      },
    );
  }

  Widget _buildGlassCircleButton({
    required IconData icon,
    Color iconColor = Colors.white,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0F17).withValues(alpha: 0.8),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 20),
        padding: EdgeInsets.zero,
        onPressed: onTap,
      ),
    );
  }

  Widget _buildMetricBox({
    required String label,
    required String value,
    required String unit,
    required Color cardSurface,
    required Color neonLime,
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? neonLime.withValues(alpha: 0.6)
              : Colors.white.withValues(alpha: 0.08),
          width: isHighlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: isHighlighted ? neonLime : Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: TextStyle(
                    color: isHighlighted ? neonLime : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
