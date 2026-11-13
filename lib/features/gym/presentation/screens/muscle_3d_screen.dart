import 'dart:convert';
import 'dart:io';

import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:bike_track/features/gym/services/gym_heatmap_service.dart';
import 'package:bike_track/l10n/app_strings.dart';
import 'package:bike_track/l10n/locale_controller.dart';
import 'package:bike_track/theme/app_theme.dart';
import 'package:bike_track/theme/theme_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum MuscleViewMode {
  explore, // Touch & scrub to select muscles (<0.4ms BVH raycast)
  orbit, // 360 rotation & pinch-zoom (controls enabled, raycasting paused)
}

enum CameraAngle { front, back }

class Muscle3DScreen extends StatefulWidget {
  final GymDatabaseService? dbService;
  final GymHeatmapService? heatmapService;
  final InAppLocalhostServer? customServer;
  final WidgetBuilder? customWebViewBuilder;
  final String? initialSelectedMuscle;
  final ThemeController? themeController;
  final LocaleController? localeController;

  const Muscle3DScreen({
    super.key,
    this.dbService,
    this.heatmapService,
    this.customServer,
    this.customWebViewBuilder,
    this.initialSelectedMuscle,
    this.themeController,
    this.localeController,
  });

  @override
  State<Muscle3DScreen> createState() => _Muscle3DScreenState();
}

class _Muscle3DScreenState extends State<Muscle3DScreen> {
  late final GymDatabaseService _dbService;
  late final MuscleRepository _muscleRepo;
  late final GymHeatmapService _heatmapService;

  InAppLocalhostServer? _localhostServer;
  InAppWebViewController? _webViewController;

  bool _isServerRunning = false;
  bool _isModelReady = false;

  MuscleViewMode _currentMode = MuscleViewMode.explore;
  CameraAngle _currentAngle = CameraAngle.front;

  bool _isHeatmapActive = false;
  bool _isLoadingHeatmap = false;
  bool _isDiagnosticsHudActive = false;
  Map<String, MuscleFatigueScore> _fatigueScores = {};
  String _selectedCategory = 'all';

  List<Muscle> _allMuscles = [];
  Map<String, Muscle> _musclesById = {};

  // Currently highlighted or selected muscle details
  String? _hoveredMuscleGroup;
  String? _hoveredRegionLabel;
  Muscle? _selectedMuscle;

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _muscleRepo = MuscleRepository(dbService: _dbService);
    _heatmapService =
        widget.heatmapService ?? GymHeatmapService(dbService: _dbService);
    _loadMuscles();
    _initLocalServer();
  }

  List<Muscle> get _filteredMuscles {
    if (_selectedCategory == 'all') return _allMuscles;
    return _allMuscles.where((m) {
      final reg = m.anatomyRegion.toLowerCase();
      switch (_selectedCategory) {
        case 'chest':
          return reg.contains('chest');
        case 'back':
          return reg.contains('back');
        case 'legs':
          return reg.contains('thigh') ||
              reg.contains('leg') ||
              reg.contains('hip');
        case 'arms':
          return reg.contains('arm') || reg.contains('forearm');
        case 'shoulders':
          return reg.contains('shoulder');
        case 'core':
          return reg.contains('core');
        default:
          return true;
      }
    }).toList();
  }

  Future<void> _toggleHeatmap() async {
    HapticFeedback.mediumImpact();
    if (_isHeatmapActive) {
      setState(() {
        _isHeatmapActive = false;
        _fatigueScores = {};
      });
      _webViewController?.evaluateJavascript(
        source: 'window.clearMuscleHeatmap();',
      );
      return;
    }

    setState(() {
      _isLoadingHeatmap = true;
    });

    try {
      final scores = await _heatmapService.computeMuscleFatigueScores();
      final colorMap = {
        for (final e in scores.entries) e.key: e.value.hexColor,
      };

      if (mounted) {
        setState(() {
          _isHeatmapActive = true;
          _isLoadingHeatmap = false;
          _fatigueScores = scores;
        });
      }

      _webViewController?.evaluateJavascript(
        source: 'window.applyMuscleHeatmap(${jsonEncode(colorMap)});',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingHeatmap = false;
        });
      }
    }
  }

  Future<void> _loadMuscles() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      final list = await _muscleRepo.getAllMuscles();
      final map = {for (final m in list) m.id: m};
      if (mounted) {
        setState(() {
          _allMuscles = list;
          _musclesById = map;
        });
      }
    } catch (_) {}
  }

  Future<void> _initLocalServer() async {
    // In headless test environments or when a custom builder is provided, skip starting server
    if (InAppWebViewPlatform.instance == null ||
        widget.customWebViewBuilder != null) {
      if (mounted) {
        setState(() {
          _isServerRunning = true;
          _isModelReady = true;
        });
      }
      return;
    }

    if (kIsWeb ||
        (!Platform.isIOS &&
            !Platform.isAndroid &&
            !Platform.isMacOS &&
            !Platform.isWindows)) {
      if (mounted) {
        setState(() => _isServerRunning = true);
      }
      return;
    }

    try {
      _localhostServer =
          widget.customServer ??
          InAppLocalhostServer(documentRoot: 'assets/gym', port: 8080);

      if (!_localhostServer!.isRunning()) {
        await _localhostServer!.start();
      }

      if (mounted) {
        setState(() => _isServerRunning = true);
      }
    } catch (e) {
      // If port 8080 is already active or in test, mark running
      if (mounted) {
        setState(() => _isServerRunning = true);
      }
    }
  }

  @override
  void dispose() {
    if (widget.customServer == null &&
        _localhostServer != null &&
        _localhostServer!.isRunning()) {
      _localhostServer!.close();
    }
    super.dispose();
  }

  void _switchMode(MuscleViewMode mode) {
    if (_currentMode == mode) return;
    HapticFeedback.selectionClick();
    setState(() => _currentMode = mode);
    _webViewController?.evaluateJavascript(
      source: "window.setInteractionMode('${mode.name}');",
    );
  }

  void _switchCameraAngle(CameraAngle angle) {
    HapticFeedback.lightImpact();
    setState(() => _currentAngle = angle);
    _webViewController?.evaluateJavascript(
      source: "window.setCameraView('${angle.name}');",
    );
  }

  void _onMuscleSelectedFromUi(String muscleId) {
    HapticFeedback.mediumImpact();
    final muscle = _musclesById[muscleId];
    setState(() {
      _selectedMuscle = muscle;
      _hoveredMuscleGroup = muscleId;
      _hoveredRegionLabel = muscle?.name;
    });

    _webViewController?.evaluateJavascript(
      source: "window.selectMuscle('$muscleId');",
    );
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedMuscle = null;
      _hoveredMuscleGroup = null;
      _hoveredRegionLabel = null;
    });
    _webViewController?.evaluateJavascript(
      source: "window.selectMuscle(null);",
    );
  }

  @override
  Widget build(BuildContext context) {
    final listenable = Listenable.merge([
      if (widget.themeController != null) widget.themeController!,
      if (widget.localeController != null) widget.localeController!,
    ]);

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final theme =
            widget.themeController?.currentTheme ?? AppTheme.of(context);
        final strings =
            widget.localeController?.strings ?? AppStrings.of(context);

        final bgDark = theme.background;
        final cardDark = theme.surface;
        final accentLime = theme.primary;
        final accentCyan = theme.tertiary;

        return Scaffold(
          backgroundColor: bgDark,
          appBar: AppBar(
            backgroundColor: bgDark,
            elevation: 0,
            title: Text(
              strings.isArabic ? 'خريطة العضلات 3D' : '3D Muscle Map',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
            iconTheme: IconThemeData(color: theme.textPrimary),
            actions: [
              // Real-time 120 FPS & Hardware Diagnostics HUD Toggle
              IconButton(
                key: const Key('diagnostics_hud_button'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(
                    () => _isDiagnosticsHudActive = !_isDiagnosticsHudActive,
                  );
                  _webViewController?.evaluateJavascript(
                    source: 'window.toggleDiagnosticsHud();',
                  );
                },
                icon: Icon(
                  Icons.speed_rounded,
                  color: _isDiagnosticsHudActive
                      ? accentLime
                      : theme.textSecondary,
                  size: 21,
                ),
                tooltip: '120 FPS & Diagnostics HUD',
              ),
              // Fatigue Heatmap Toggle
              IconButton(
                key: const Key('heatmap_toggle_button'),
                onPressed: _isLoadingHeatmap ? null : _toggleHeatmap,
                icon: _isLoadingHeatmap
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF9500),
                        ),
                      )
                    : Icon(
                        _isHeatmapActive
                            ? Icons.local_fire_department_rounded
                            : Icons.local_fire_department_outlined,
                        color: _isHeatmapActive
                            ? const Color(0xFFFF453A)
                            : theme.textSecondary,
                        size: 22,
                      ),
                tooltip: 'Fatigue Heatmap',
              ),
              // Front / Back camera toggle button
              TextButton.icon(
                key: const Key('camera_angle_toggle_button'),
                onPressed: () {
                  final next = _currentAngle == CameraAngle.front
                      ? CameraAngle.back
                      : CameraAngle.front;
                  _switchCameraAngle(next);
                },
                icon: Icon(
                  Icons.flip_camera_ios_rounded,
                  color: accentCyan,
                  size: 18,
                ),
                label: Text(
                  _currentAngle == CameraAngle.front
                      ? (strings.isArabic ? 'أمامي' : 'FRONT')
                      : (strings.isArabic ? 'خلفي' : 'BACK'),
                  style: TextStyle(
                    color: accentCyan,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // 1. 3D WebGL Canvas Layer
              if (_isServerRunning)
                _buildWebView(bgDark, accentLime, theme)
              else
                Center(child: CircularProgressIndicator(color: accentLime)),

              // 2. Loading overlay if model is still downloading or parsing
              if (!_isModelReady && _isServerRunning)
                Container(
                  color: bgDark,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: accentLime),
                        const SizedBox(height: 16),
                        Text(
                          strings.loading3dModel,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 3b. Heatmap Legend (docked unobtrusively above bottom controls - unblocks 3D figure)
              if (_isHeatmapActive)
                Positioned(
                  bottom: _selectedMuscle != null ? 245 : 140,
                  left: 20,
                  right: 20,
                  child: Center(child: _buildHeatmapLegend(cardDark)),
                ),

              // 4. Live Hover HUD Banner (docked safely at bottom above controls)
              if (_hoveredRegionLabel != null || _hoveredMuscleGroup != null)
                Positioned(
                  bottom: _selectedMuscle != null
                      ? (_isHeatmapActive ? 290 : 220)
                      : (_isHeatmapActive ? 185 : 135),
                  left: 24,
                  right: 24,
                  child: Center(
                    child: _buildHoverHud(cardDark, accentLime, strings),
                  ),
                ),

              // 5. Bottom Navigation & Action Overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Unobtrusive Mode / Gesture indicator pill docked safely at bottom
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: _buildModeTogglePill(
                        cardDark,
                        accentLime,
                        accentCyan,
                        strings,
                      ),
                    ),
                    // Selected Muscle Action Card (if a muscle was clicked)
                    if (_selectedMuscle != null)
                      _buildSelectedMuscleCard(theme, strings)
                    else
                      // Horizontal Quick Muscle Chips
                      _buildQuickMuscleChips(cardDark, accentLime, strings),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWebView(
    Color bgDark,
    Color accentLime, [
    AppThemeTokens? theme,
  ]) {
    if (widget.customWebViewBuilder != null) {
      return widget.customWebViewBuilder!(context);
    }
    if (InAppWebViewPlatform.instance == null) {
      return Container(key: const Key('muscle_3d_webview'), color: bgDark);
    }
    return InAppWebView(
      key: const Key('muscle_3d_webview'),
      initialUrlRequest: URLRequest(
        url: WebUri('http://localhost:8080/web/index.html'),
      ),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        supportZoom: false,
        isInspectable: kDebugMode,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
      ),
      onWebViewCreated: (controller) {
        _webViewController = controller;

        controller.addJavaScriptHandler(
          handlerName: 'onModelReady',
          callback: (args) {
            if (mounted) {
              setState(() => _isModelReady = true);
              if (theme != null) {
                final hex =
                    '#${theme.background.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                controller.evaluateJavascript(
                  source: "window.setTheme && window.setTheme('$hex');",
                );
              }
              if (widget.initialSelectedMuscle != null) {
                _onMuscleSelectedFromUi(widget.initialSelectedMuscle!);
              }
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onMuscleHovered',
          callback: (args) {
            if (args.isEmpty || args.first == null) {
              if (mounted) {
                setState(() {
                  _hoveredMuscleGroup = null;
                  _hoveredRegionLabel = null;
                });
              }
              return;
            }
            final data = Map<String, dynamic>.from(args.first as Map);
            final group = data['muscleGroup'] as String?;
            final label = data['label'] as String?;

            if (mounted) {
              setState(() {
                _hoveredMuscleGroup = group;
                _hoveredRegionLabel = label;
              });
            }
          },
        );

        controller.addJavaScriptHandler(
          handlerName: 'onMuscleSelected',
          callback: (args) {
            HapticFeedback.mediumImpact();
            if (args.isEmpty || args.first == null) {
              if (mounted) {
                setState(() => _selectedMuscle = null);
              }
              return;
            }
            final data = Map<String, dynamic>.from(args.first as Map);
            final group = data['muscleGroup'] as String?;
            final muscle = _musclesById[group];

            if (mounted) {
              setState(() {
                _selectedMuscle = muscle;
              });
            }
          },
        );
      },
    );
  }

  Widget _buildModeTogglePill(
    Color cardDark,
    Color accentLime,
    Color accentCyan,
    AppStrings strings,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Explore Mode (Raycasting active, Orbit disabled)
          Expanded(
            child: GestureDetector(
              key: const Key('mode_explore_button'),
              onTap: () => _switchMode(MuscleViewMode.explore),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentMode == MuscleViewMode.explore
                      ? accentLime.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentMode == MuscleViewMode.explore
                        ? accentLime
                        : Colors.transparent,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 16,
                        color: _currentMode == MuscleViewMode.explore
                            ? accentLime
                            : const Color(0xFF8E9BAE),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.isArabic
                            ? 'إصبع: اختيار • إصبعان: تدوير وتكبير'
                            : '1-Finger: Select / 2-Fingers: Rotate & Zoom',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _currentMode == MuscleViewMode.explore
                              ? Colors.white
                              : const Color(0xFF8E9BAE),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Orbit Mode (360 Rotation & Zoom active, Raycast paused)
          Expanded(
            child: GestureDetector(
              key: const Key('mode_orbit_button'),
              onTap: () => _switchMode(MuscleViewMode.orbit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _currentMode == MuscleViewMode.orbit
                      ? accentCyan.withValues(alpha: 0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _currentMode == MuscleViewMode.orbit
                        ? accentCyan
                        : Colors.transparent,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rotate_90_degrees_ccw_rounded,
                        size: 16,
                        color: _currentMode == MuscleViewMode.orbit
                            ? accentCyan
                            : const Color(0xFF8E9BAE),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        strings.isArabic ? 'تدوير 360°' : 'Orbit 360° (تدوير)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _currentMode == MuscleViewMode.orbit
                              ? Colors.white
                              : const Color(0xFF8E9BAE),
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
    );
  }

  Widget _buildHeatmapLegend(Color cardDark) {
    return Container(
      key: const Key('heatmap_legend'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendDot(const Color(0xFF34C759), 'Ready'),
          const SizedBox(width: 12),
          _buildLegendDot(const Color(0xFFFFCC00), 'Moderate'),
          const SizedBox(width: 12),
          _buildLegendDot(const Color(0xFFFF3B30), 'Fatigued'),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Color _parseHexColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFCCFF00);
    }
  }

  Widget _buildHoverHud(Color cardDark, Color accentLime, AppStrings strings) {
    final rawText = _hoveredRegionLabel ?? _hoveredMuscleGroup ?? '';
    if (rawText.isEmpty) return const SizedBox.shrink();

    final text = _hoveredMuscleGroup != null
        ? strings.localizedMuscleName(_hoveredMuscleGroup!, _hoveredRegionLabel)
        : rawText;

    final fatigue = _isHeatmapActive && _hoveredMuscleGroup != null
        ? _fatigueScores[_hoveredMuscleGroup]
        : null;

    final dotColor = fatigue != null
        ? _parseHexColor(fatigue.hexColor)
        : accentLime;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dotColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              fatigue != null
                  ? '$text • ${strings.isArabic ? "الحمل" : "Load"}: ${fatigue.totalScore.toStringAsFixed(1)}'
                  : text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedMuscleCard(AppThemeTokens theme, AppStrings strings) {
    final cardDark = theme.surface;
    final accentLime = theme.primary;
    final m = _selectedMuscle!;
    final fatigue = _isHeatmapActive ? _fatigueScores[m.id] : null;

    return AnimatedSlide(
      offset: Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          key: const Key('selected_muscle_card'),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: fatigue != null
                  ? _parseHexColor(fatigue.hexColor)
                  : accentLime.withValues(alpha: 0.6),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                          (fatigue != null
                                  ? _parseHexColor(fatigue.hexColor)
                                  : accentLime)
                              .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.fitness_center_rounded,
                      color: fatigue != null
                          ? _parseHexColor(fatigue.hexColor)
                          : accentLime,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.localizedMuscleName(m.id, m.name),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${strings.isArabic ? "المنطقة" : "Region"}: ${m.anatomyRegion}',
                          style: const TextStyle(
                            color: Color(0xFF8E9BAE),
                            fontSize: 12,
                          ),
                        ),
                        if (fatigue != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _parseHexColor(fatigue.hexColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Load: ${fatigue.totalScore.toStringAsFixed(1)} (Gym: ${fatigue.gymScore.toStringAsFixed(1)}, Bike: ${fatigue.cyclingScore.toStringAsFixed(1)})',
                                style: TextStyle(
                                  color: _parseHexColor(fatigue.hexColor),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: theme.textSecondary,
                      size: 20,
                    ),
                    onPressed: _clearSelection,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  key: const Key('view_targeted_exercises_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: theme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 20),
                  label: Text(
                    strings.isArabic
                        ? 'عرض التمارين المستهدفة'
                        : 'View Targeted Exercises',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MuscleDetailScreen(
                          muscleId: m.id,
                          dbService: _dbService,
                          themeController: widget.themeController,
                          localeController: widget.localeController,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickMuscleChips(
    Color cardDark,
    Color accentLime,
    AppStrings strings,
  ) {
    if (_allMuscles.isEmpty) return const SizedBox.shrink();

    final filtered = _filteredMuscles;
    final categories = [
      {'id': 'all', 'label': strings.allCategories},
      {'id': 'chest', 'label': strings.chestCategory},
      {'id': 'back', 'label': strings.backCategory},
      {'id': 'legs', 'label': strings.legsCategory},
      {'id': 'arms', 'label': strings.armsCategory},
      {'id': 'shoulders', 'label': strings.shouldersCategory},
      {'id': 'core', 'label': strings.coreCategory},
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filter Chips (GYM-P4-003)
        SizedBox(
          height: 32,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: categories.map((cat) {
                final isCatSelected = _selectedCategory == cat['id'];
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    key: Key('category_filter_${cat['id']}'),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategory = cat['id']!);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isCatSelected
                            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                            : cardDark,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isCatSelected
                              ? const Color(0xFF00E5FF)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat['label']!,
                          style: TextStyle(
                            color: isCatSelected
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF8E9BAE),
                            fontSize: 11,
                            fontWeight: isCatSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Filtered Quick Muscle Chips
        SizedBox(
          height: 42,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: filtered.map((m) {
                final isSelected = _selectedMuscle?.id == m.id;
                final fatigue = _isHeatmapActive ? _fatigueScores[m.id] : null;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    key: Key('3d_chip_${m.id}'),
                    onTap: () => _onMuscleSelectedFromUi(m.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentLime.withValues(alpha: 0.2)
                            : cardDark,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? accentLime
                              : (fatigue != null
                                    ? _parseHexColor(fatigue.hexColor)
                                          .withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.08)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (fatigue != null) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _parseHexColor(fatigue.hexColor),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            strings.localizedMuscleName(m.id, m.name),
                            style: TextStyle(
                              color: isSelected ? accentLime : Colors.white70,
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}
