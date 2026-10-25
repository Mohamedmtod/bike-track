import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bike_track/config.dart';
import 'package:bike_track/models/ride_model.dart';
import 'package:bike_track/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Supabase Cloud Live Roundtrip Tests', () {
    SupabaseClient? client;
    final shouldRun =
        Platform.environment['RUN_SUPABASE_LIVE_TEST'] == 'true';

    setUp(() {
      if (shouldRun) {
        client = SupabaseClient(supabaseUrl, supabaseAnonKey);
      }
    });

    tearDown(() async {
      if (client != null) {
        await client!.dispose();
      }
    });

    test('Insert, verify math/metrics, and cleanup test ride record in public.rides',
        () async {
      expect(supabaseUrl, isNotEmpty);
      expect(supabaseAnonKey, isNotEmpty);

      final supabase = client;
      if (!shouldRun || supabase == null) {
        // Skipped to prevent writing to production database during normal CI/local test runs
        return;
      }

      final uniqueDistance = 7788.5;
      final uniqueMaxSpeed = 33.3;
      final uniqueMinSpeed = 9.9;
      final testClientId = 'live_test_${DateTime.now().millisecondsSinceEpoch}';

      final routePoints = [
        const [30.0444, 31.2357],
        const [30.0450, 31.2360],
      ];
      final testRide = RideModel(
        clientId: testClientId,
        startTime: DateTime.now().toUtc(),
        durationSeconds: 1500,
        distanceMeters: uniqueDistance,
        avgSpeedKmh: 18.7,
        maxSpeedKmh: uniqueMaxSpeed,
        minSpeedKmh: uniqueMinSpeed,
        routePoints: routePoints
            .map((point) => LatLng(point[0], point[1]))
            .toList(),
      );
      final service = SupabaseService(supabase);

      // Exercise the production upsert path twice for idempotency.
      await service.insertRide(testRide);
      final insertedRow = await supabase
          .from('rides')
          .select()
          .eq('client_id', testClientId)
          .single();
      final insertedId = insertedRow['id'] as int;
      expect(insertedRow['is_manual'], false);

      await service.insertRide(testRide);
      final repeatedRow = await supabase
          .from('rides')
          .select()
          .eq('client_id', testClientId)
          .single();
      expect(repeatedRow['id'], insertedId);

      try {
        // Verify the actual cloud representation after the production service call.
        final fetched = await supabase
            .from('rides')
            .select()
            .eq('id', insertedId)
            .single();

        expect((fetched['distance_meters'] as num).toDouble(), uniqueDistance);
        expect((fetched['max_speed_kmh'] as num).toDouble(), uniqueMaxSpeed);
        expect((fetched['min_speed_kmh'] as num).toDouble(), uniqueMinSpeed);
        expect((fetched['duration_seconds'] as num).toInt(), 1500);
        expect(fetched['client_id'], testClientId);
        expect(fetched['is_manual'], false);
        expect(fetched['route_points'], routePoints);
      } finally {
        await service.deleteRide(testClientId, insertedId);

        final verifyDeleted =
            await supabase.from('rides').select().eq('id', insertedId);
        expect(verifyDeleted, isEmpty);
      }
    });

    test('Insert, verify fields, and cleanup test log record in public.ride_logs',
        () async {
      expect(supabaseUrl, isNotEmpty);
      expect(supabaseAnonKey, isNotEmpty);

      final supabase = client;
      if (!shouldRun || supabase == null) {
        return;
      }

      final uniqueSessionId =
          'test_session_${DateTime.now().millisecondsSinceEpoch}';
      final testLog = {
        'session_id': uniqueSessionId,
        'event_type': 'GPS_ACCEPTED',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'latitude': 30.0444,
        'longitude': 31.2357,
        'speed_mps': 5.0,
        'accuracy': 3.5,
        'reason': null,
        'metadata': {'test_tag': 'anti_drift_verification', 'step_meters': 12.3},
      };

      // 1. Insert test record into public.ride_logs
      final insertResult =
          await supabase.from('ride_logs').insert(testLog).select();

      expect(insertResult, isNotEmpty);
      final insertedRow = insertResult.first;
      final insertedId = insertedRow['id'];
      expect(insertedId, isNotNull);

      try {
        // 2. Fetch record and verify fields
        final fetched = await supabase
            .from('ride_logs')
            .select()
            .eq('id', insertedId)
            .single();

        expect(fetched['session_id'], uniqueSessionId);
        expect(fetched['event_type'], 'GPS_ACCEPTED');
        expect((fetched['latitude'] as num).toDouble(), 30.0444);
        expect((fetched['longitude'] as num).toDouble(), 31.2357);
        expect((fetched['speed_mps'] as num).toDouble(), 5.0);
        expect((fetched['accuracy'] as num).toDouble(), 3.5);
        expect(fetched['metadata']['test_tag'], 'anti_drift_verification');
      } finally {
        // 3. Delete the test log record immediately so table stays 100% clean
        await supabase.from('ride_logs').delete().eq('id', insertedId);

        final verifyDeleted =
            await supabase.from('ride_logs').select().eq('id', insertedId);
        expect(verifyDeleted, isEmpty);
      }
    });
  });
}
