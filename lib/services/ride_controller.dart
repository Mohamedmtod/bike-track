import 'dart:async';
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

  int reminderMinutes = 30;
  int reminderNotificationTriggerCount = 0;
  static const String _prefReminderKey = 'reminderMinutes';

  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;

  List<RideModel> ridesHistory = [];
  bool isLoadingHistory = false;

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
      _initPreferences();
    }
    if (autoFetchHistory) {
      fetchHistory();
    }
  }

  ITelemetryService get telemetryService => _telemetryService;

  Future<void> _initPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      reminderMinutes = prefs.getInt(_prefReminderKey) ?? 30;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> changeReminderMinutes(int delta) async {
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

  Future<void> fetchHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      ridesHistory = await _supabaseService.getAllRides();
    } catch (e) {
      logTelemetryError('fetch_history_error', {'error': e.toString()});
    } finally {
      isLoadingHistory = false;
      notifyListeners();
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

    // Cancel periodic reminder
    try {
      await _notificationService.cancel(3);
    } catch (_) {}

    final avgSpeedKmh = durationSeconds > 0
        ? (distanceMeters / 1000.0) / (durationSeconds / 3600.0)
        : 0.0;

    // Log RIDE_STOP event with exact metadata
    _telemetryService.logEvent(
      eventType: 'RIDE_STOP',
      metadata: {
        'duration_seconds': durationSeconds,
        'distance_meters': distanceMeters,
        'avg_speed_kmh': avgSpeedKmh,
        'max_speed_kmh': maxSpeedKmh,
        'min_speed_kmh': minSpeedKmh,
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
      startTime: startTime ?? DateTime.now(),
      durationSeconds: durationSeconds,
      distanceMeters: distanceMeters,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      minSpeedKmh: minSpeedKmh,
    );

    try {
      await _supabaseService.insertRide(ride);
    } catch (e) {
      logTelemetryError('save_ride_error', {'error': e.toString()});
    }

    try {
      await _notificationService.showNotification(
        2,
        '🏁 انتهت الرحلة!',
        'عاش يا نجم! مشيت ${(distanceMeters / 1000).toStringAsFixed(2)} كم في ${(durationSeconds / 60).floor()} دقيقة',
      );
    } catch (_) {}

    await fetchHistory();
    notifyListeners();
  }

  // Statistics helpers for Dashboard
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
