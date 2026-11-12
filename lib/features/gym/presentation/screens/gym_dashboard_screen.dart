import 'dart:io';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:bike_track/features/gym/models/workout_session.dart';
import 'package:bike_track/features/gym/presentation/screens/active_workout_screen.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_3d_screen.dart';
import 'package:bike_track/features/gym/presentation/screens/muscle_detail_screen.dart';
import 'package:bike_track/features/gym/services/gym_backup_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GymDashboardScreen extends StatefulWidget {
  final GymDatabaseService? dbService;
  final GymBackupService? backupService;

  const GymDashboardScreen({
    super.key,
    this.dbService,
    this.backupService,
  });

  @override
  State<GymDashboardScreen> createState() => _GymDashboardScreenState();
}

class _GymDashboardScreenState extends State<GymDashboardScreen> {
  late final GymDatabaseService _dbService;
  late final MuscleRepository _muscleRepo;
  late final WorkoutRepository _workoutRepo;
  late final GymBackupService _backupService;

  bool _isLoading = true;
  bool _isExportingBackup = false;
  WorkoutSession? _activeSession;
  List<WorkoutSession> _recentSessions = [];
  List<Muscle> _muscles = [];

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _muscleRepo = MuscleRepository(dbService: _dbService);
    _workoutRepo = WorkoutRepository(dbService: _dbService);
    _backupService = widget.backupService ?? GymBackupService(dbService: _dbService);
    _refreshData();
  }

  Future<void> _refreshData() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      final active = await _workoutRepo.getActiveSession();
      final recent = await _workoutRepo.getRecentSessions(limit: 5);
      final muscles = await _muscleRepo.getAllMuscles();

      if (mounted) {
        setState(() {
          _activeSession = active;
          _recentSessions = recent;
          _muscles = muscles;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('_exportBackup error: $e\n$stack');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    if (_isExportingBackup) return;
    HapticFeedback.mediumImpact();
    setState(() => _isExportingBackup = true);

    try {
      final backupFile = await _backupService.createBackupFile();
      if (!mounted) return;

      final fileName = backupFile.path.split(Platform.pathSeparator).last;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF14161F),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF34C759), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Backup created: $fileName',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      await _backupService.exportBackupToFiles(backupFile: backupFile);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF14161F),
            content: Text(
              'Failed to export backup: $e',
              style: const TextStyle(color: Color(0xFFFF3B30), fontSize: 13),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingBackup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF090A0F); // OLED Black
    const cardDark = Color(0xFF14161F); // Titanium Dark
    const accentLime = Color(0xFFCCFF00); // ProBike Cyber Lime
    const accentCyan = Color(0xFF00E5FF); // Electric Cyan

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center_rounded, color: accentLime, size: 22),
              SizedBox(width: 8),
              Text(
                'ProBike Gym',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('gym_backup_button'),
            icon: _isExportingBackup
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentCyan),
                  )
                : const Icon(Icons.backup_rounded, color: accentCyan),
            tooltip: 'Export Database Backup (نسخة احتياطية)',
            onPressed: _exportBackup,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8E9BAE)),
            onPressed: () {
              HapticFeedback.lightImpact();
              _refreshData();
            },
          ),
        ],
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentLime))
          : RefreshIndicator(
              onRefresh: _refreshData,
              color: accentLime,
              backgroundColor: cardDark,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // Active Workout Banner (if in progress)
                  if (_activeSession != null) ...[
                    _buildActiveSessionCard(cardDark, accentLime),
                    const SizedBox(height: 16),
                  ],

                  // 3D Muscle Map Entry Hero Card
                  _build3DHeroCard(cardDark, accentCyan),
                  const SizedBox(height: 16),

                  // Start Free Workout Action
                  _buildStartWorkoutCard(accentLime),
                  const SizedBox(height: 24),

                  // Muscle Groups Section
                  const Text(
                    'MUSCLE GROUPS (المجموعات العضلية)',
                    style: TextStyle(
                      color: Color(0xFF8E9BAE),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMuscleGroupsGrid(cardDark, accentLime),
                  const SizedBox(height: 24),

                  // Recent Sessions Section
                  const Text(
                    'RECENT WORKOUTS (آخر الجلسات)',
                    style: TextStyle(
                      color: Color(0xFF8E9BAE),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildRecentWorkoutsSection(cardDark),
                  const SizedBox(height: 24),

                  // Manual Database Backup Card (GYM-P4-004)
                  _buildBackupCard(cardDark, accentCyan),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildActiveSessionCard(Color cardDark, Color accentLime) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentLime.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: accentLime.withValues(alpha: 0.1),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentLime.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.play_arrow_rounded, color: accentLime, size: 24),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout In Progress',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 2),
                Text(
                  'Tap to resume logging sets',
                  style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentLime,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ActiveWorkoutScreen(
                    sessionId: _activeSession!.id,
                    dbService: _dbService,
                  ),
                ),
              ).then((_) => _refreshData());
            },
            child: const Text('RESUME', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _build3DHeroCard(Color cardDark, Color accentCyan) {
    return GestureDetector(
      key: const Key('open_3d_muscle_map_button'),
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Muscle3DScreen(dbService: _dbService),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          gradient: LinearGradient(
            colors: [
              cardDark,
              accentCyan.withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentCyan.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.view_in_ar_rounded, color: accentCyan, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Interactive 3D Body',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Explore 126 muscles & view heatmap',
                    style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF8E9BAE)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartWorkoutCard(Color accentLime) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        key: const Key('start_free_workout_button'),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentLime,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.add_rounded, size: 24, color: Colors.black),
        label: const Text(
          'Start Free Workout (بدء تمرين حر)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: () async {
          HapticFeedback.mediumImpact();
          final session = await _workoutRepo.startSession();
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActiveWorkoutScreen(
                  sessionId: session.id,
                  dbService: _dbService,
                ),
              ),
            ).then((_) => _refreshData());
          }
        },
      ),
    );
  }

  Widget _buildMuscleGroupsGrid(Color cardDark, Color accentLime) {
    if (_muscles.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _muscles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (context, index) {
        final muscle = _muscles[index];
        return GestureDetector(
          key: Key('muscle_chip_${muscle.id}'),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MuscleDetailScreen(
                  muscleId: muscle.id,
                  dbService: _dbService,
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: cardDark,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.fitness_center, size: 16, color: Color(0xFF8E9BAE)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        muscle.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        muscle.anatomyRegion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentWorkoutsSection(Color cardDark) {
    if (_recentSessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        ),
        child: const Center(
          child: Text(
            'No completed workouts yet.\nTap "Start Free Workout" to record your sets!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 13, height: 1.5),
          ),
        ),
      );
    }

    return Column(
      children: _recentSessions.map((s) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFFCCFF00), size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.startedAt.toLocal().toString().split('.')[0],
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Duration: ${s.duration.inMinutes} mins',
                      style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF8E9BAE), size: 18),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBackupCard(Color cardDark, Color accentCyan) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accentCyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.storage_rounded, color: accentCyan, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Database Backup (نسخة احتياطية)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Save your offline workouts to Files or iCloud',
                  style: TextStyle(color: Color(0xFF8E9BAE), fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            key: const Key('export_backup_card_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan.withValues(alpha: 0.2),
              foregroundColor: accentCyan,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: _isExportingBackup ? null : _exportBackup,
            child: _isExportingBackup
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                  )
                : const Text('Export', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
