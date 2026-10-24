import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/ride_model.dart';
import 'notification_service.dart';
import 'supabase_service.dart';
import 'telemetry_service.dart';

class RideController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final INotificationService _notificationService;
  final ITelemetryService _telemetryService;

  bool isRiding = false;
  bool _isStarting = false;
  DateTime? startTime;
  DateTime? _lastPositionTime;
  int durationSeconds = 0;
  double distanceMeters = 0.0;
  double currentSpeedKmh = 0.0;
  double maxSpeedKmh = 0.0;
  double minSpeedKmh = 0.0;
  List<LatLng> routePoints = [];

  Position? currentPosition;
  String? currentSessionId;
  String? _activeRideClientId;

  int reminderMinutes = 30;
  int reminderNotificationTriggerCount = 0;
  static const String _prefReminderKey = 'reminderMinutes';

  // Offline-first persistence keys
  static const String _prefPendingSyncRidesKey = 'pending_sync_rides';
  static const String _prefCachedRidesHistoryKey = 'cached_rides_history';
  static const String _prefActiveRideSnapshotKey = 'active_ride_snapshot';

  Timer? _timer;
  Timer? _snapshotTimer;
  StreamSubscription<Position>? _positionStreamSubscription;

  List<RideModel> ridesHistory = [];
  bool isLoadingHistory = false;

  /// Number of rides in history that are still pending sync to Supabase.
  int get pendingSyncCount =>
      ridesHistory.where((r) => r.syncStatus == SyncStatus.pending).length;

  /// Alias for ridesHistory to support alternative naming.
  List<RideModel> get rideHistory => ridesHistory;

  /// Trigger active ride snapshot for testing crash recovery.
  Future<void> saveActiveRideSnapshotForTest() async {
    await _saveActiveRideSnapshot();
  }

  /// Sets the last position update timestamp for deterministic zeroing tests.
  @visibleForTesting
  void setLastPositionTimeForTest(DateTime time) {
    _lastPositionTime = time;
  }

  bool _preferencesLoaded = false;
  Future<void>? _initPrefsFuture;

  RideController({
    SupabaseService? supabaseService,
    INotificationService? notificationService,
    ITelemetryService? telemetryService,
    bool autoFetchHistory = true,
    bool autoLoadPreferences = true,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _notificationService = notificationService ?? NotificationService(),
        _telemetryService = telemetryService ?? TelemetryService() {
    if (autoLoadPreferences) {
      _initPrefsFuture = _initPreferences();
    }
    if (autoFetchHistory) {
      _initOfflineFirst();
    }
  }

  ITelemetryService get telemetryService => _telemetryService;

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_preferencesLoaded) {
        reminderMinutes = prefs.getInt(_prefReminderKey) ?? 30;
        _preferencesLoaded = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Initialize offline-first: load cached history, recover interrupted rides,
  /// then try to sync pending rides and fetch fresh data.
  Future<void> _initOfflineFirst() async {
    isLoadingHistory = true;
    notifyListeners();

    try {
      // 1. Load cached rides history from local storage
      await _loadCachedHistory();

      // 2. Check for interrupted ride snapshot and recover it
      await _recoverInterruptedRide();

      // 3. Try to sync pending rides queue
      await _syncPendingRides();

      // 4. Fetch fresh history from Supabase
      await _fetchAndMergeHistory();
    } catch (_) {
      // Even if everything fails, we still have local cached data
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> changeReminderMinutes(int delta) async {
    if (_initPrefsFuture != null) {
      await _initPrefsFuture;
    }
    _preferencesLoaded = true;
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
    reminderMinutes = (reminderMinutes + delta).clamp(5, 180);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefReminderKey, reminderMinutes);
    } catch (_) {}

    if (isRiding) {
      try {
        await _notificationService.cancel(3);
        await _notificationService.periodicallyShowWithDuration(
          3,
          '🤔 لسه راكب العجلة؟',
          'عدى $reminderMinutes دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟',
          Duration(minutes: reminderMinutes),
        );
      } catch (_) {}
    }

    notifyListeners();
  }

  /// Fetch history merging local pending rides with server data.
  Future<void> fetchHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      await _syncPendingRides();
      await _fetchAndMergeHistory();
    } catch (e) {
      logTelemetryError('fetch_history_error', {'error': e.toString()});
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  /// Fetch from Supabase and merge with any still-pending local rides.
  Future<void> _fetchAndMergeHistory() async {
    try {
      final serverRides = await _supabaseService.getAllRides();
      final pendingRides = await _loadPendingRides();

      // Merge: server rides take precedence, then add any pending rides not yet on server
      final serverClientIds = serverRides.map((r) => r.clientId).toSet();
      final uniquePending = pendingRides
          .where((r) => !serverClientIds.contains(r.clientId))
          .toList();

      ridesHistory = [...uniquePending, ...serverRides];
      ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Cache the merged history locally
      await _saveCachedHistory();
    } catch (e) {
      // If network fails, just use cached + pending
      logTelemetryError('fetch_merge_error', {'error': e.toString()});
    }
  }

  Future<bool> startRide() async {
    if (isRiding) return true;
    if (_isStarting) return false;

    _isStarting = true;
    try {
      final isTestEnvironment =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

      // Generate a unique session ID for this ride
      final sessionId = 'ride_${DateTime.now().millisecondsSinceEpoch}';
      currentSessionId = sessionId;
      _activeRideClientId = RideModel(
        startTime: DateTime.now(),
        durationSeconds: 0,
        distanceMeters: 0,
        avgSpeedKmh: 0,
        maxSpeedKmh: 0,
        minSpeedKmh: 0,
      ).clientId;
      _telemetryService.startSession(sessionId);

      // Trigger non-blocking deletion of telemetry older than 14 days
      unawaited(_telemetryService.cleanOldLogs(14).catchError((_) {}));

      // Haptic feedback & wakelock for OLED handlebar display
      try {
        HapticFeedback.heavyImpact();
      } catch (_) {}

      if (!isTestEnvironment) {
        try {
          await WakelockPlus.enable();
        } catch (_) {}

        // Check & request location permission
        try {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
            if (permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) {
              logTelemetryError('location_permission_denied', {
                'permission': permission.toString(),
              });
              return false;
            }
          }
          if (permission == LocationPermission.deniedForever) {
            logTelemetryError('location_permission_denied_forever');
            return false;
          }
        } catch (e) {
          logTelemetryError('location_permission_error', {
            'error': e.toString(),
          });
        }
      }

      isRiding = true;
      startTime = DateTime.now();
      _lastPositionTime = null;
      durationSeconds = 0;
      distanceMeters = 0.0;
      currentSpeedKmh = 0.0;
      maxSpeedKmh = 0.0;
      minSpeedKmh = 0.0;
      routePoints = [];

      // Log RIDE_START telemetry event
      _telemetryService.logEvent(
        eventType: 'RIDE_START',
        metadata: {
          'reminder_minutes': reminderMinutes,
          'start_time': startTime!.toUtc().toIso8601String(),
        },
      );

      // Save initial active ride snapshot
      await _saveActiveRideSnapshot();

      // Notification #1
      try {
        await _notificationService.showNotification(
          1,
          '🚴 بدأت الرحلة!',
          'العداد شغال دلوقتي.. طريق السلامة يا بطل',
        );
      } catch (_) {}

      // Schedule periodic reminder on iOS (ID: 3)
      try {
        await _notificationService.periodicallyShowWithDuration(
          3,
          '🤔 لسه راكب العجلة؟',
          'عدى $reminderMinutes دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟',
          Duration(minutes: reminderMinutes),
        );
      } catch (_) {}

      // 1-second periodic timer for live display sync and speed zeroing
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (startTime != null) {
          durationSeconds = DateTime.now().difference(startTime!).inSeconds;
        }

        // Zero speed after 3 seconds of no new GPS update
        if (_lastPositionTime != null &&
            DateTime.now().difference(_lastPositionTime!).inSeconds >= 3 &&
            currentSpeedKmh > 0.0) {
          currentSpeedKmh = 0.0;
        }

        notifyListeners();
      });

      // Periodic snapshot timer: save every 10 seconds
      _snapshotTimer?.cancel();
      if (!isTestEnvironment) {
        _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          _saveActiveRideSnapshot();
        });
      }

      // Start GPS stream with Apple background settings
      try {
        final appleSettings = AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          allowBackgroundLocationUpdates: true,
          pauseLocationUpdatesAutomatically: false,
          showBackgroundLocationIndicator: true,
        );

        _positionStreamSubscription?.cancel();
        _positionStreamSubscription = Geolocator.getPositionStream(
          locationSettings: appleSettings,
        ).listen(
          processPositionUpdate,
          onError: (error) {
            logTelemetryError('gps_stream_error', {'error': error.toString()});
          },
        );
      } catch (e) {
        // In headless test environments without hardware GPS stream
      }

      notifyListeners();
      return true;
    } finally {
      _isStarting = false;
    }
  }

  void processPositionUpdate(Position pos) {
    if (!isRiding) return;

    _lastPositionTime = DateTime.now();
    // Retain Position? currentPosition for immediate map centering
    currentPosition = pos;

    final rawSpeedKmh = (pos.speed > 0 ? pos.speed : 0.0) * 3.6;

    // 1. 20 m accuracy rejection
    if (pos.accuracy > 20.0) {
      currentSpeedKmh = 0.0;
      _telemetryService.logEvent(
        eventType: 'GPS_REJECTED',
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        accuracy: pos.accuracy,
        reason: 'accuracy',
        metadata: {
          'accuracy': pos.accuracy,
          'speed_kmh': rawSpeedKmh,
        },
      );
      notifyListeners();
      return;
    }

    // 2. First accurate-point anchor with no distance
    if (routePoints.isEmpty) {
      routePoints.add(LatLng(pos.latitude, pos.longitude));
      // Max/min updates from first accepted moving point
      if (rawSpeedKmh > 2.5 && rawSpeedKmh <= 65.0) {
        currentSpeedKmh = rawSpeedKmh;
        maxSpeedKmh = rawSpeedKmh;
        minSpeedKmh = rawSpeedKmh;
      } else {
        currentSpeedKmh = 0.0;
      }

      _telemetryService.logEvent(
        eventType: 'GPS_ACCEPTED',
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        accuracy: pos.accuracy,
        reason: null,
        metadata: {
          'anchor': true,
          'step_meters': 0.0,
          'distance_meters': distanceMeters,
          'speed_kmh': currentSpeedKmh,
          'route_points_count': routePoints.length,
        },
      );

      // Save snapshot on accepted GPS point
      _saveActiveRideSnapshot();
      notifyListeners();
      return;
    }

    // 3. 2.5 km/h Doppler stationary rejection
    if (rawSpeedKmh <= 2.5) {
      currentSpeedKmh = 0.0;
      _telemetryService.logEvent(
        eventType: 'GPS_REJECTED',
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        accuracy: pos.accuracy,
        reason: 'stationary',
        metadata: {
          'speed_kmh': rawSpeedKmh,
        },
      );
      notifyListeners();
      return;
    }

    // 4. 3 m micro-jitter rejection
    final last = routePoints.last;
    final stepMeters = Geolocator.distanceBetween(
      last.latitude,
      last.longitude,
      pos.latitude,
      pos.longitude,
    );
    if (stepMeters <= 3.0) {
      currentSpeedKmh = 0.0;
      _telemetryService.logEvent(
        eventType: 'GPS_REJECTED',
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        accuracy: pos.accuracy,
        reason: 'micro_jitter',
        metadata: {
          'step_meters': stepMeters,
          'speed_kmh': rawSpeedKmh,
        },
      );
      notifyListeners();
      return;
    }

    // 5. 65 km/h raw-speed spike rejection
    if (rawSpeedKmh > 65.0) {
      currentSpeedKmh = 0.0;
      _telemetryService.logEvent(
        eventType: 'GPS_REJECTED',
        latitude: pos.latitude,
        longitude: pos.longitude,
        speedMps: pos.speed,
        accuracy: pos.accuracy,
        reason: 'speed_spike',
        metadata: {
          'step_meters': stepMeters,
          'speed_kmh': rawSpeedKmh,
        },
      );
      notifyListeners();
      return;
    }

    // 6. Accepted-point distance/route/speed updates
    distanceMeters += stepMeters;
    routePoints.add(LatLng(pos.latitude, pos.longitude));
    currentSpeedKmh = rawSpeedKmh;

    if (currentSpeedKmh > maxSpeedKmh) {
      maxSpeedKmh = currentSpeedKmh;
    }
    if (minSpeedKmh == 0.0 || currentSpeedKmh < minSpeedKmh) {
      minSpeedKmh = currentSpeedKmh;
    }

    _telemetryService.logEvent(
      eventType: 'GPS_ACCEPTED',
      latitude: pos.latitude,
      longitude: pos.longitude,
      speedMps: pos.speed,
      accuracy: pos.accuracy,
      reason: null,
      metadata: {
        'step_meters': stepMeters,
        'distance_meters': distanceMeters,
        'speed_kmh': currentSpeedKmh,
        'route_points_count': routePoints.length,
      },
    );

    // Save snapshot on accepted GPS point
    _saveActiveRideSnapshot();
    notifyListeners();
  }

  void logTelemetryError(String reason, [Map<String, dynamic>? metadata]) {
    _telemetryService.logEvent(
      eventType: 'ERROR',
      reason: reason,
      metadata: metadata,
    );
  }

  void tickTimerForTest([int seconds = 1]) {
    for (int i = 0; i < seconds; i++) {
      durationSeconds++;
      if (durationSeconds > 0 &&
          durationSeconds % (reminderMinutes * 60) == 0) {
        reminderNotificationTriggerCount++;
      }
    }
    notifyListeners();
  }

  Future<void> stopRide() async {
    if (!isRiding) return;

    final isTestEnvironment =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    // Haptic feedback & disable wakelock
    try {
      HapticFeedback.heavyImpact();
      HapticFeedback.vibrate();
    } catch (_) {}
    if (!isTestEnvironment) {
      try {
        await WakelockPlus.disable();
      } catch (_) {}
    }

    isRiding = false;
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _timer?.cancel();
    _timer = null;
    _snapshotTimer?.cancel();
    _snapshotTimer = null;

    // Cancel periodic reminder
    try {
      await _notificationService.cancel(3);
    } catch (_) {}

    final double avgSpeedKmh;
    if (durationSeconds > 0 && distanceMeters > 0) {
      final calc = (distanceMeters / 1000.0) / (durationSeconds / 3600.0);
      avgSpeedKmh = (calc.isNaN || calc.isInfinite) ? 0.0 : calc;
    } else {
      avgSpeedKmh = 0.0;
    }

    final safeMaxSpeed = (maxSpeedKmh.isNaN || maxSpeedKmh.isInfinite) ? 0.0 : maxSpeedKmh;
    final safeMinSpeed = (minSpeedKmh.isNaN || minSpeedKmh.isInfinite) ? 0.0 : minSpeedKmh;

    // Log RIDE_STOP event with exact metadata
    _telemetryService.logEvent(
      eventType: 'RIDE_STOP',
      metadata: {
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'avg_speed_kmh': avgSpeedKmh,
        'max_speed_kmh': safeMaxSpeed,
        'min_speed_kmh': safeMinSpeed,
        'route_points_count': routePoints.length,
      },
    );

    // Flush buffered telemetry immediately on stop
    try {
      await _telemetryService.flush();
    } catch (_) {
      // Swallowed transport failure
    }

    final ride = RideModel(
      clientId: _activeRideClientId,
      startTime: startTime ?? DateTime.now(),
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: safeMaxSpeed,
      minSpeedKmh: safeMinSpeed,
    );

    // OFFLINE-FIRST: Save locally FIRST, then try to upload
    await _saveRideLocally(ride);

    // Clear active ride snapshot since ride is now saved
    await _clearActiveRideSnapshot();

    // Show ride in history immediately (before network call), deduplicated by clientId
    final existingIndex = ridesHistory.indexWhere((r) => r.clientId == ride.clientId);
    if (existingIndex >= 0) {
      ridesHistory[existingIndex] = ride;
    } else {
      ridesHistory.insert(0, ride);
    }
    notifyListeners();

    // Try to upload to Supabase
    try {
      await _supabaseService.insertRide(ride);
      ride.syncStatus = SyncStatus.synced;
      await _removePendingRide(ride.clientId);
    } catch (e) {
      logTelemetryError('save_ride_error', {'error': e.toString()});
      // Ride stays in pending queue for later sync
    }

    try {
      await _notificationService.showNotification(
        2,
        '🏁 انتهت الرحلة!',
        'عاش يا نجم! مشيت ${(distanceMeters / 1000).toStringAsFixed(2)} كم في ${(durationSeconds / 60).floor()} دقيقة',
      );
    } catch (_) {}

    // Cache the updated history
    await _saveCachedHistory();
    notifyListeners();
  }

  // ─── MANUAL RIDE ENTRY ───────────────────────────────────────────────

  /// Add a manual ride entry from the Dashboard (for missed/lost rides).
  /// Requires actual confirmed values: startTime, durationSeconds, distanceMeters.
  /// Calculates avgSpeedKmh from the provided values.
  Future<void> addManualRide({
    required DateTime startTime,
    required int durationSeconds,
    required double distanceMeters,
  }) async {
    final double avgSpeedKmh;
    if (durationSeconds > 0 && distanceMeters > 0) {
      final calc = (distanceMeters / 1000.0) / (durationSeconds / 3600.0);
      avgSpeedKmh = (calc.isNaN || calc.isInfinite) ? 0.0 : calc;
    } else {
      avgSpeedKmh = 0.0;
    }

    final ride = RideModel(
      startTime: startTime,
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: 0.0, // Unknown for manual entry
      minSpeedKmh: 0.0, // Unknown for manual entry
      isManual: true,
    );

    // Save locally first
    await _saveRideLocally(ride);

    // Add to history immediately, deduplicated by clientId
    final existingIdx = ridesHistory.indexWhere((r) => r.clientId == ride.clientId);
    if (existingIdx >= 0) {
      ridesHistory[existingIdx] = ride;
    } else {
      ridesHistory.insert(0, ride);
    }
    ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));
    notifyListeners();

    // Try to upload
    try {
      await _supabaseService.insertRide(ride);
      ride.syncStatus = SyncStatus.synced;
      await _removePendingRide(ride.clientId);
    } catch (e) {
      logTelemetryError('manual_ride_sync_error', {'error': e.toString()});
    }

    await _saveCachedHistory();
    notifyListeners();
  }

  // ─── OFFLINE-FIRST PERSISTENCE ──────────────────────────────────────

  /// Save a ride to the pending sync queue in SharedPreferences.
  Future<void> _saveRideLocally(RideModel ride) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefPendingSyncRidesKey);
      final List<Map<String, dynamic>> queue = raw != null
          ? (jsonDecode(raw) as List<dynamic>)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
          : [];

      // Prevent duplicates by clientId
      if (!queue.any((r) => r['client_id'] == ride.clientId)) {
        queue.add(ride.toLocalJson());
        await prefs.setString(_prefPendingSyncRidesKey, jsonEncode(queue));
      }
    } catch (_) {}
  }

  /// Remove a ride from the pending queue after successful sync.
  Future<void> _removePendingRide(String clientId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefPendingSyncRidesKey);
      if (raw == null) return;

      final List<Map<String, dynamic>> queue = (jsonDecode(raw) as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      queue.removeWhere((r) => r['client_id'] == clientId);
      await prefs.setString(_prefPendingSyncRidesKey, jsonEncode(queue));
    } catch (_) {}
  }

  /// Load pending rides from SharedPreferences.
  Future<List<RideModel>> _loadPendingRides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefPendingSyncRidesKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) =>
              RideModel.fromLocalJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Sync all pending rides to Supabase.
  Future<void> _syncPendingRides() async {
    final pending = await _loadPendingRides();
    if (pending.isEmpty) return;

    for (final ride in pending) {
      try {
        await _supabaseService.insertRide(ride);
        ride.syncStatus = SyncStatus.synced;
        for (final r in ridesHistory) {
          if (r.clientId == ride.clientId) {
            r.syncStatus = SyncStatus.synced;
          }
        }
        await _removePendingRide(ride.clientId);
      } catch (_) {
        // Will retry on next sync
        break; // Stop on first failure (likely no network)
      }
    }
  }

  /// Public entry point to trigger synchronization of pending offline rides.
  Future<void> syncPendingRides() async {
    await _syncPendingRides();
    await _saveCachedHistory();
    notifyListeners();
  }

  /// Save ride history cache to SharedPreferences.
  Future<void> _saveCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = ridesHistory.map((r) => r.toLocalJson()).toList();
      await prefs.setString(_prefCachedRidesHistoryKey, jsonEncode(data));
    } catch (_) {}
  }

  /// Load cached ride history from SharedPreferences.
  Future<void> _loadCachedHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefCachedRidesHistoryKey);
      if (raw == null || raw.isEmpty) return;

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final decodedRides = decoded
          .map((e) =>
              RideModel.fromLocalJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      // Deduplicate by clientId
      final seenClientIds = <String>{};
      final deduped = <RideModel>[];
      for (final r in decodedRides) {
        if (seenClientIds.add(r.clientId)) {
          deduped.add(r);
        }
      }
      ridesHistory = deduped;

      // Merge with any pending rides
      final pending = await _loadPendingRides();
      for (final p in pending) {
        final existingIdx = ridesHistory.indexWhere((r) => r.clientId == p.clientId);
        if (existingIdx == -1) {
          ridesHistory.add(p);
        } else {
          ridesHistory[existingIdx].syncStatus = SyncStatus.pending;
        }
      }

      ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));
      notifyListeners();
    } catch (_) {}
  }

  // ─── ACTIVE RIDE SNAPSHOT (Crash Recovery) ──────────────────────────

  /// Save current ride state as a snapshot for crash recovery.
  Future<void> _saveActiveRideSnapshot() async {
    if (!isRiding || startTime == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final snapshot = <String, dynamic>{
        'client_id': _activeRideClientId,
        'start_time': startTime!.toIso8601String(),
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'max_speed_kmh': maxSpeedKmh,
        'min_speed_kmh': minSpeedKmh,
        'route_points_count': routePoints.length,
        'snapshot_time': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_prefActiveRideSnapshotKey, jsonEncode(snapshot));
    } catch (_) {}
  }

  /// Clear active ride snapshot after ride is properly saved.
  Future<void> _clearActiveRideSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveRideSnapshotKey);
    } catch (_) {}
  }

  /// Recover an interrupted ride from snapshot and save it as a local ride.
  Future<void> _recoverInterruptedRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefActiveRideSnapshotKey);
      if (raw == null || raw.isEmpty) return;

      final snapshot = jsonDecode(raw) as Map<String, dynamic>;

      // Calculate duration prioritizing recorded duration_seconds
      final snapDuration = (snapshot['duration_seconds'] as num?)?.toInt() ?? 0;
      final snapStartTime = DateTime.parse(snapshot['start_time'] as String);
      final snapTime = DateTime.parse(snapshot['snapshot_time'] as String);
      final elapsedFromWallClock = snapTime.difference(snapStartTime).inSeconds;
      final totalDuration = snapDuration > 0
          ? snapDuration
          : (elapsedFromWallClock > 0 ? elapsedFromWallClock : 0);

      final recoveredDistance =
          (snapshot['distance_meters'] as num).toDouble();
      final double avgSpeed;
      if (totalDuration > 0 && recoveredDistance > 0) {
        final calc = (recoveredDistance / 1000.0) / (totalDuration / 3600.0);
        avgSpeed = (calc.isNaN || calc.isInfinite) ? 0.0 : calc;
      } else {
        avgSpeed = 0.0;
      }

      final maxSpeed = (snapshot['max_speed_kmh'] as num).toDouble();
      final minSpeed = (snapshot['min_speed_kmh'] as num).toDouble();

      final recoveredRide = RideModel(
        clientId: snapshot['client_id'] as String?,
        startTime: snapStartTime,
        durationSeconds: totalDuration,
        distanceMeters: recoveredDistance,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: (maxSpeed.isNaN || maxSpeed.isInfinite) ? 0.0 : maxSpeed,
        minSpeedKmh: (minSpeed.isNaN || minSpeed.isInfinite) ? 0.0 : minSpeed,
      );

      // Save locally and add to history
      await _saveRideLocally(recoveredRide);

      final existingIdx = ridesHistory.indexWhere((r) => r.clientId == recoveredRide.clientId);
      if (existingIdx >= 0) {
        ridesHistory[existingIdx] = recoveredRide;
      } else {
        ridesHistory.insert(0, recoveredRide);
      }
      ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Clear the snapshot
      await prefs.remove(_prefActiveRideSnapshotKey);

      logTelemetryError('ride_recovered_from_snapshot', {
        'client_id': recoveredRide.clientId,
        'duration_seconds': totalDuration,
        'distance_meters': recoveredDistance,
      });
    } catch (_) {}
  }

  // ─── STATISTICS HELPERS FOR DASHBOARD ───────────────────────────────

  double get todayDistanceKm {
    final now = DateTime.now();
    final todayRides = ridesHistory.where((r) =>
        r.startTime.year == now.year &&
        r.startTime.month == now.month &&
        r.startTime.day == now.day);
    final totalMeters =
        todayRides.fold<double>(0.0, (sum, r) => sum + r.distanceMeters);
    return totalMeters / 1000.0;
  }

  int get todayDurationSeconds {
    final now = DateTime.now();
    final todayRides = ridesHistory.where((r) =>
        r.startTime.year == now.year &&
        r.startTime.month == now.month &&
        r.startTime.day == now.day);
    return todayRides.fold<int>(0, (sum, r) => sum + r.durationSeconds);
  }

  double get todayMaxSpeedKmh {
    final now = DateTime.now();
    final todayRides = ridesHistory.where((r) =>
        r.startTime.year == now.year &&
        r.startTime.month == now.month &&
        r.startTime.day == now.day);
    if (todayRides.isEmpty) return 0.0;
    return todayRides
        .map((r) => r.maxSpeedKmh)
        .reduce((a, b) => a > b ? a : b);
  }

  double get weeklyDistanceKm {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final weekRides =
        ridesHistory.where((r) => r.startTime.isAfter(sevenDaysAgo));
    final totalMeters =
        weekRides.fold<double>(0.0, (sum, r) => sum + r.distanceMeters);
    return totalMeters / 1000.0;
  }

  int get weeklyRidesCount {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return ridesHistory.where((r) => r.startTime.isAfter(sevenDaysAgo)).length;
  }

  List<DailyStat> get weeklyDailyStats {
    final now = DateTime.now();
    final List<DailyStat> stats = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayRides = ridesHistory.where((r) =>
          r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day);
      final totalKm =
          dayRides.fold<double>(0.0, (sum, r) => sum + r.distanceMeters) /
              1000.0;
      stats.add(DailyStat(date: date, distanceKm: totalKm));
    }
    return stats;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _snapshotTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _telemetryService.dispose();
    try {
      _notificationService.cancel(3);
    } catch (_) {}
    super.dispose();
  }
}

class DailyStat {
  final DateTime date;
  final double distanceKm;
  DailyStat({required this.date, required this.distanceKm});
}
