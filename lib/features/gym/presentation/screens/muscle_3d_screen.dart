import 'dart:io';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

enum MuscleViewMode {
  explore, // Touch & scrub to select muscles (<0.4ms BVH raycast)
  orbit,   // 360 rotation & pinch-zoom (controls enabled, raycasting paused)
}

enum CameraAngle {
  front,
  back,
}

class Muscle3DScreen extends StatefulWidget {
  final GymDatabaseService? dbService;
  final InAppLocalhostServer? customServer;
  final WidgetBuilder? customWebViewBuilder;
  final String? initialSelectedMuscle;

  const Muscle3DScreen({
    super.key,
    this.dbService,
    this.customServer,
    this.customWebViewBuilder,
    this.initialSelectedMuscle,
  });

  @override
  State<Muscle3DScreen> createState() => _Muscle3DScreenState();
}

class _Muscle3DScreenState extends State<Muscle3DScreen> {
  late final GymDatabaseService _dbService;
  late final MuscleRepository _muscleRepo;

  InAppLocalhostServer? _localhostServer;
  InAppWebViewController? _webViewController;

  bool _isServerRunning = false;
  bool _isModelReady = false;

  MuscleViewMode _currentMode = MuscleViewMode.explore;
  CameraAngle _currentAngle = CameraAngle.front;

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
    _loadMuscles();
    _initLocalServer();
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
    if (InAppWebViewPlatform.instance == null || widget.customWebViewBuilder != null) {
      if (mounted) {
        setState(() {
          _isServerRunning = true;
          _isModelReady = true;
        });
      }
      return;
    }

    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid && !Platform.isMacOS && !Platform.isWindows)) {
      if (mounted) {
        setState(() => _isServerRunning = true);
      }
      return;
    }

    try {
      _localhostServer = widget.customServer ??
          InAppLocalhostServer(
            documentRoot: 'assets/gym',
            port: 8080,
          );

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
    if (widget.customServer == null && _localhostServer != null && _localhostServer!.isRunning()) {
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
    const bgDark = Color(0xFF090A0F); // OLED Black
    const cardDark = Color(0xFF14161F); // Titanium Dark
    const accentLime = Color(0xFFCCFF00); // Cyber Lime
    const accentCyan = Color(0xFF00E5FF); // Electric Cyan

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: const Text(
          '3D Muscle Map',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Front / Back camera toggle button
          TextButton.icon(
            key: const Key('camera_angle_toggle_button'),
            onPressed: () {
              final next = _currentAngle == CameraAngle.front ? CameraAngle.back : CameraAngle.front;
              _switchCameraAngle(next);
            },
            icon: Icon(
              Icons.flip_camera_ios_rounded,
              color: accentCyan,
              size: 18,
            ),
            label: Text(
              _currentAngle == CameraAngle.front ? 'FRONT' : 'BACK',
              style: const TextStyle(
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
            _buildWebView(bgDark, accentLime)
          else
            const Center(
              child: CircularProgressIndicator(color: accentLime),
            ),
            const Center(
              child: CircularProgressIndicator(color: accentLime),
            ),

          // 2. Loading overlay if model is still downloading or parsing
          if (!_isModelReady && _isServerRunning)
            Container(
              color: bgDark,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: accentLime),
                    SizedBox(height: 16),
                    Text(
                      'Loading 3D Anatomy Model...',
                      style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Top Mode Toggle Floating Pill (Explore vs Orbit)
          Positioned(
            top: 12,
            left: 20,
            right: 20,
            child: _buildModeTogglePill(cardDark, accentLime, accentCyan),
          ),

          // 4. Live Hover HUD Banner
          if (_hoveredRegionLabel != null || _hoveredMuscleGroup != null)
            Positioned(
              top: 68,
              left: 24,
              right: 24,
              child: _buildHoverHud(cardDark, accentLime),
            ),

          // 5. Bottom Navigation & Action Overlay
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selected Muscle Action Card (if a muscle was clicked)
                if (_selectedMuscle != null)
                  _buildSelectedMuscleCard(cardDark, accentLime)
                else
                  // Horizontal Quick Muscle Chips
                  _buildQuickMuscleChips(cardDark, accentLime),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebView(Color bgDark, Color accentLime) {
    if (widget.customWebViewBuilder != null) {
      return widget.customWebViewBuilder!(context);
    }
    if (InAppWebViewPlatform.instance == null) {
      return Container(
        key: const Key('muscle_3d_webview'),
        color: bgDark,
      );
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

  Widget _buildModeTogglePill(Color cardDark, Color accentLime, Color accentCyan) {
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
                        color: _currentMode == MuscleViewMode.explore ? accentLime : const Color(0xFF8E9BAE),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Explore (لمس)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _currentMode == MuscleViewMode.explore ? Colors.white : const Color(0xFF8E9BAE),
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
                        color: _currentMode == MuscleViewMode.orbit ? accentCyan : const Color(0xFF8E9BAE),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Orbit 360° (تدوير)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _currentMode == MuscleViewMode.orbit ? Colors.white : const Color(0xFF8E9BAE),
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

  Widget _buildHoverHud(Color cardDark, Color accentLime) {
    final text = _hoveredRegionLabel ?? _hoveredMuscleGroup ?? '';
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardDark.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentLime.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: accentLime,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
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

  Widget _buildSelectedMuscleCard(Color cardDark, Color accentLime) {
    final m = _selectedMuscle!;
    return Container(
      key: const Key('selected_muscle_card'),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentLime.withValues(alpha: 0.6)),
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
                  color: accentLime.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.fitness_center_rounded, color: accentLime, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Region: ${m.anatomyRegion}',
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF8E9BAE), size: 20),
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
                backgroundColor: accentLime,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              label: const Text(
                'View Targeted Exercises (عرض التمارين)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MuscleDetailScreen(
                      muscleId: m.id,
                      dbService: _dbService,
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

  Widget _buildQuickMuscleChips(Color cardDark, Color accentLime) {
    if (_allMuscles.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _allMuscles.map((m) {
            final isSelected = _selectedMuscle?.id == m.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                key: Key('3d_chip_${m.id}'),
                onTap: () => _onMuscleSelectedFromUi(m.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? accentLime.withValues(alpha: 0.2) : cardDark,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? accentLime : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      m.name,
                      style: TextStyle(
                        color: isSelected ? accentLime : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
