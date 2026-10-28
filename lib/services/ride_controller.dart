import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../models/analytics_models.dart';
import '../models/ride_model.dart';
import 'notification_service.dart';
import 'share_service.dart';
import 'supabase_service.dart';
import 'telemetry_service.dart';

enum RideState {
  idle,
  recording,
  paused,
}

class RideController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final INotificationService _notificationService;
  final ITelemetryService _telemetryService;
  final IShareService _shareService;

  RideState state = RideState.idle;
  bool isRiding = false;
  bool _isStarting = false;

  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  set startTime(DateTime? val) {
    _startTime = val;
    if (state == RideState.recording &&
        currentSegmentStartTime != null &&
        accumulatedActiveSeconds == 0) {
      currentSegmentStartTime = val;
    }
  }

  DateTime? _lastPositionTime;
  int durationSeconds = 0;
  int accumulatedActiveSeconds = 0;
  DateTime? currentSegmentStartTime;

  DateTime Function() _clock = DateTime.now;

  /// Injects a custom clock for deterministic testing.
  @visibleForTesting
  void setClockForTest(DateTime Function() clock) {
    _clock = clock;
  }

  bool get isPaused => state == RideState.paused;
  bool get isRecording => state == RideState.recording;

  final bool promptRecoveryOnInterrupted;
  Map<String, dynamic>? interruptedRideSnapshot;
  bool get hasInterruptedRide => interruptedRideSnapshot != null;

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
  static const String _prefPendingDeletesKey = 'pending_delete_rides';

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

  /// Current hydration & rest reminder interval in minutes.
  int get reminderIntervalMinutes => reminderMinutes;

  /// Updates the reminder interval by [delta] minutes (clamped between 5 and 180).
  Future<void> updateReminderIntervalDelta(int delta) async {
    final newVal = (reminderMinutes + delta).clamp(5, 180);
    if (newVal != reminderMinutes) {
      reminderMinutes = newVal;
      notifyListeners();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_prefReminderKey, reminderMinutes);
      } catch (_) {}
    }
  }

  /// Trigger active ride snapshot for testing crash recovery.
  Future<void> saveActiveRideSnapshotForTest() async {
    await _saveActiveRideSnapshot();
  }

  /// Trigger interrupted ride recovery for testing.
  @visibleForTesting
  Future<void> recoverInterruptedRideForTest() async {
    await _recoverInterruptedRide();
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
    IShareService? shareService,
    bool autoFetchHistory = true,
    bool autoLoadPreferences = true,
    this.promptRecoveryOnInterrupted = false,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _notificationService = notificationService ?? NotificationService(),
        _telemetryService = telemetryService ?? TelemetryService(),
        _shareService = shareService ?? SharePlusService() {
    if (autoLoadPreferences) {
      _initPrefsFuture = _initPreferences();
    }
    if (autoFetchHistory) {
      _initOfflineFirst();
    }
  }

  ITelemetryService get telemetryService => _telemetryService;
  IShareService get shareService => _shareService;

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

    // Only reschedule notification if actively recording!
    // If paused, notification remains canceled until resumeRide() is called.
    if (isRecording) {
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
      // If network fails, ensure pending rides are loaded into history
      if (ridesHistory.isEmpty) {
        final pending = await _loadPendingRides();
        if (pending.isNotEmpty) {
          ridesHistory = pending;
          ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));
          notifyListeners();
        }
      }
      logTelemetryError('fetch_merge_error', {'error': e.toString()});
    }
  }

  Future<bool> startRide() async {
    if (isRiding) return true;
    if (_isStarting) return false;

    // Prevent starting a new ride if an interrupted session is awaiting recovery
    if (hasInterruptedRide) {
      logTelemetryError('start_ride_blocked_interrupted_ride_exists');
      return false;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (promptRecoveryOnInterrupted && prefs.containsKey(_prefActiveRideSnapshotKey)) {
        final raw = prefs.getString(_prefActiveRideSnapshotKey);
        if (raw != null && raw.isNotEmpty) {
          interruptedRideSnapshot = jsonDecode(raw) as Map<String, dynamic>;
          notifyListeners();
          logTelemetryError('start_ride_blocked_interrupted_ride_exists');
          return false;
        }
      }
    } catch (_) {}

    _isStarting = true;
    try {
      final isTestEnvironment =
          !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

      // Generate a unique session ID for this ride
      final sessionId = 'ride_${_clock().millisecondsSinceEpoch}';
      currentSessionId = sessionId;
      _activeRideClientId = RideModel(
        startTime: _clock(),
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

      state = RideState.recording;
      isRiding = true;
      accumulatedActiveSeconds = 0;
      currentSegmentStartTime = _clock();
      _startTime = currentSegmentStartTime;
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
        if (state == RideState.recording && currentSegmentStartTime != null) {
          final segSeconds = _clock().difference(currentSegmentStartTime!).inSeconds;
          durationSeconds = accumulatedActiveSeconds + (segSeconds > 0 ? segSeconds : 0);
        } else if (state == RideState.paused) {
          durationSeconds = accumulatedActiveSeconds;
        }

        // Zero speed after 3 seconds of no new GPS update (only while recording)
        if (state == RideState.recording &&
            _lastPositionTime != null &&
            _clock().difference(_lastPositionTime!).inSeconds >= 3 &&
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

  /// Pauses the active ride. Freezes moving duration and speed, stops route accumulation.
  Future<bool> pauseRide() async {
    if (state != RideState.recording) return false;

    if (currentSegmentStartTime != null) {
      final segSeconds = _clock().difference(currentSegmentStartTime!).inSeconds;
      if (segSeconds > 0) {
        accumulatedActiveSeconds += segSeconds;
      }
      currentSegmentStartTime = null;
    }
    durationSeconds = accumulatedActiveSeconds;
    state = RideState.paused;
    currentSpeedKmh = 0.0;

    // Cancel hydration reminder during pause so it doesn't disturb user
    try {
      await _notificationService.cancel(3);
    } catch (_) {}

    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    _telemetryService.logEvent(
      eventType: 'RIDE_PAUSED',
      latitude: currentPosition?.latitude,
      longitude: currentPosition?.longitude,
      metadata: {
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
      },
    );

    await _saveActiveRideSnapshot();
    notifyListeners();
    return true;
  }

  /// Resumes the paused ride. Starts a new active duration segment and reschedules reminder.
  Future<bool> resumeRide() async {
    if (state != RideState.paused) return false;

    state = RideState.recording;
    currentSegmentStartTime = _clock();
    _lastPositionTime = _clock();

    // Re-enable Wakelock to ensure display stays awake (critical after crash recovery)
    final isTestEnvironment =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    try {
      if (!isTestEnvironment) {
        await WakelockPlus.enable();
      }
    } catch (_) {}

    // Reschedule reminder with full duration
    try {
      await _notificationService.cancel(3);
      await _notificationService.periodicallyShowWithDuration(
        3,
        '🤔 لسه راكب العجلة؟',
        'عدى $reminderMinutes دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟',
        Duration(minutes: reminderMinutes),
      );
    } catch (_) {}

    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}

    _telemetryService.logEvent(
      eventType: 'RIDE_RESUMED',
      latitude: currentPosition?.latitude,
      longitude: currentPosition?.longitude,
      metadata: {
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
      },
    );

    await _saveActiveRideSnapshot();
    notifyListeners();
    return true;
  }

  void processPositionUpdate(Position pos) {
    if (!isRiding) return;

    _lastPositionTime = _clock();
    // Retain Position? currentPosition for immediate map centering
    currentPosition = pos;

    // While paused: retain currentPosition for map centering, but ignore distance and route points!
    if (state == RideState.paused) {
      currentSpeedKmh = 0.0;
      notifyListeners();
      return;
    }

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
      if (state == RideState.recording) {
        accumulatedActiveSeconds++;
        durationSeconds = accumulatedActiveSeconds;
        if (durationSeconds > 0 &&
            durationSeconds % (reminderMinutes * 60) == 0) {
          reminderNotificationTriggerCount++;
        }
      }
    }
    // Mirror periodic timer: zero speed if no GPS update for >= 3s (only when recording)
    if (state == RideState.recording &&
        _lastPositionTime != null &&
        _clock().difference(_lastPositionTime!).inSeconds >= 3 &&
        currentSpeedKmh > 0.0) {
      currentSpeedKmh = 0.0;
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

    // Finalize duration from active segment without Wall-Clock leakage from pause
    if (state == RideState.recording && currentSegmentStartTime != null) {
      final segSeconds = _clock().difference(currentSegmentStartTime!).inSeconds;
      if (segSeconds > 0) {
        accumulatedActiveSeconds += segSeconds;
      }
      currentSegmentStartTime = null;
    }
    durationSeconds = accumulatedActiveSeconds;
    if (durationSeconds < 0) {
      durationSeconds = 0;
    }

    state = RideState.idle;
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
      routePoints: List<LatLng>.from(routePoints),
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
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefPendingSyncRidesKey);
      } catch (_) {}
      return [];
    }
  }

  /// Sync all pending rides to Supabase.
  Future<void> _syncPendingRides() async {
    await _syncPendingDeletes();
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

  /// Sync queued remote deletions to Supabase.
  Future<void> _syncPendingDeletes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_prefPendingDeletesKey) ?? [];
      if (raw.isEmpty) return;

      final remaining = <String>[];
      for (final clientId in raw) {
        try {
          await _supabaseService.deleteRide(clientId);
        } catch (_) {
          remaining.add(clientId);
        }
      }
      if (remaining.isEmpty) {
        await prefs.remove(_prefPendingDeletesKey);
      } else {
        await prefs.setStringList(_prefPendingDeletesKey, remaining);
      }
    } catch (_) {}
  }

  /// Delete a ride locally and from Supabase.
  Future<void> deleteRide(String clientId, [int? supabaseId]) async {
    // 1. Remove from local history immediately
    ridesHistory.removeWhere((r) => r.clientId == clientId);
    await _removePendingRide(clientId);
    await _saveCachedHistory();
    notifyListeners();

    // 2. Delete remotely via Supabase (or queue for later if offline)
    try {
      await _supabaseService.deleteRide(clientId, supabaseId);
    } catch (e) {
      logTelemetryError('delete_ride_remote_error', {
        'client_id': clientId,
        'error': e.toString(),
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getStringList(_prefPendingDeletesKey) ?? [];
        if (!raw.contains(clientId)) {
          raw.add(clientId);
          await prefs.setStringList(_prefPendingDeletesKey, raw);
        }
      } catch (_) {}
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

      final deduped = <RideModel>[];
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final decodedRides = decoded
            .map((e) =>
                RideModel.fromLocalJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        // Deduplicate by clientId
        final seenClientIds = <String>{};
        for (final r in decodedRides) {
          if (seenClientIds.add(r.clientId)) {
            deduped.add(r);
          }
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
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_prefCachedRidesHistoryKey);
      } catch (_) {}
    }
  }

  // ─── ACTIVE RIDE SNAPSHOT (Crash Recovery) ──────────────────────────

  /// Save current ride state as a snapshot for crash recovery.
  Future<void> _saveActiveRideSnapshot() async {
    if (!isRiding || startTime == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final int exactActiveDuration;
      if (state == RideState.recording && currentSegmentStartTime != null) {
        final seg = _clock().difference(currentSegmentStartTime!).inSeconds;
        exactActiveDuration = accumulatedActiveSeconds + (seg > 0 ? seg : 0);
      } else {
        exactActiveDuration = accumulatedActiveSeconds;
      }
      durationSeconds = exactActiveDuration;

      final snapshot = <String, dynamic>{
        'client_id': _activeRideClientId,
        'start_time': startTime!.toIso8601String(),
        'state': state.name,
        'is_paused': state == RideState.paused,
        'accumulated_active_seconds': exactActiveDuration,
        'duration_seconds': exactActiveDuration,
        'current_segment_start_time': currentSegmentStartTime?.toIso8601String(),
        'distance_meters': distanceMeters,
        'max_speed_kmh': maxSpeedKmh,
        'min_speed_kmh': minSpeedKmh,
        'route_points': routePoints
            .map((point) => [point.latitude, point.longitude])
            .toList(),
        'route_points_count': routePoints.length,
        'snapshot_time': _clock().toIso8601String(),
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

  /// Recover an interrupted ride from snapshot and either prompt or save as local ride.
  Future<void> _recoverInterruptedRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefActiveRideSnapshotKey);
      if (raw == null || raw.isEmpty) return;

      final snapshot = jsonDecode(raw) as Map<String, dynamic>;

      if (promptRecoveryOnInterrupted) {
        interruptedRideSnapshot = snapshot;
        notifyListeners();
        return;
      }

      await saveInterruptedRideAsFinished(snapshot);
    } catch (_) {}
  }

  /// Restores an interrupted ride from snapshot into active session (in Paused state).
  Future<bool> restoreInterruptedRide() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefActiveRideSnapshotKey);
    final snapshot = interruptedRideSnapshot ??
        (raw != null ? jsonDecode(raw) as Map<String, dynamic> : null);
    if (snapshot == null) return false;

    final isTestEnvironment =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

    _activeRideClientId = snapshot['client_id'] as String?;
    final snapStartTime =
        DateTime.tryParse(snapshot['start_time'] as String? ?? '') ?? _clock();
    _startTime = snapStartTime;

    final isPaused = snapshot['is_paused'] as bool? ??
        (snapshot['state'] == RideState.paused.name);
    final rawAccumulated =
        (snapshot['accumulated_active_seconds'] as num?)?.toInt() ?? 0;
    final rawDuration =
        (snapshot['duration_seconds'] as num?)?.toInt() ?? 0;
    int recoveredDuration =
        rawAccumulated > rawDuration ? rawAccumulated : rawDuration;

    if (recoveredDuration == 0 && !isPaused) {
      final snapTime =
          DateTime.tryParse(snapshot['snapshot_time'] as String? ?? '');
      if (snapTime != null) {
        final elapsed = snapTime.difference(snapStartTime).inSeconds;
        if (elapsed > 0) {
          recoveredDuration = elapsed;
        }
      }
    }

    accumulatedActiveSeconds = recoveredDuration;
    durationSeconds = accumulatedActiveSeconds;
    distanceMeters = (snapshot['distance_meters'] as num?)?.toDouble() ?? 0.0;
    maxSpeedKmh = (snapshot['max_speed_kmh'] as num?)?.toDouble() ?? 0.0;
    minSpeedKmh = (snapshot['min_speed_kmh'] as num?)?.toDouble() ?? 0.0;

    final savedRoutePoints = (snapshot['route_points'] as List<dynamic>? ??
            const <dynamic>[])
        .map((point) {
          if (point is List &&
              point.length >= 2 &&
              point[0] is num &&
              point[1] is num) {
            return LatLng(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            );
          }
          return null;
        })
        .whereType<LatLng>()
        .toList();
    routePoints = savedRoutePoints;

    // Always restore in Paused state so the rider can choose when to resume
    state = RideState.paused;
    isRiding = true;
    currentSegmentStartTime = null;
    currentSpeedKmh = 0.0;
    currentSessionId = 'ride_${_clock().millisecondsSinceEpoch}';
    _telemetryService.startSession(currentSessionId!);

    // Re-enable Wakelock for the restored cockpit session
    try {
      if (!isTestEnvironment) {
        await WakelockPlus.enable();
      }
    } catch (_) {}

    if (routePoints.isNotEmpty) {
      currentPosition = Position(
        latitude: routePoints.last.latitude,
        longitude: routePoints.last.longitude,
        timestamp: _clock(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state == RideState.recording && currentSegmentStartTime != null) {
        final segSeconds = _clock().difference(currentSegmentStartTime!).inSeconds;
        durationSeconds = accumulatedActiveSeconds + (segSeconds > 0 ? segSeconds : 0);
      } else if (state == RideState.paused) {
        durationSeconds = accumulatedActiveSeconds;
      }
      if (state == RideState.recording &&
          _lastPositionTime != null &&
          _clock().difference(_lastPositionTime!).inSeconds >= 3 &&
          currentSpeedKmh > 0.0) {
        currentSpeedKmh = 0.0;
      }
      notifyListeners();
    });

    _snapshotTimer?.cancel();
    if (!isTestEnvironment) {
      _snapshotTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _saveActiveRideSnapshot();
      });
    }

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
      ).listen(processPositionUpdate);
    } catch (_) {}

    interruptedRideSnapshot = null;
    await _saveActiveRideSnapshot();
    notifyListeners();
    return true;
  }

  /// Saves the interrupted ride snapshot as a completed ride to history.
  Future<void> saveInterruptedRideAsFinished([Map<String, dynamic>? snap]) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefActiveRideSnapshotKey);
      final snapshot = snap ?? interruptedRideSnapshot ??
          (raw != null ? jsonDecode(raw) as Map<String, dynamic> : null);
      if (snapshot == null) return;

      final isPaused = snapshot['is_paused'] as bool? ??
          (snapshot['state'] == RideState.paused.name);
      final rawAccumulated =
          (snapshot['accumulated_active_seconds'] as num?)?.toInt() ?? 0;
      final rawDuration =
          (snapshot['duration_seconds'] as num?)?.toInt() ?? 0;
      final snapDuration =
          rawAccumulated > rawDuration ? rawAccumulated : rawDuration;
      final snapStartTime =
          DateTime.tryParse(snapshot['start_time'] as String? ?? '') ?? _clock();
      final snapTime =
          DateTime.tryParse(snapshot['snapshot_time'] as String? ?? '');
      final elapsedFromWallClock =
          (snapTime != null)
              ? snapTime.difference(snapStartTime).inSeconds
              : 0;

      final int totalDuration;
      if (snapDuration > 0) {
        totalDuration = snapDuration;
      } else if (isPaused) {
        // Paused state preserves frozen duration (even if 0) - NEVER inflate with paused gap!
        totalDuration = snapDuration;
      } else {
        // Legacy fallback only for unpaused snapshots with 0 duration recorded
        totalDuration = elapsedFromWallClock > 0 ? elapsedFromWallClock : 0;
      }

      final recoveredDistance =
          (snapshot['distance_meters'] as num?)?.toDouble() ?? 0.0;
      final double avgSpeed;
      if (totalDuration > 0 && recoveredDistance > 0) {
        final calc = (recoveredDistance / 1000.0) / (totalDuration / 3600.0);
        avgSpeed = (calc.isNaN || calc.isInfinite) ? 0.0 : calc;
      } else {
        avgSpeed = 0.0;
      }

      final maxSpeed = (snapshot['max_speed_kmh'] as num?)?.toDouble() ?? 0.0;
      final minSpeed = (snapshot['min_speed_kmh'] as num?)?.toDouble() ?? 0.0;
      final savedRoutePoints = (snapshot['route_points'] as List<dynamic>? ??
              const <dynamic>[])
          .map((point) {
            if (point is List &&
                point.length >= 2 &&
                point[0] is num &&
                point[1] is num) {
              return LatLng(
                (point[0] as num).toDouble(),
                (point[1] as num).toDouble(),
              );
            }
            return null;
          })
          .whereType<LatLng>()
          .toList();

      final recoveredRide = RideModel(
        clientId: snapshot['client_id'] as String?,
        startTime: snapStartTime,
        durationSeconds: totalDuration,
        distanceMeters: recoveredDistance,
        avgSpeedKmh: avgSpeed,
        maxSpeedKmh: (maxSpeed.isNaN || maxSpeed.isInfinite) ? 0.0 : maxSpeed,
        minSpeedKmh: (minSpeed.isNaN || minSpeed.isInfinite) ? 0.0 : minSpeed,
        routePoints: savedRoutePoints,
      );

      await _saveRideLocally(recoveredRide);

      final existingIdx = ridesHistory.indexWhere((r) => r.clientId == recoveredRide.clientId);
      if (existingIdx >= 0) {
        ridesHistory[existingIdx] = recoveredRide;
      } else {
        ridesHistory.insert(0, recoveredRide);
      }
      ridesHistory.sort((a, b) => b.startTime.compareTo(a.startTime));

      // Save cached history BEFORE removing active ride snapshot (offline-first pattern)
      await _saveCachedHistory();

      // Clear the snapshot
      await prefs.remove(_prefActiveRideSnapshotKey);
      interruptedRideSnapshot = null;

      logTelemetryError('ride_recovered_from_snapshot', {
        'client_id': recoveredRide.clientId,
        'duration_seconds': totalDuration,
        'distance_meters': recoveredDistance,
      });
      notifyListeners();

      // Subsequent sync step to Supabase (non-blocking)
      try {
        await _supabaseService.insertRide(recoveredRide);
        recoveredRide.syncStatus = SyncStatus.synced;
        await _removePendingRide(recoveredRide.clientId);
        await _saveCachedHistory();
        notifyListeners();
      } catch (_) {
        // Retained in pending queue for automatic retry
      }
    } catch (_) {}
  }

  /// Discards the interrupted ride snapshot without saving.
  Future<void> discardInterruptedRide() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefActiveRideSnapshotKey);
      interruptedRideSnapshot = null;
      notifyListeners();
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

  double get totalKilometers {
    return ridesHistory.fold<double>(0.0, (sum, r) => sum + r.distanceMeters) / 1000.0;
  }

  double get weeklyDistanceKm {
    return weeklyDailyStats.fold<double>(0.0, (sum, s) => sum + s.totalDistanceKm);
  }

  int get weeklyRidesCount {
    return weeklyDailyStats.fold<int>(0, (sum, s) => sum + s.rideCount);
  }

  List<DaySummary> get weeklyDailyStats {
    final now = _clock().toLocal();
    final List<DaySummary> stats = [];
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      stats.add(getDaySummary(date, includeActiveRide: (i == 0)));
    }
    return stats;
  }

  /// Calculates a complete summary of rides on a specific local calendar date.
  /// If [includeActiveRide] is true and a ride is currently active on [date],
  /// its live metrics and route points are temporarily included in the summary.
  DaySummary getDaySummary(DateTime date, {bool includeActiveRide = false}) {
    final target = date.toLocal();
    final dayRides = ridesHistory.where((r) {
      final l = r.startTime.toLocal();
      return l.year == target.year && l.month == target.month && l.day == target.day;
    }).toList();

    bool addedActive = false;
    if (includeActiveRide && isRiding && startTime != null) {
      final activeLocal = startTime!.toLocal();
      if (activeLocal.year == target.year &&
          activeLocal.month == target.month &&
          activeLocal.day == target.day) {
        final currentDuration = durationSeconds;
        final currentDistance = distanceMeters;
        final double currentAvgSpeed = (currentDuration > 0 && currentDistance > 0)
            ? ((currentDistance / 1000.0) / (currentDuration / 3600.0))
            : 0.0;
        final activeRide = RideModel(
          clientId: _activeRideClientId ?? 'active_transient',
          startTime: startTime!,
          durationSeconds: currentDuration,
          distanceMeters: currentDistance,
          avgSpeedKmh: (currentAvgSpeed.isNaN || currentAvgSpeed.isInfinite)
              ? 0.0
              : currentAvgSpeed,
          maxSpeedKmh: maxSpeedKmh,
          minSpeedKmh: minSpeedKmh,
          routePoints: List<LatLng>.from(routePoints),
        );
        dayRides.add(activeRide);
        addedActive = true;
      }
    }

    // Chronological order: morning to evening
    dayRides.sort((a, b) => a.startTime.compareTo(b.startTime));

    final totalDistance = dayRides.fold<double>(0.0, (sum, r) => sum + r.distanceMeters);
    final totalDuration = dayRides.fold<int>(0, (sum, r) => sum + r.durationSeconds);

    final double avgSpeed;
    if (totalDistance > 0 && totalDuration > 0) {
      final calc = (totalDistance / 1000.0) / (totalDuration / 3600.0);
      avgSpeed = (calc.isNaN || calc.isInfinite) ? 0.0 : calc;
    } else {
      avgSpeed = 0.0;
    }

    final validMaxSpeeds = dayRides
        .map((r) => r.maxSpeedKmh)
        .where((s) => s > 0 && !s.isNaN && !s.isInfinite)
        .toList();
    final double? maxSpeed = validMaxSpeeds.isNotEmpty
        ? validMaxSpeeds.reduce((a, b) => a > b ? a : b)
        : null;

    final validMinSpeeds = dayRides
        .map((r) => r.minSpeedKmh)
        .where((s) => s > 0 && !s.isNaN && !s.isInfinite)
        .toList();
    final double? minSpeed = validMinSpeeds.isNotEmpty
        ? validMinSpeeds.reduce((a, b) => a < b ? a : b)
        : null;

    final polylines = dayRides
        .map((r) => r.routePoints)
        .where((pts) => pts.length >= 2)
        .toList();

    return DaySummary(
      date: date,
      rides: dayRides,
      totalDistanceMeters: totalDistance,
      totalDurationSeconds: totalDuration,
      avgSpeedKmh: avgSpeed,
      maxSpeedKmh: maxSpeed,
      minSpeedKmh: minSpeed,
      rideCount: dayRides.length,
      hasGpsRoutes: polylines.isNotEmpty,
      allPolylines: polylines,
      includesActiveRide: addedActive,
    );
  }

  /// Calculates personal records from completed rides in history.
  PersonalRecords getPersonalRecords() {
    if (ridesHistory.isEmpty) {
      return const PersonalRecords();
    }

    RideModel? longest;
    for (final r in ridesHistory) {
      if (longest == null || r.distanceMeters > longest.distanceMeters) {
        longest = r;
      }
    }

    // Fastest ride by average speed (minimum 1000m to exclude 10-meter testing artifacts)
    RideModel? fastest;
    for (final r in ridesHistory) {
      if (r.distanceMeters >= 1000 && r.avgSpeedKmh > 0 && !r.avgSpeedKmh.isNaN && !r.avgSpeedKmh.isInfinite) {
        if (fastest == null || r.avgSpeedKmh > fastest.avgSpeedKmh) {
          fastest = r;
        }
      }
    }
    if (fastest == null) {
      for (final r in ridesHistory) {
        if (r.avgSpeedKmh > 0 && !r.avgSpeedKmh.isNaN && !r.avgSpeedKmh.isInfinite) {
          if (fastest == null || r.avgSpeedKmh > fastest.avgSpeedKmh) {
            fastest = r;
          }
        }
      }
    }

    // Most active day (group all rides by local date)
    final Map<String, double> dayDistances = {};
    final Map<String, DateTime> dayDates = {};
    for (final r in ridesHistory) {
      final l = r.startTime.toLocal();
      final key = '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
      dayDistances[key] = (dayDistances[key] ?? 0.0) + (r.distanceMeters / 1000.0);
      dayDates[key] ??= DateTime(l.year, l.month, l.day);
    }

    String? maxDayKey;
    double maxDayDist = 0.0;
    dayDistances.forEach((key, dist) {
      if (dist > maxDayDist) {
        maxDayDist = dist;
        maxDayKey = key;
      }
    });

    return PersonalRecords(
      longestRide: longest,
      fastestRide: fastest,
      mostActiveDayDate: maxDayKey != null ? dayDates[maxDayKey] : null,
      mostActiveDayDistanceKm: maxDayDist,
    );
  }

  /// Calculates aggregated summary and chart buckets for the specified period and metric.
  PeriodSummary getPeriodSummary({
    required AnalyticsPeriod period,
    required DateTime referenceDate,
    required AnalyticsMetric metric,
  }) {
    final refLocal = referenceDate.toLocal();
    final DateTime startDate;
    final DateTime endDate;
    final List<ChartBucket> buckets = [];

    switch (period) {
      case AnalyticsPeriod.day:
        startDate = DateTime(refLocal.year, refLocal.month, refLocal.day, 0, 0, 0);
        endDate = DateTime(refLocal.year, refLocal.month, refLocal.day, 23, 59, 59, 999);
        final daySummary = getDaySummary(referenceDate);
        if (daySummary.rides.isEmpty) {
          buckets.add(ChartBucket(label: '—', date: startDate, value: 0.0));
        } else {
          for (int i = 0; i < daySummary.rides.length; i++) {
            final r = daySummary.rides[i];
            final val = _extractMetricValue(r, metric);
            final hour = r.startTime.toLocal().hour;
            final min = r.startTime.toLocal().minute.toString().padLeft(2, '0');
            buckets.add(ChartBucket(
              label: '${hour.toString().padLeft(2, '0')}:$min',
              date: r.startTime.toLocal(),
              value: val,
            ));
          }
        }
        break;

      case AnalyticsPeriod.week:
        // Calendar week: Monday to Sunday
        final daysFromMonday = (refLocal.weekday - DateTime.monday) % 7;
        final monday = DateTime(refLocal.year, refLocal.month, refLocal.day).subtract(Duration(days: daysFromMonday));
        startDate = monday;
        endDate = monday.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59, milliseconds: 999));

        const arabicDays = ['إث', 'ثل', 'أر', 'خم', 'جم', 'سب', 'أح'];
        for (int i = 0; i < 7; i++) {
          final dayDate = monday.add(Duration(days: i));
          final summary = getDaySummary(dayDate);
          final val = _extractPeriodMetricValue(
            distanceMeters: summary.totalDistanceMeters,
            durationSeconds: summary.totalDurationSeconds,
            avgSpeedKmh: summary.avgSpeedKmh,
            rideCount: summary.rideCount,
            metric: metric,
          );
          final isToday = dayDate.year == _clock().toLocal().year &&
              dayDate.month == _clock().toLocal().month &&
              dayDate.day == _clock().toLocal().day;
          buckets.add(ChartBucket(
            label: arabicDays[i],
            date: dayDate,
            value: val,
            isHighlighted: isToday,
          ));
        }
        break;

      case AnalyticsPeriod.month:
        startDate = DateTime(refLocal.year, refLocal.month, 1);
        final nextMonth = DateTime(refLocal.year, refLocal.month + 1, 1);
        final lastDayOfMonth = nextMonth.subtract(const Duration(days: 1));
        endDate = DateTime(lastDayOfMonth.year, lastDayOfMonth.month, lastDayOfMonth.day, 23, 59, 59, 999);

        final totalDays = lastDayOfMonth.day;
        for (int d = 1; d <= totalDays; d++) {
          final dayDate = DateTime(refLocal.year, refLocal.month, d);
          final summary = getDaySummary(dayDate);
          final val = _extractPeriodMetricValue(
            distanceMeters: summary.totalDistanceMeters,
            durationSeconds: summary.totalDurationSeconds,
            avgSpeedKmh: summary.avgSpeedKmh,
            rideCount: summary.rideCount,
            metric: metric,
          );
          final isToday = dayDate.year == _clock().toLocal().year &&
              dayDate.month == _clock().toLocal().month &&
              dayDate.day == _clock().toLocal().day;
          buckets.add(ChartBucket(
            label: '$d',
            date: dayDate,
            value: val,
            isHighlighted: isToday,
          ));
        }
        break;

      case AnalyticsPeriod.year:
        startDate = DateTime(refLocal.year, 1, 1);
        endDate = DateTime(refLocal.year, 12, 31, 23, 59, 59, 999);

        const arabicMonths = ['ينا', 'فبر', 'مار', 'أبر', 'ماي', 'يون', 'يول', 'أغس', 'سبت', 'أكت', 'نوف', 'ديس'];
        for (int m = 1; m <= 12; m++) {
          final monthStart = DateTime(refLocal.year, m, 1);
          final monthRides = ridesHistory.where((r) {
            final l = r.startTime.toLocal();
            return l.year == refLocal.year && l.month == m;
          }).toList();

          final dist = monthRides.fold<double>(0.0, (s, r) => s + r.distanceMeters);
          final dur = monthRides.fold<int>(0, (s, r) => s + r.durationSeconds);
          final double avg = (dist > 0 && dur > 0)
              ? ((dist / 1000.0) / (dur / 3600.0))
              : 0.0;
          final val = _extractPeriodMetricValue(
            distanceMeters: dist,
            durationSeconds: dur,
            avgSpeedKmh: avg,
            rideCount: monthRides.length,
            metric: metric,
          );
          final isCurrentMonth = refLocal.year == _clock().toLocal().year && m == _clock().toLocal().month;
          buckets.add(ChartBucket(
            label: arabicMonths[m - 1],
            date: monthStart,
            value: val,
            isHighlighted: isCurrentMonth,
          ));
        }
        break;

      case AnalyticsPeriod.all:
        DateTime earliest = _clock().toLocal().subtract(const Duration(days: 365));
        for (final r in ridesHistory) {
          final l = r.startTime.toLocal();
          if (l.isBefore(earliest)) earliest = l;
        }
        startDate = DateTime(earliest.year, earliest.month, 1);
        endDate = _clock().toLocal();

        final nowLocal = _clock().toLocal();
        int totalMonths = (nowLocal.year - startDate.year) * 12 + (nowLocal.month - startDate.month) + 1;
        if (totalMonths <= 0) totalMonths = 1;
        if (totalMonths > 24) {
          for (int y = startDate.year; y <= nowLocal.year; y++) {
            final yearRides = ridesHistory.where((r) => r.startTime.toLocal().year == y).toList();
            final dist = yearRides.fold<double>(0.0, (s, r) => s + r.distanceMeters);
            final dur = yearRides.fold<int>(0, (s, r) => s + r.durationSeconds);
            final double avg = (dist > 0 && dur > 0)
                ? ((dist / 1000.0) / (dur / 3600.0))
                : 0.0;
            final val = _extractPeriodMetricValue(
              distanceMeters: dist,
              durationSeconds: dur,
              avgSpeedKmh: avg,
              rideCount: yearRides.length,
              metric: metric,
            );
            buckets.add(ChartBucket(
              label: '$y',
              date: DateTime(y, 1, 1),
              value: val,
              isHighlighted: y == nowLocal.year,
            ));
          }
        } else {
          for (int i = 0; i < totalMonths; i++) {
            final monthDate = DateTime(startDate.year, startDate.month + i, 1);
            final monthRides = ridesHistory.where((r) {
              final l = r.startTime.toLocal();
              return l.year == monthDate.year && l.month == monthDate.month;
            }).toList();
            final dist = monthRides.fold<double>(0.0, (s, r) => s + r.distanceMeters);
            final dur = monthRides.fold<int>(0, (s, r) => s + r.durationSeconds);
            final double avg = (dist > 0 && dur > 0)
                ? ((dist / 1000.0) / (dur / 3600.0))
                : 0.0;
            final val = _extractPeriodMetricValue(
              distanceMeters: dist,
              durationSeconds: dur,
              avgSpeedKmh: avg,
              rideCount: monthRides.length,
              metric: metric,
            );
            buckets.add(ChartBucket(
              label: '${monthDate.month}/${monthDate.year.toString().substring(2)}',
              date: monthDate,
              value: val,
              isHighlighted: monthDate.year == nowLocal.year && monthDate.month == nowLocal.month,
            ));
          }
        }
        break;
    }

    final periodRides = ridesHistory.where((r) {
      final l = r.startTime.toLocal();
      return (l.isAfter(startDate) || l.isAtSameMomentAs(startDate)) &&
          (l.isBefore(endDate) || l.isAtSameMomentAs(endDate));
    }).toList();

    final totalDist = periodRides.fold<double>(0.0, (s, r) => s + r.distanceMeters);
    final totalDur = periodRides.fold<int>(0, (s, r) => s + r.durationSeconds);
    final double avgSpeed = (totalDist > 0 && totalDur > 0)
        ? ((totalDist / 1000.0) / (totalDur / 3600.0))
        : 0.0;

    return PeriodSummary(
      period: period,
      referenceDate: referenceDate,
      startDate: startDate,
      endDate: endDate,
      totalDistanceMeters: totalDist,
      totalDurationSeconds: totalDur,
      avgSpeedKmh: (avgSpeed.isNaN || avgSpeed.isInfinite) ? 0.0 : avgSpeed,
      rideCount: periodRides.length,
      buckets: buckets,
      records: getPersonalRecords(),
    );
  }

  double _extractMetricValue(RideModel r, AnalyticsMetric metric) {
    switch (metric) {
      case AnalyticsMetric.distance:
        return r.distanceMeters / 1000.0;
      case AnalyticsMetric.duration:
        return r.durationSeconds / 60.0;
      case AnalyticsMetric.averageSpeed:
        return r.avgSpeedKmh;
      case AnalyticsMetric.rideCount:
        return 1.0;
    }
  }

  double _extractPeriodMetricValue({
    required double distanceMeters,
    required int durationSeconds,
    required double avgSpeedKmh,
    required int rideCount,
    required AnalyticsMetric metric,
  }) {
    switch (metric) {
      case AnalyticsMetric.distance:
        return distanceMeters / 1000.0;
      case AnalyticsMetric.duration:
        return durationSeconds / 60.0;
      case AnalyticsMetric.averageSpeed:
        return avgSpeedKmh;
      case AnalyticsMetric.rideCount:
        return rideCount.toDouble();
    }
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

typedef DailyStat = DaySummary;
