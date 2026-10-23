import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bike_track/services/ride_controller.dart';

Position createTestPosition(double lat, double lng, double speedMps) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.now(),
    accuracy: 3.0,
    altitude: 15.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 1.0,
    speed: speedMps,
    speedAccuracy: 0.5,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Ride Logic & NFC Idempotency Tests', () {
    test('NFC Idempotency: Duplicate startRide calls do not restart active ride',
        () async {
      final controller = RideController(autoFetchHistory: false);

      expect(controller.isRiding, false);

      // Call startRide 5 times consecutively (e.g. repeated NFC taps)
      await controller.startRide();
      final initialStartTime = controller.startTime;
      expect(controller.isRiding, true);
      expect(initialStartTime, isNotNull);

      await controller.startRide();
      await controller.startRide();
      await controller.startRide();
      await controller.startRide();

      expect(controller.isRiding, true);
      expect(controller.startTime, initialStartTime);

      // Call stopRide 3 times consecutively
      await controller.stopRide();
      expect(controller.isRiding, false);

      await controller.stopRide();
      await controller.stopRide();
      expect(controller.isRiding, false);

      controller.dispose();
    });

    test('Reminder Interval Control (+5 / -5 mins) with persistence & clamping',
        () async {
      final controller = RideController(autoFetchHistory: false);

      // Default is 30 mins
      expect(controller.reminderMinutes, 30);

      // +5 mins -> 35
      await controller.changeReminderMinutes(5);
      expect(controller.reminderMinutes, 35);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('reminderMinutes'), 35);

      // Decrement 10 times by -5 mins -> clamps at minimum 5 mins (never <= 0)
      for (int i = 0; i < 10; i++) {
        await controller.changeReminderMinutes(-5);
      }
      expect(controller.reminderMinutes, 5);
      expect(prefs.getInt('reminderMinutes'), 5);

      // Cannot exceed 180 mins
      for (int i = 0; i < 40; i++) {
        await controller.changeReminderMinutes(5);
      }
      expect(controller.reminderMinutes, 180);

      controller.dispose();
    });

    test('Simulated Bike GPS Route, speed calculations and jitter filtering',
        () async {
      final controller = RideController(autoFetchHistory: false);
      await controller.startRide();

      // Point 1: Initial position, 0.0 m/s
      controller.processPositionUpdate(
          createTestPosition(30.0444, 31.2357, 0.0));
      expect(controller.routePoints.length, 1);
      expect(controller.distanceMeters, 0.0);
      expect(controller.currentSpeedKmh, 0.0);
      expect(controller.maxSpeedKmh, 0.0);
      expect(controller.minSpeedKmh, 0.0);

      // Point 2: GPS jitter (< 2 meters away)
      controller.processPositionUpdate(
          createTestPosition(30.044405, 31.235705, 0.5));
      expect(controller.routePoints.length, 1,
          reason: 'Jitter < 2m should not add new point');
      expect(controller.distanceMeters, 0.0);

      // Point 3: Movement ~111m North at 5.0 m/s (18.0 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0454, 31.2357, 5.0));
      expect(controller.routePoints.length, 2);
      expect(controller.distanceMeters, greaterThan(100.0));
      expect(controller.currentSpeedKmh, 18.0);
      expect(controller.maxSpeedKmh, 18.0);
      expect(controller.minSpeedKmh, 18.0);

      // Point 4: Acceleration ~111m North at 8.0 m/s (28.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0464, 31.2357, 8.0));
      expect(controller.routePoints.length, 3);
      expect(controller.currentSpeedKmh, 28.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 18.0);

      // Point 5: Deceleration ~111m North at 3.0 m/s (10.8 km/h)
      controller.processPositionUpdate(
          createTestPosition(30.0474, 31.2357, 3.0));
      expect(controller.routePoints.length, 4);
      expect(controller.currentSpeedKmh, 10.8);
      expect(controller.maxSpeedKmh, 28.8);
      expect(controller.minSpeedKmh, 10.8);

      controller.dispose();
    });

    test('Periodic Notification Trigger counts accurately on timer intervals',
        () async {
      final controller = RideController(
        autoFetchHistory: false,
        autoLoadPreferences: false,
      );
      await controller.startRide();

      // Set reminder to 20 mins
      await controller.changeReminderMinutes(-10); // 30 - 10 = 20 mins
      expect(controller.reminderMinutes, 20);
      expect(controller.reminderNotificationTriggerCount, 0);

      // Fast forward 1199 seconds (just before 20 mins)
      controller.tickTimerForTest(1199);
      expect(controller.reminderNotificationTriggerCount, 0);

      // Tick 1 more second -> 1200 seconds (exactly 20 mins)
      controller.tickTimerForTest(1);
      expect(controller.reminderNotificationTriggerCount, 1);

      // Fast forward another 20 mins (1200 seconds) -> 2400 seconds
      controller.tickTimerForTest(1200);
      expect(controller.reminderNotificationTriggerCount, 2);

      controller.dispose();
    });
  });
}
