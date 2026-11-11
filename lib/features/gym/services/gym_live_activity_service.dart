import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Manages ActivityKit Live Activities & Dynamic Island on iPhone 14 Pro (iOS 16.1+).
///
/// Surfaces rest timer progress directly on Lock Screen and Island.
class GymLiveActivityService {
  static const MethodChannel _channel = MethodChannel('com.probike.gym/live_activities');

  static GymLiveActivityService? _instance;
  static GymLiveActivityService get instance => _instance ??= GymLiveActivityService();

  @visibleForTesting
  static set testInstance(GymLiveActivityService? custom) => _instance = custom;

  bool _isLiveActivityActive = false;
  bool get isLiveActivityActive => _isLiveActivityActive;

  /// Starts or updates a Live Activity for the active rest timer.
  Future<bool> startRestTimerActivity({
    required int restDurationSeconds,
    required DateTime endsAtUtc,
    String? exerciseName,
  }) async {
    try {
      final success = await _channel.invokeMethod<bool>('startRestActivity', {
        'durationSeconds': restDurationSeconds,
        'endsAtUtc': endsAtUtc.toUtc().toIso8601String(),
        'exerciseName': exerciseName ?? 'Rest',
      }) ?? false;
      _isLiveActivityActive = success;
      return success;
    } catch (e) {
      debugPrint('[LiveActivity] Platform channel unavailable or unsupported: $e');
      _isLiveActivityActive = false;
      return false;
    }
  }

  /// Updates remaining seconds in the active Live Activity.
  Future<void> updateRestTimerActivity({required int secondsRemaining}) async {
    if (!_isLiveActivityActive) return;
    try {
      await _channel.invokeMethod('updateRestActivity', {
        'secondsRemaining': secondsRemaining,
      });
    } catch (_) {}
  }

  /// Ends the active Live Activity when rest is finished or skipped.
  Future<void> endRestTimerActivity() async {
    if (!_isLiveActivityActive) return;
    try {
      await _channel.invokeMethod('endRestActivity');
    } catch (_) {}
    _isLiveActivityActive = false;
  }
}

