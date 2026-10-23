import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_model.dart';

class SupabaseService {
  final SupabaseClient? _client;

  SupabaseService([SupabaseClient? client]) : _client = client;

  SupabaseClient get _activeClient => _client ?? Supabase.instance.client;

  Future<void> insertRide(RideModel ride) async {
    await _activeClient.from('rides').insert(ride.toJson());
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
}
