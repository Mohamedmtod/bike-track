import 'dart:async';
import 'package:bike_track/features/gym/data/gym_seed_data.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Database service managing local SQLite persistence for ProBike Gym Module.
/// Runs in WAL mode (`journal_mode = WAL`) with foreign keys enabled.
class GymDatabaseService {
  GymDatabaseService({DatabaseFactory? databaseFactory}) : _factory = databaseFactory;

  static const String databaseName = 'probike_gym.db';
  static const int databaseVersion = 1;

  final DatabaseFactory? _factory;
  Database? _database;

  Database get database {
    if (_database == null) {
      throw StateError('GymDatabaseService has not been initialized. Call initialize() first.');
    }
    return _database!;
  }

  bool get isInitialized => _database != null && _database!.isOpen;

  Future<Database> initialize({String? customPath, bool inMemory = false}) async {
    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final dbFactory = _factory ?? databaseFactory;

    String path;
    if (inMemory) {
      path = inMemoryDatabasePath;
    } else if (customPath != null) {
      path = customPath;
    } else {
      final databasesPath = await dbFactory.getDatabasesPath();
      path = p.join(databasesPath, databaseName);
    }

    _database = await dbFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: databaseVersion,
        onConfigure: (db) async {
          // Enable Foreign Key constraints
          await db.execute('PRAGMA foreign_keys = ON;');
          // Enable Write-Ahead Logging (WAL) for high concurrency & crash resilience
          if (!inMemory) {
            await db.execute('PRAGMA journal_mode = WAL;');
            await db.execute('PRAGMA synchronous = NORMAL;');
          }
        },
        onCreate: (db, version) async {
          await _createTables(db);
          await GymSeedData.populate(db);
        },
      ),
    );

    return _database!;
  }

  Future<void> seedInitialData() async {
    await GymSeedData.populate(database);
  }

  Future<void> _createTables(Database db) async {
    final batch = db.batch();

    // 1. MUSCLE Table
    batch.execute('''
      CREATE TABLE MUSCLE (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        anatomy_region TEXT NOT NULL,
        muscle_group TEXT NOT NULL
      );
    ''');

    // 2. MUSCLE_MESH_BINDING Table
    batch.execute('''
      CREATE TABLE MUSCLE_MESH_BINDING (
        id TEXT PRIMARY KEY,
        muscle_id TEXT NOT NULL,
        mesh_id TEXT NOT NULL,
        side TEXT NOT NULL CHECK(side IN ('left', 'right', 'both')),
        FOREIGN KEY (muscle_id) REFERENCES MUSCLE (id) ON DELETE CASCADE
      );
    ''');

    // 3. EXERCISE Table
    batch.execute('''
      CREATE TABLE EXERCISE (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        logging_type TEXT NOT NULL,
        laterality TEXT NOT NULL,
        equipment TEXT NOT NULL,
        instructions TEXT,
        asset_key TEXT
      );
    ''');

    // 4. EXERCISE_MUSCLE Table
    batch.execute('''
      CREATE TABLE EXERCISE_MUSCLE (
        exercise_id TEXT NOT NULL,
        muscle_id TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('PRIMARY', 'SECONDARY')),
        PRIMARY KEY (exercise_id, muscle_id),
        FOREIGN KEY (exercise_id) REFERENCES EXERCISE (id) ON DELETE CASCADE,
        FOREIGN KEY (muscle_id) REFERENCES MUSCLE (id) ON DELETE CASCADE
      );
    ''');

    // 5. WORKOUT_SESSION Table
    batch.execute('''
      CREATE TABLE WORKOUT_SESSION (
        id TEXT PRIMARY KEY,
        started_at TEXT NOT NULL,
        ended_at TEXT,
        status TEXT NOT NULL CHECK(status IN ('IN_PROGRESS', 'DONE', 'CANCELLED')),
        rest_ends_at_utc TEXT,
        rest_duration_seconds INTEGER,
        notes TEXT
      );
    ''');

    // 6. SESSION_EXERCISE Table
    batch.execute('''
      CREATE TABLE SESSION_EXERCISE (
        id TEXT PRIMARY KEY,
        session_id TEXT NOT NULL,
        exercise_id TEXT NOT NULL,
        performed_exercise_id TEXT,
        superset_group_id TEXT,
        notes TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES WORKOUT_SESSION (id) ON DELETE CASCADE,
        FOREIGN KEY (exercise_id) REFERENCES EXERCISE (id) ON DELETE CASCADE
      );
    ''');

    // 7. SET_LOG Table
    batch.execute('''
      CREATE TABLE SET_LOG (
        id TEXT PRIMARY KEY,
        session_exercise_id TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        logical_set_id TEXT,
        set_type TEXT NOT NULL CHECK(set_type IN ('WARMUP', 'WORKING', 'DROP')),
        failure_status INTEGER NOT NULL DEFAULT 0,
        weight_kg REAL,
        reps INTEGER,
        duration_seconds INTEGER,
        side TEXT NOT NULL DEFAULT 'both' CHECK(side IN ('both', 'left', 'right')),
        rest_taken_seconds INTEGER,
        completed INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (session_exercise_id) REFERENCES SESSION_EXERCISE (id) ON DELETE CASCADE
      );
    ''');

    // Indices for ultra-fast query and ghost pre-fill lookups
    batch.execute('CREATE INDEX idx_muscle_group ON MUSCLE (muscle_group);');
    batch.execute('CREATE INDEX idx_mesh_binding_muscle ON MUSCLE_MESH_BINDING (muscle_id);');
    batch.execute('CREATE INDEX idx_exercise_muscle_lookup ON EXERCISE_MUSCLE (muscle_id, role);');
    batch.execute('CREATE INDEX idx_session_status ON WORKOUT_SESSION (status);');
    batch.execute('CREATE INDEX idx_session_exercise_session ON SESSION_EXERCISE (session_id, sort_order);');
    batch.execute('CREATE INDEX idx_set_log_session_ex ON SET_LOG (session_exercise_id, set_number);');

    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
  }
}

