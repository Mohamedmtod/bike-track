import 'package:latlong2/latlong.dart';
import 'package:bike_track/models/ride_model.dart';

enum AnalyticsPeriod {
  day,
  week,
  month,
  year,
  all,
}

enum AnalyticsMetric {
  distance,
  duration,
  averageSpeed,
  rideCount,
}

class DaySummary {
  final DateTime date;
  final List<RideModel> rides;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double avgSpeedKmh;
  final double? maxSpeedKmh;
  final double? minSpeedKmh;
  final int rideCount;
  final bool hasGpsRoutes;
  final List<List<LatLng>> allPolylines;
  final bool includesActiveRide;

  const DaySummary({
    required this.date,
    required this.rides,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.minSpeedKmh,
    required this.rideCount,
    required this.hasGpsRoutes,
    required this.allPolylines,
    this.includesActiveRide = false,
  });

  double get totalDistanceKm => totalDistanceMeters / 1000.0;
  double get distanceKm => totalDistanceKm;
}

class ChartBucket {
  final String label;
  final DateTime date;
  final double value;
  final bool isHighlighted;

  const ChartBucket({
    required this.label,
    required this.date,
    required this.value,
    this.isHighlighted = false,
  });
}

class PersonalRecords {
  final RideModel? longestRide;
  final RideModel? fastestRide;
  final DateTime? mostActiveDayDate;
  final double mostActiveDayDistanceKm;

  const PersonalRecords({
    this.longestRide,
    this.fastestRide,
    this.mostActiveDayDate,
    this.mostActiveDayDistanceKm = 0.0,
  });
}

class PeriodSummary {
  final AnalyticsPeriod period;
  final DateTime referenceDate;
  final DateTime startDate;
  final DateTime endDate;
  final double totalDistanceMeters;
  final int totalDurationSeconds;
  final double avgSpeedKmh;
  final int rideCount;
  final List<ChartBucket> buckets;
  final PersonalRecords records;

  const PeriodSummary({
    required this.period,
    required this.referenceDate,
    required this.startDate,
    required this.endDate,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.avgSpeedKmh,
    required this.rideCount,
    required this.buckets,
    required this.records,
  });

  double get totalDistanceKm => totalDistanceMeters / 1000.0;
}
