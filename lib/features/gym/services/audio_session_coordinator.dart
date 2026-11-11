import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Coordinates audio session settings on iOS to ensure gym timer chimes
/// do not interrupt user background music (e.g. Spotify, Apple Music).
///
/// Configures AVAudioSession with `.playback`, `.mixWithOthers`, and `.duckOthers`.
class AppAudioSessionCoordinator {
  static const MethodChannel _channel = MethodChannel('com.probike.gym/audio_session');

  static AppAudioSessionCoordinator? _instance;
  static AppAudioSessionCoordinator get instance => _instance ??= AppAudioSessionCoordinator();

  @visibleForTesting
  static set testInstance(AppAudioSessionCoordinator? custom) => _instance = custom;

  bool _isConfigured = false;
  bool get isConfigured => _isConfigured;

  /// Initializes the audio session with mix-with-others and duck-others.
  Future<bool> initialize() async {
    try {
      final success = await _channel.invokeMethod<bool>('configureSession') ?? false;
      _isConfigured = success;
      return success;
    } catch (e) {
      debugPrint('[AudioSession] Falling back to system haptics/audio: $e');
      _isConfigured = false;
      return false;
    }
  }

  /// Plays a rest timer completion chime with ducking and haptic feedback.
  Future<void> playRestCompleteSound() async {
    HapticFeedback.heavyImpact();
    try {
      await _channel.invokeMethod('playRestCompleteAlert');
    } catch (e) {
      // Fallback for non-iOS or test environment
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Restores standard audio session configuration if needed.
  Future<void> deactivate() async {
    try {
      await _channel.invokeMethod('deactivateSession');
      _isConfigured = false;
    } catch (_) {}
  }
}

