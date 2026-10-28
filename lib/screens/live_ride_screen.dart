import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/map_config.dart';
import '../l10n/app_strings.dart';
import '../l10n/locale_controller.dart';
import '../services/ride_controller.dart';
import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class LiveRideScreen extends StatefulWidget {
  final RideController controller;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const LiveRideScreen({
    super.key,
    required this.controller,
    this.themeController,
    this.localeController,
  });

  @override
  State<LiveRideScreen> createState() => _LiveRideScreenState();
}

class _LiveRideScreenState extends State<LiveRideScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  bool _isMapReady = false;
  LatLng? _lastCenteredPoint;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _holdController;
  bool _isHoldingStop = false;
  final GlobalKey _holdButtonKey = GlobalKey();

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

    // 900ms Hold-to-Stop controller
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _holdController.addStatusListener((status) async {
      if (status == AnimationStatus.completed && _isHoldingStop) {
        _isHoldingStop = false;
        HapticFeedback.heavyImpact();
        HapticFeedback.vibrate();
        await widget.controller.stopRide();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    });

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
    _holdController.dispose();
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
    final effectiveLocaleController =
        widget.localeController ?? LocaleController();
    final strings = effectiveLocaleController.strings;
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

        return Directionality(
          textDirection: effectiveLocaleController.textDirection,
          child: Scaffold(
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
                    backgroundColor: theme.background,
                    onMapReady: () {
                      setState(() {
                        _isMapReady = true;
                      });
                      _recenterMap();
                    },
                  ),
                  children: [
                    // Native Dark Stadia Alidade Smooth Dark Tile Layer with keepBuffer: 4 and panBuffer: 2
                    StadiaMapConfig.buildTileLayer(),
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
                        // Compact 42x42 dark navigation puck with lime/amber border for live position
                        if (pos != null)
                          Marker(
                            point: currentLatLng,
                            width: 42,
                            height: 42,
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                final isPaused = widget.controller.isPaused;
                                final puckColor = isPaused ? const Color(0xFFF59E0B) : neonLime;
                                final pulseAlpha = isPaused ? 0.35 : _pulseAnimation.value * 0.6;
                                return Container(
                                  decoration: BoxDecoration(
                                    color: cardSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: puckColor,
                                      width: 2.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: puckColor.withValues(alpha: pulseAlpha),
                                        blurRadius: 12 * (isPaused ? 0.7 : _pulseAnimation.value),
                                        spreadRadius: 2 * (isPaused ? 0.5 : _pulseAnimation.value),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.directions_bike,
                                      size: 20,
                                      color: puckColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                    const StadiaAttributionWidget(
                      alignment: Alignment.bottomRight,
                      margin: EdgeInsets.only(bottom: 8, right: 8),
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
                            color: widget.controller.isPaused
                                ? const Color(0xFFF59E0B).withValues(alpha: 0.55)
                                : neonLime.withValues(alpha: 0.35),
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
                                  final isPaused = widget.controller.isPaused;
                                  final badgeColor = isPaused ? const Color(0xFFF59E0B) : neonLime;
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isPaused
                                          ? const Color(0xFFF59E0B)
                                          : neonLime.withValues(alpha: _pulseAnimation.value),
                                      boxShadow: [
                                        BoxShadow(
                                          color: badgeColor.withValues(
                                              alpha: isPaused ? 0.8 : _pulseAnimation.value * 0.8),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.controller.isPaused
                                    ? '⏸️ ${strings.liveStatusPaused}'
                                    : '🟢 ${strings.liveGpsLocked}',
                                style: const TextStyle(
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
                        color: widget.controller.isPaused
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.45)
                            : neonLime.withValues(alpha: 0.25),
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
                                color: widget.controller.isPaused
                                    ? const Color(0xFFF59E0B)
                                    : neonLime,
                                fontSize: 46,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'Courier',
                                letterSpacing: 2.0,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ),
                          if (widget.controller.isPaused)
                            Container(
                              margin: const EdgeInsets.only(top: 2, bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                ),
                              ),
                              child: Text(
                                strings.liveStatusPaused,
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            )
                          else
                            Text(
                              strings.liveTimeElapsed,
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
                              label: strings.liveDistanceCrushed,
                              value: (widget.controller.distanceMeters / 1000.0)
                                   .toStringAsFixed(2),
                              unit: strings.kmUnit,
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              label: strings.liveCurrentSpeed,
                              value: widget.controller.currentSpeedKmh
                                  .toStringAsFixed(1),
                              unit: strings.kmhUnit,
                              cardSurface: cardSurface,
                              neonLime: widget.controller.isPaused
                                  ? const Color(0xFFF59E0B)
                                  : neonLime,
                              isHighlighted: true,
                            ),
                          ),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricBox(
                              label: strings.liveMaxSpeed,
                              value: widget.controller.maxSpeedKmh
                                  .toStringAsFixed(1),
                              unit: strings.kmhUnit,
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildMetricBox(
                              label: strings.liveMinSpeed,
                              value: widget.controller.minSpeedKmh
                                  .toStringAsFixed(1),
                              unit: strings.kmhUnit,
                              cardSurface: cardSurface,
                              neonLime: neonLime,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Dual Action Controls (Pause/Resume & Hold-to-Stop)
                      Row(
                        children: [
                          // 1. Pause / Resume Button
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (widget.controller.isPaused) {
                                  await widget.controller.resumeRide();
                                } else {
                                  await widget.controller.pauseRide();
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.controller.isPaused
                                    ? const Color(0xFF10B981) // Vivid Emerald Green
                                    : const Color(0xFFF59E0B), // Caution Amber
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                elevation: 8,
                                shadowColor: (widget.controller.isPaused
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B))
                                    .withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      widget.controller.isPaused
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.pause_circle_filled_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      widget.controller.isPaused
                                          ? strings.liveResumeButton
                                          : strings.livePauseButton,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // 2. Hold-to-Stop Button (900ms)
                          Expanded(
                            child: _buildHoldToStopButton(strings, stopRed),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildHoldToStopButton(AppStrings strings, Color stopRed) {
    return Semantics(
      button: true,
      enabled: true,
      label: '${strings.liveFinishButton}: ${strings.liveHoldToStopNotice}',
      onLongPress: () async {
        HapticFeedback.heavyImpact();
        await widget.controller.stopRide();
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Listener(
        key: _holdButtonKey,
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _isHoldingStop = true;
          HapticFeedback.selectionClick();
          _holdController.forward();
        },
        onPointerMove: (event) {
          if (!_isHoldingStop) return;
          final renderBox =
              _holdButtonKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final local = renderBox.globalToLocal(event.position);
            final bounds = Rect.fromLTWH(
              -8,
              -8,
              renderBox.size.width + 16,
              renderBox.size.height + 16,
            );
            if (!bounds.contains(local)) {
              _isHoldingStop = false;
              if (_holdController.status != AnimationStatus.completed) {
                _holdController.reverse();
              }
            }
          }
        },
        onPointerUp: (event) {
          final renderBox =
              _holdButtonKey.currentContext?.findRenderObject() as RenderBox?;
          if (renderBox != null) {
            final local = renderBox.globalToLocal(event.position);
            final bounds = Rect.fromLTWH(
              -8,
              -8,
              renderBox.size.width + 16,
              renderBox.size.height + 16,
            );
            if (!bounds.contains(local)) {
              _isHoldingStop = false;
            }
          }
          if (_holdController.status != AnimationStatus.completed) {
            _isHoldingStop = false;
            _holdController.reverse();
          }
        },
        onPointerCancel: (_) {
          _isHoldingStop = false;
          if (_holdController.status != AnimationStatus.completed) {
            _holdController.reverse();
          }
        },
        child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) {
          final progress = _holdController.value;
          return Container(
            height: 56,
            decoration: BoxDecoration(
              color: stopRed,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: stopRed.withValues(alpha: 0.5),
                  blurRadius: 10 + (progress * 6),
                  spreadRadius: progress * 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress fill background
                  if (progress > 0.0)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: progress,
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.28),
                        ),
                      ),
                    ),
                  // Button Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  value: progress > 0 ? progress : 0,
                                  strokeWidth: 2.5,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const Icon(
                                Icons.stop_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.liveFinishButton,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              Text(
                                strings.liveHoldToStopNotice,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
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
        icon: icon == Icons.arrow_back_ios_new_rounded
            ? Transform.flip(
                flipX: Directionality.of(context) == TextDirection.rtl,
                child: Icon(icon, color: iconColor, size: 20),
              )
            : Icon(icon, color: iconColor, size: 20),
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
