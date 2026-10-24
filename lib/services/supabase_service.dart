import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';

class SupabaseService {
  final SupabaseClient? _client;

  SupabaseService([SupabaseClient? client]) : _client = client;

  SupabaseClient get _activeClient => _client ?? Supabase.instance.client;

  /// Insert ride using upsert on `client_id` to prevent duplicates on retry.
  Future<void> insertRide(RideModel ride) async {
    final json = ride.toJson();
    // Remove the local `id` field; Supabase generates it.
    json.remove('id');
    await _activeClient
        .from('rides')
        .upsert(json, onConflict: 'client_id');
  }

  Future<List<RideModel>> getAllRides() async {
    final response = await _activeClient
        .from('rides')
        .select()
        .order('start_time', ascending: false);
    return (response as List<dynamic>)
        .map((e) => RideModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteRide(String clientId, [int? id]) async {
    if (id != null) {
      await _activeClient.from('rides').delete().eq('id', id);
    } else {
      await _activeClient.from('rides').delete().eq('client_id', clientId);
    }
  }
}
