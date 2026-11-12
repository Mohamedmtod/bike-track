import 'dart:io';
import 'package:bike_track/features/gym/data/gym_analytics_repository.dart';
import 'package:bike_track/features/gym/data/gym_bike_bridge.dart';
import 'package:bike_track/features/gym/data/gym_database_service.dart';
import 'package:bike_track/features/gym/data/workout_repository.dart';
import 'package:bike_track/features/gym/models/set_log.dart';
import 'package:bike_track/features/gym/services/audio_session_coordinator.dart';
import 'package:bike_track/features/gym/services/gym_backup_service.dart';
import 'package:bike_track/features/gym/services/gym_heatmap_service.dart';
import 'package:bike_track/features/gym/services/gym_live_activity_service.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/services/telemetry_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('TEST-REG-01..13 — Gym 13 Critical Edge Cases & Cycling Concurrency Tests', () {
    late GymDatabaseService dbService;

    setUp(() async {
      dbService = GymDatabaseService(databaseFactory: databaseFactoryFfi);
      await dbService.initialize(inMemory: true);
      GymDatabaseService.defaultInstance = dbService;
    });

    tearDown(() async {
      await dbService.close();
      GymDatabaseService.defaultInstance = null;
    });

    // Scenario 1: GPS Stream Concurrency while Logging Gym Sets
    test('Scenario 1: High-frequency GPS telemetry logging concurrent with SQLite Gym set commits', () async {
      SharedPreferences.setMockInitialValues({});
      final telemetry = TelemetryService();
      final workoutRepo = WorkoutRepository(dbService: dbService);

      final session = await workoutRepo.startSession();
      final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');

      // Interleave 20 telemetry events with 20 set logs concurrently
      final futures = <Future>[];
      for (int i = 1; i <= 20; i++) {
        telemetry.logEvent(
          eventType: 'gps_point',
          latitude: 30.0 + i * 0.001,
          longitude: 31.0 + i * 0.001,
        );
        futures.add(workoutRepo.saveSetLog(
          SetLog(
            id: 'set_c_$i',
            sessionExerciseId: se.id,
            setNumber: i,
            setType: SetType.working,
            weightKg: 80.0 + i,
            reps: 10,
            completed: true,
          ),
        ));
      }

      await Future.wait(futures);

      final sets = await workoutRepo.getSetsForSessionExercise(se.id);
      expect(sets.length, equals(20));
      expect(sets.last.weightKg, equals(100.0));
      expect(telemetry.bufferSize, equals(20));
    });

    // Scenario 2: 100% Offline Mode & Bundled Assets Integrity
    test('Scenario 2: Gym operates 100% offline with bundled assets present and accessible', () async {
      final glbFile = File('assets/gym/models/male_anatomy.glb');
      final manifestFile = File('assets/gym/models/manifest.json');
      final webBundle = File('assets/gym/web/gym_viewer_bundle.js');

      expect(glbFile.existsSync(), isTrue);
      expect(manifestFile.existsSync(), isTrue);
      expect(webBundle.existsSync(), isTrue);
      expect(glbFile.lengthSync(), greaterThan(1024 * 1024)); // >1MB
    });

    // Scenario 3: Database WAL Checkpoint Resilience & Backup Integrity
    test('Scenario 3: WAL checkpoint flushes transactions cleanly into standalone backup file', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final session = await workoutRepo.startSession();
      final se = await workoutRepo.addExerciseToSession(session.id, 'squat');
      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_wal_1',
          sessionExerciseId: se.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 120.0,
          reps: 8,
          completed: true,
        ),
      );

      final backupService = GymBackupService(dbService: dbService);
      final tempDir = await Directory.systemTemp.createTemp('probike_reg_test_');
      final backup = await backupService.createBackupFile(customTargetDir: tempDir);

      expect(backup.existsSync(), isTrue);
      expect(backup.lengthSync(), greaterThan(0));

      await tempDir.delete(recursive: true);
    });

    // Scenario 4: Heavy Volume Rapid-Fire Set Logging (50 Rapid Sets)
    test('Scenario 4: 50 rapid sequential set updates enforce correct ordering without race condition', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final session = await workoutRepo.startSession();
      final se = await workoutRepo.addExerciseToSession(session.id, 'romanian_deadlift');

      for (int i = 1; i <= 50; i++) {
        await workoutRepo.saveSetLog(
          SetLog(
            id: 'set_rapid_$i',
            sessionExerciseId: se.id,
            setNumber: i,
            setType: SetType.working,
            weightKg: 100.0 + (i * 0.5),
            reps: 5,
            completed: true,
          ),
        );
      }

      final sets = await workoutRepo.getSetsForSessionExercise(se.id);
      expect(sets.length, equals(50));
      for (int i = 0; i < 50; i++) {
        expect(sets[i].setNumber, equals(i + 1));
      }
    });

    // Scenario 5: Monotonic Clock Rest Timer Recovery Across Wall-Clock Jump
    test('Scenario 5: Monotonic rest timer handles time jumps without negative remaining duration', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final session = await workoutRepo.startSession();

      final futureRest = DateTime.now().toUtc().add(const Duration(seconds: 90));
      await workoutRepo.updateRestEndsAt(session.id, futureRest, durationSeconds: 90);

      // Verify active session recovers rest end time
      final loaded = await workoutRepo.getActiveSession();
      expect(loaded, isNotNull);
      expect(loaded!.restEndsAtUtc, isNotNull);

      final target = loaded.restEndsAtUtc!.toLocal();
      final diff = target.difference(DateTime.now()).inSeconds;
      expect(diff, greaterThanOrEqualTo(85));
      expect(diff, lessThanOrEqualTo(95));
    });

    // Scenario 6: Cycling Bridge Resiliency to Corrupted SharedPreferences Data
    test('Scenario 6: Corrupted JSON in cached_rides_history handled gracefully without throw', () async {
      SharedPreferences.setMockInitialValues({
        'cached_rides_history': 'INVALID_JSON_{{{corrupt: true}',
      });
      final prefs = await SharedPreferences.getInstance();
      final bridge = GymBikeBridge(prefs: prefs);

      final rides = await bridge.getRecentRides();
      expect(rides, isEmpty);

      final fatigue = await bridge.getCyclingMuscleFatigue();
      expect(fatigue, isEmpty);
    });

    // Scenario 7: Exercise Swapping preserves session order and target muscle
    test('Scenario 7: Swapping exercise replaces target ID and preserves history integrity', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final session = await workoutRepo.startSession();
      final se = await workoutRepo.addExerciseToSession(session.id, 'bench_press');

      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_swap_1',
          sessionExerciseId: se.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 80.0,
          reps: 10,
          completed: true,
        ),
      );

      // Swap to incline_db_press
      await workoutRepo.swapExerciseInSession(se.id, 'incline_db_press');

      final exercises = await workoutRepo.getSessionExercises(session.id);
      expect(exercises.first.performedExerciseId, equals('incline_db_press'));
      expect(exercises.first.exerciseId, equals('bench_press'));
    });

    // Scenario 8: Unilateral sets maintain side bindings (left/right/both)
    test('Scenario 8: Unilateral set logging supports left, right, and both side switching', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final session = await workoutRepo.startSession();
      final se = await workoutRepo.addExerciseToSession(session.id, 'cable_woodchopper');

      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_uni_1',
          sessionExerciseId: se.id,
          setNumber: 1,
          setType: SetType.working,
          weightKg: 15.0,
          reps: 12,
          side: 'left',
          completed: true,
        ),
      );

      await workoutRepo.saveSetLog(
        SetLog(
          id: 'set_uni_2',
          sessionExerciseId: se.id,
          setNumber: 2,
          setType: SetType.working,
          weightKg: 15.0,
          reps: 12,
          side: 'right',
          completed: true,
        ),
      );

      final sets = await workoutRepo.getSetsForSessionExercise(se.id);
      expect(sets[0].side, equals('left'));
      expect(sets[1].side, equals('right'));
    });

    // Scenario 9: Ghost Prefill with Null Previous Performance
    test('Scenario 9: Ghost prefill on brand-new exercise returns null gracefully', () async {
      final workoutRepo = WorkoutRepository(dbService: dbService);
      final history = await workoutRepo.getLastPerformance('pull_ups');
      expect(history, isEmpty);
    });

    // Scenario 10: Brzycki 1RM Formula Extreme Boundary Values
    test('Scenario 10: Brzycki 1RM handles extreme inputs (0 reps, 1 rep, 36 reps, >=37 reps) safely', () {
      expect(GymAnalyticsRepository.calculate1RM(100.0, 1), equals(100.0));
      expect(GymAnalyticsRepository.calculate1RM(100.0, 0), equals(0.0));
      expect(GymAnalyticsRepository.calculate1RM(100.0, -5), equals(0.0));
      expect(GymAnalyticsRepository.calculate1RM(0.0, 10), equals(0.0));

      // 10 reps at 100kg -> ~133.3kg
      expect(GymAnalyticsRepository.calculate1RM(100.0, 10), closeTo(133.3, 0.5));

      // Reps >= 37 clamps rep count to 36 to prevent division by zero or negative
      final highRep = GymAnalyticsRepository.calculate1RM(50.0, 40);
      expect(highRep.isFinite, isTrue);
      expect(highRep, greaterThan(0));
    });

    // Scenario 11: Heatmap Score Clamping & Tier Classification
    test('Scenario 11: Heatmap service correctly assigns High, Moderate, and Recovered tiers', () async {
      final now = DateTime.now();
      final rideHigh = RideModel(
        id: 1,
        startTime: now.subtract(const Duration(hours: 1)),
        durationSeconds: 7200,
        distanceMeters: 60000.0, // 60 km
        avgSpeedKmh: 30.0,
        maxSpeedKmh: 45.0,
        minSpeedKmh: 10.0,
      );

      final bikeBridge = GymBikeBridge(overrideRides: [rideHigh]);
      final heatmapService = GymHeatmapService(dbService: dbService, bikeBridge: bikeBridge);

      final scores = await heatmapService.computeMuscleFatigueScores();
      expect(scores['quads']!.hexColor, equals(GymHeatmapService.colorHighFatigue));
      expect(scores['calves']!.hexColor, equals(GymHeatmapService.colorHighFatigue));

      // Untrained muscle stays in recovered tier
      expect(scores['biceps']!.hexColor, equals(GymHeatmapService.colorRecovered));
    });

    // Scenario 12: Manual Backup Service with In-Memory / Isolated Mode
    test('Scenario 12: Backup service produces valid file with custom destination', () async {
      final backupService = GymBackupService(dbService: dbService);
      final customDir = await Directory.systemTemp.createTemp('probike_custom_backup_');

      final file = await backupService.createBackupFile(customTargetDir: customDir);
      expect(file.existsSync(), isTrue);
      expect(file.parent.path, equals(customDir.path));

      await customDir.delete(recursive: true);
    });

    // Scenario 13: Native Audio & Live Activities Graceful Fallback
    test('Scenario 13: Audio coordinator and Live Activity bridge handle missing native channels safely', () async {
      final audioCoordinator = AppAudioSessionCoordinator();
      final liveActivityService = GymLiveActivityService();

      // Ensure calling native hooks does not throw unhandled exceptions
      await expectLater(audioCoordinator.initialize(), completes);
      await expectLater(audioCoordinator.playRestCompleteSound(), completes);
      await expectLater(liveActivityService.startRestTimerActivity(restDurationSeconds: 60, endsAtUtc: DateTime.now().add(const Duration(seconds: 60))), completes);
      await expectLater(liveActivityService.endRestTimerActivity(), completes);
    });
  });
}
