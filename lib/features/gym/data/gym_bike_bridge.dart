import 'dart:convert';
import 'package:bike_track/models/ride_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Read-only bridge that accesses cycling ride history to integrate
/// cycling load into the Gym 3D Muscle Fatigue Heatmap.
///
/// Strict Architectural Invariant:
/// - Never writes to or alters cycling storage or telemetry.
/// - Operates purely in read-only mode.
class GymBikeBridge {
  static const String _prefCachedRidesHistoryKey = 'cached_rides_history';

  final SharedPreferences? prefs;
  final List<RideModel>? overrideRides;

  GymBikeBridge({
    this.prefs,
    this.overrideRides,
  });

  /// Loads completed rides within the specified time window (default: 48 hours).
  Future<List<RideModel>> getRecentRides({Duration window = const Duration(hours: 48)}) async {
    if (overrideRides != null) {
      final cutoff = DateTime.now().subtract(window);
      return overrideRides!.where((r) => r.startTime.isAfter(cutoff)).toList();
    }

    try {
      final p = prefs ?? await SharedPreferences.getInstance();
      final raw = p.getString(_prefCachedRidesHistoryKey);
      if (raw == null || raw.isEmpty) return [];

      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final cutoff = DateTime.now().subtract(window);

      final rides = <RideModel>[];
      for (final item in decoded) {
        final ride = RideModel.fromLocalJson(Map<String, dynamic>.from(item as Map));
        if (ride.startTime.isAfter(cutoff)) {
          rides.add(ride);
        }
      }
      return rides;
    } catch (_) {
      return [];
    }
  }

  /// Calculates cycling-induced fatigue for leg muscle groups within the window.
  ///
  /// Muscle impact distribution:
  /// - Quadriceps: 1.0 (Primary downstroke power)
  /// - Calves: 0.8 (Plantar flexion & ankle stabilization)
  /// - Hamstrings: 0.7 (Pedal upstroke & knee flexion)
  /// - Glutes: 0.6 (Hip extension power)
  Future<Map<String, double>> getCyclingMuscleFatigue({
    Duration window = const Duration(hours: 48),
  }) async {
    final recentRides = await getRecentRides(window: window);
    if (recentRides.isEmpty) return {};

    double rawCycleScore = 0.0;
    final now = DateTime.now();

    for (final r in recentRides) {
      final hoursAgo = now.difference(r.startTime.toLocal()).inHours;
      final decay = (1.0 - (hoursAgo / window.inHours)).clamp(0.1, 1.0);
      final rideHours = r.durationSeconds / 3600.0;
      // Formula: 0.25 pts per km + 1.5 pts per hour of cycling, weighted by recency decay
      final rideScore = (r.distanceKm * 0.25 + rideHours * 1.5) * decay;
      rawCycleScore += rideScore;
    }

    return {
      'quads': rawCycleScore * 1.0,
      'calves': rawCycleScore * 0.8,
      'hamstrings': rawCycleScore * 0.7,
      'glutes': rawCycleScore * 0.6,
    };
  }
}
