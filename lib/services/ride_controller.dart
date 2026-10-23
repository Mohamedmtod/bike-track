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

class RideController extends ChangeNotifier {
  final SupabaseService _supabaseService;
  final NotificationService _notificationService;

  bool isRiding = false;
  DateTime? startTime;
  int durationSeconds = 0;
  double distanceMeters = 0.0;
  double currentSpeedKmh = 0.0;
  double maxSpeedKmh = 0.0;
  double minSpeedKmh = 0.0;
  List<LatLng> routePoints = [];

  Position? currentPosition;

  int reminderMinutes = 30;
  int reminderNotificationTriggerCount = 0;
  static const String _prefReminderKey = 'reminderMinutes';

  Timer? _timer;
  StreamSubscription<Position>? _positionStreamSubscription;

  List<RideModel> ridesHistory = [];
  bool isLoadingHistory = false;

  RideController({
    SupabaseService? supabaseService,
    NotificationService? notificationService,
    bool autoFetchHistory = true,
    bool autoLoadPreferences = true,
  })  : _supabaseService = supabaseService ?? SupabaseService(),
        _notificationService = notificationService ?? NotificationService() {
    if (autoLoadPreferences) {
      _initPreferences();
    }
    if (autoFetchHistory) {
      fetchHistory();
    }
  }

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
    notifyListeners();
  }

  Future<void> fetchHistory() async {
    isLoadingHistory = true;
    notifyListeners();
    try {
      ridesHistory = await _supabaseService.getAllRides();
    } catch (_) {
      // Gracefully handle network issues
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> startRide() async {
    if (isRiding) return;

    final isTestEnvironment =
        !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

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
          if (permission == LocationPermission.denied) {
            return;
          }
        }
        if (permission == LocationPermission.deniedForever) {
          return;
        }
      } catch (_) {
        // Allow seamless execution in headless test environments
      }
    }

    isRiding = true;
    startTime = DateTime.now();
    durationSeconds = 0;
    distanceMeters = 0.0;
    currentSpeedKmh = 0.0;
    maxSpeedKmh = 0.0;
    minSpeedKmh = 0.0;
    routePoints = [];

    // Notification #1
    try {
      await _notificationService.showNotification(
        1,
        '🚴 بدأت الرحلة!',
        'العداد شغال دلوقتي.. طريق السلامة يا بطل',
      );
    } catch (_) {}

    // 1-second periodic timer
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      durationSeconds++;

      // Periodic reminder
      if (durationSeconds > 0 &&
          durationSeconds % (reminderMinutes * 60) == 0) {
        reminderNotificationTriggerCount++;
        try {
          _notificationService.showNotification(
            3,
            '🤔 لسه راكب العجلة؟',
            'عدى $reminderMinutes دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟',
          );
        } catch (_) {}
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
      ).listen(processPositionUpdate);
    } catch (_) {
      // In headless test environments without hardware GPS stream
    }

    notifyListeners();
  }

  void processPositionUpdate(Position pos) {
    currentPosition = pos;
    currentSpeedKmh = (pos.speed > 0 ? pos.speed : 0.0) * 3.6;

    if (currentSpeedKmh > maxSpeedKmh) {
      maxSpeedKmh = currentSpeedKmh;
    }
    if (currentSpeedKmh > 2.0 &&
        (minSpeedKmh == 0.0 || currentSpeedKmh < minSpeedKmh)) {
      minSpeedKmh = currentSpeedKmh;
    }

    final newPoint = LatLng(pos.latitude, pos.longitude);
    if (routePoints.isEmpty) {
      routePoints.add(newPoint);
    } else {
      final last = routePoints.last;
      final stepMeters = Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        pos.latitude,
        pos.longitude,
      );
      if (stepMeters > 2.0) {
        distanceMeters += stepMeters;
        routePoints.add(newPoint);
      }
    }
    notifyListeners();
  }

  void tickTimerForTest([int seconds = 1]) {
    for (int i = 0; i < seconds; i++) {
      durationSeconds++;
      if (durationSeconds > 0 &&
          durationSeconds % (reminderMinutes * 60) == 0) {
        reminderNotificationTriggerCount++;
        try {
          _notificationService.showNotification(
            3,
            '🤔 لسه راكب العجلة؟',
            'عدى $reminderMinutes دقيقة على الرايد.. لسه مكمل ولا نزلت ونسيت توقف؟',
          );
        } catch (_) {}
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

    final avgSpeedKmh = durationSeconds > 0
        ? (distanceMeters / 1000.0) / (durationSeconds / 3600.0)
        : 0.0;

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
    } catch (_) {
      // Fail silently to never block UI
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
    super.dispose();
  }
}

class DailyStat {
  final DateTime date;
  final double distanceKm;
  DailyStat({required this.date, required this.distanceKm});
}
