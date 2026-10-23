import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bike_track/config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;

  group('Supabase Cloud Live Roundtrip Tests', () {
    late SupabaseClient client;

    setUp(() {
      client = SupabaseClient(supabaseUrl, supabaseAnonKey);
    });

    tearDown(() async {
      await client.dispose();
    });

    test('Insert, verify math/metrics, and cleanup test ride record in public.rides',
        () async {
      expect(supabaseUrl, isNotEmpty);
      expect(supabaseAnonKey, isNotEmpty);

      final uniqueDistance = 7788.5;
      final uniqueMaxSpeed = 33.3;
      final uniqueMinSpeed = 9.9;

      final testRecord = {
        'start_time': DateTime.now().toUtc().toIso8601String(),
        'duration_seconds': 1500,
        'distance_meters': uniqueDistance,
        'avg_speed_kmh': 18.7,
        'max_speed_kmh': uniqueMaxSpeed,
        'min_speed_kmh': uniqueMinSpeed,
      };

      // 1. Insert test record into public.rides
      final insertResult =
          await client.from('rides').insert(testRecord).select();

      expect(insertResult, isNotEmpty);
      final insertedRow = insertResult.first;
      final insertedId = insertedRow['id'];
      expect(insertedId, isNotNull);

      try {
        // 2. Fetch record and verify distance, max speed, and min speed
        final fetched = await client
            .from('rides')
            .select()
            .eq('id', insertedId)
            .single();

        expect((fetched['distance_meters'] as num).toDouble(), uniqueDistance);
        expect((fetched['max_speed_kmh'] as num).toDouble(), uniqueMaxSpeed);
        expect((fetched['min_speed_kmh'] as num).toDouble(), uniqueMinSpeed);
        expect((fetched['duration_seconds'] as num).toInt(), 1500);
      } finally {
        // 3. Delete the test ride record immediately so table stays 100% clean
        await client.from('rides').delete().eq('id', insertedId);

        final verifyDeleted =
            await client.from('rides').select().eq('id', insertedId);
        expect(verifyDeleted, isEmpty);
      }
    });
  });
}
