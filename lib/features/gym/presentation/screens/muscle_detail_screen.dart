import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/exercise_repository.dart';
import 'package:bike_track/features/gym/data/muscle_repository.dart';
import 'package:bike_track/features/gym/models/exercise.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MuscleDetailScreen extends StatefulWidget {
  final String muscleId;
  final GymDatabaseService? dbService;

  const MuscleDetailScreen({
    super.key,
    required this.muscleId,
    this.dbService,
  });

  @override
  State<MuscleDetailScreen> createState() => _MuscleDetailScreenState();
}

class _MuscleDetailScreenState extends State<MuscleDetailScreen> {
  late final GymDatabaseService _dbService;
  late final MuscleRepository _muscleRepo;
  late final ExerciseRepository _exerciseRepo;

  bool _isLoading = true;
  Muscle? _muscle;
  List<Exercise> _exercises = [];

  @override
  void initState() {
    super.initState();
    _dbService = widget.dbService ?? GymDatabaseService.instance;
    _muscleRepo = MuscleRepository(dbService: _dbService);
    _exerciseRepo = ExerciseRepository(dbService: _dbService);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (!_dbService.isInitialized) {
        await _dbService.initialize();
      }
      final muscle = await _muscleRepo.getMuscleById(widget.muscleId);
      final exercises = await _exerciseRepo.getExercisesForMuscle(widget.muscleId);

      if (mounted) {
        setState(() {
          _muscle = muscle;
          _exercises = exercises;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF090A0F);
    const cardDark = Color(0xFF14161F);
    const accentLime = Color(0xFFCCFF00);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        title: Text(
          _muscle?.name ?? widget.muscleId,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: accentLime))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardDark,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: accentLime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.fitness_center, color: accentLime),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _muscle?.name ?? widget.muscleId,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Region: ${_muscle?.anatomyRegion ?? "Target Area"} • ${_exercises.length} Exercises',
                              style: const TextStyle(color: Color(0xFF8E9BAE), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'TARGETED EXERCISES',
                  style: TextStyle(
                    color: Color(0xFF8E9BAE),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                if (_exercises.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: Text(
                        'No exercises found for this muscle group.',
                        style: TextStyle(color: Color(0xFF8E9BAE)),
                      ),
                    ),
                  )
                else
                  ..._exercises.map((ex) => _buildExerciseCard(ex, cardDark, accentLime)),
              ],
            ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise, Color cardDark, Color accentLime) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sports_gymnastics, color: Color(0xFF8E9BAE)),
          ),
          title: Text(
            exercise.name,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _buildPill(exercise.equipment, Colors.white.withValues(alpha: 0.1), Colors.white70),
                _buildPill(exercise.laterality, Colors.white.withValues(alpha: 0.1), Colors.white70),
              ],
            ),
          ),
          trailing: const Icon(Icons.chevron_right, color: Color(0xFF8E9BAE)),
          onTap: () {
            HapticFeedback.lightImpact();
          },
        ),
      ),
    );
  }

  Widget _buildPill(String label, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.w500),
      ),
    );
  }
}
