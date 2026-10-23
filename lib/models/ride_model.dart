class RideModel {
  final int? id;
  final DateTime startTime;
  final int durationSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double minSpeedKmh;

  RideModel({
    this.id,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.minSpeedKmh,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as int?,
      startTime: DateTime.parse(json['start_time'].toString()),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
      minSpeedKmh: (json['min_speed_kmh'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'start_time': startTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'avg_speed_kmh': avgSpeedKmh,
      'max_speed_kmh': maxSpeedKmh,
      'min_speed_kmh': minSpeedKmh,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }
}
