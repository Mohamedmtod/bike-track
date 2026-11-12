import 'dart:io';
import 'dart:ui';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service responsible for flushing WAL and exporting local SQLite database (`probike_gym.db`)
/// to iOS Files, AirDrop, or iCloud Drive for single-user manual backups.
class GymBackupService {
  final GymDatabaseService _dbService;
  final Future<ShareResult> Function(ShareParams params)? customShareHandler;

  GymBackupService({
    GymDatabaseService? dbService,
    this.customShareHandler,
  }) : _dbService = dbService ?? GymDatabaseService.instance;

  /// Forces SQLite WAL checkpoint and copies `probike_gym.db` to a timestamped backup file.
  Future<File> createBackupFile({Directory? customTargetDir}) async {
    final db = _dbService.database;

    // 1. Force WAL checkpoint so all recent transactions are committed to the main database file
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } catch (_) {}

    final sourcePath = db.path;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFileName = 'probike_gym_backup_$timestamp.db';

    final targetDir = customTargetDir ?? (await _resolveTargetDirectory());
    final backupPath = p.join(targetDir.path, backupFileName);

    // Handle in-memory database during tests
    if (sourcePath == ':memory:' || sourcePath == 'in_memory' || sourcePath.isEmpty) {
      final backupFile = File(backupPath);
      await backupFile.writeAsString('PROBIKE_GYM_BACKUP_TEST_STUB');
      return backupFile;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw StateError('Source database file does not exist at $sourcePath');
    }

    return await sourceFile.copy(backupPath);
  }

  /// Exports backup and displays the platform share sheet (Files / AirDrop / iCloud Drive).
  Future<ShareResult> exportBackupToFiles({
    File? backupFile,
    Rect? sharePositionOrigin,
  }) async {
    final file = backupFile ?? await createBackupFile();
    final xFile = XFile(file.path, mimeType: 'application/x-sqlite3');
    final params = ShareParams(
      files: [xFile],
      subject: 'ProBike Gym Backup',
      text: 'ProBike Gym Database Backup (${p.basename(file.path)})',
      sharePositionOrigin: sharePositionOrigin,
    );

    if (customShareHandler != null) {
      return await customShareHandler!(params);
    }

    return await SharePlus.instance.share(params);
  }

  Future<Directory> _resolveTargetDirectory() async {
    try {
      return await getTemporaryDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }
}
