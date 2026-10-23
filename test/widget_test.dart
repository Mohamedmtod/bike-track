import 'package:flutter_test/flutter_test.dart';
import 'package:bike_track/models/ride_model.dart';

void main() {
  test('RideModel JSON serialization smoke test', () {
    final now = DateTime.now();
    final ride = RideModel(
      id: 1,
      startTime: now,
      durationSeconds: 120,
      distanceMeters: 500.5,
      avgSpeedKmh: 15.0,
      maxSpeedKmh: 20.0,
      minSpeedKmh: 5.0,
    );

    final json = ride.toJson();
    expect(json['duration_seconds'], 120);
    expect(json['distance_meters'], 500.5);

    final fromJson = RideModel.fromJson(json);
    expect(fromJson.id, 1);
    expect(fromJson.durationSeconds, 120);
  });
}
