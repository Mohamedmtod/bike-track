import 'package:bike_track/features/gym/services/audio_session_coordinator.dart';
import 'package:bike_track/features/gym/services/gym_live_activity_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TEST-IOS-01 & TEST-IOS-02 — Native Audio Coordinator & Live Activities Tests', () {
    const audioChannel = MethodChannel('com.probike.gym/audio_session');
    const activityChannel = MethodChannel('com.probike.gym/live_activities');

    final audioCalls = <MethodCall>[];
    final activityCalls = <MethodCall>[];

    setUp(() {
      audioCalls.clear();
      activityCalls.clear();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
        audioCalls.add(call);
        switch (call.method) {
          case 'configureSession':
            return true;
          case 'playRestCompleteAlert':
            return true;
          case 'deactivateSession':
            return true;
          default:
            return null;
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(activityChannel, (call) async {
        activityCalls.add(call);
        switch (call.method) {
          case 'startRestActivity':
            return true;
          case 'updateRestActivity':
            return true;
          case 'endRestActivity':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(activityChannel, null);
    });

    test('AppAudioSessionCoordinator initializes with mixWithOthers and configures successfully', () async {
      final coordinator = AppAudioSessionCoordinator();
      expect(coordinator.isConfigured, isFalse);

      final success = await coordinator.initialize();

      expect(success, isTrue);
      expect(coordinator.isConfigured, isTrue);
      expect(audioCalls.map((c) => c.method), contains('configureSession'));
    });

    test('AppAudioSessionCoordinator handles channel exceptions gracefully without throwing', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(audioChannel, (call) async {
        throw PlatformException(code: 'UNAVAILABLE', message: 'Not supported on this device');
      });

      final coordinator = AppAudioSessionCoordinator();
      final success = await coordinator.initialize();

      expect(success, isFalse);
      expect(coordinator.isConfigured, isFalse);

      // Play alert should also execute fallback safely without crashing
      await expectLater(coordinator.playRestCompleteSound(), completes);
    });

    test('AppAudioSessionCoordinator plays rest complete alert and deactivates cleanly', () async {
      final coordinator = AppAudioSessionCoordinator();
      await coordinator.initialize();

      await coordinator.playRestCompleteSound();
      expect(audioCalls.map((c) => c.method), contains('playRestCompleteAlert'));

      await coordinator.deactivate();
      expect(coordinator.isConfigured, isFalse);
      expect(audioCalls.map((c) => c.method), contains('deactivateSession'));
    });

    test('GymLiveActivityService starts, updates, and ends Live Activity cleanly', () async {
      final service = GymLiveActivityService();
      expect(service.isLiveActivityActive, isFalse);

      final endsAt = DateTime.now().toUtc().add(const Duration(seconds: 90));
      final started = await service.startRestTimerActivity(
        restDurationSeconds: 90,
        endsAtUtc: endsAt,
        exerciseName: 'Barbell Bench Press',
      );

      expect(started, isTrue);
      expect(service.isLiveActivityActive, isTrue);
      expect(activityCalls.first.method, equals('startRestActivity'));
      expect(activityCalls.first.arguments['durationSeconds'], equals(90));
      expect(activityCalls.first.arguments['exerciseName'], equals('Barbell Bench Press'));

      // Update remaining seconds
      await service.updateRestTimerActivity(secondsRemaining: 45);
      expect(activityCalls.map((c) => c.method), contains('updateRestActivity'));

      // End activity
      await service.endRestTimerActivity();
      expect(service.isLiveActivityActive, isFalse);
      expect(activityCalls.map((c) => c.method), contains('endRestActivity'));
    });

    test('GymLiveActivityService handles unsupported OS or platform exception gracefully', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(activityChannel, (call) async {
        throw PlatformException(code: 'UNSUPPORTED_OS', message: 'Requires iOS 16.1+');
      });

      final service = GymLiveActivityService();
      final started = await service.startRestTimerActivity(
        restDurationSeconds: 60,
        endsAtUtc: DateTime.now().toUtc().add(const Duration(seconds: 60)),
      );

      expect(started, isFalse);
      expect(service.isLiveActivityActive, isFalse);

      // Subsequent update or end should not throw
      await expectLater(service.updateRestTimerActivity(secondsRemaining: 30), completes);
      await expectLater(service.endRestTimerActivity(), completes);
    });
  });
}

