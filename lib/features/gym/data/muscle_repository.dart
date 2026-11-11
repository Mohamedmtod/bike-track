import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/models/muscle.dart';
import 'package:sqflite/sqflite.dart';

class MuscleRepository {
  final GymDatabaseService _dbService;

  MuscleRepository({GymDatabaseService? dbService})
      : _dbService = dbService ?? GymDatabaseService.instance;

  Database get _db => _dbService.database;

  Future<List<Muscle>> getAllMuscles() async {
    final results = await _db.query('MUSCLE', orderBy: 'name ASC');
    return results.map(Muscle.fromMap).toList();
  }

  Future<Muscle?> getMuscleById(String id) async {
    final results = await _db.query('MUSCLE', where: 'id = ?', whereArgs: [id], limit: 1);
    if (results.isEmpty) return null;
    return Muscle.fromMap(results.first);
  }

  Future<List<MuscleMeshBinding>> getMeshBindingsForMuscle(String muscleId) async {
    final results = await _db.query(
      'MUSCLE_MESH_BINDING',
      where: 'muscle_id = ?',
      whereArgs: [muscleId],
    );
    return results.map(MuscleMeshBinding.fromMap).toList();
  }
}
