/// Ride sync status for offline-first queue management.
enum SyncStatus { pending, synced }

class RideModel {
  final int? id;
  final String clientId;
  final DateTime startTime;
  final int durationSeconds;
  final double distanceMeters;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double minSpeedKmh;
  final bool isManual;
  SyncStatus syncStatus;

  RideModel({
    this.id,
    String? clientId,
    required this.startTime,
    required this.durationSeconds,
    required this.distanceMeters,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.minSpeedKmh,
    this.isManual = false,
    this.syncStatus = SyncStatus.pending,
  }) : clientId = clientId ?? _generateClientId();

  /// Generates a unique client-side ID for deduplication on upsert.
  static String _generateClientId() {
    final now = DateTime.now();
    final hash = Object.hash(
      now.microsecondsSinceEpoch,
      identityHashCode(now),
    );
    return 'ride_${now.millisecondsSinceEpoch}_${hash.toUnsigned(32).toRadixString(36)}';
  }

  factory RideModel.fromJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as int?,
      clientId: json['client_id'] as String? ?? _generateClientId(),
      startTime: DateTime.parse(json['start_time'].toString()),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
      minSpeedKmh: (json['min_speed_kmh'] as num).toDouble(),
      isManual: json['is_manual'] as bool? ?? false,
      syncStatus: SyncStatus.synced,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'client_id': clientId,
      'start_time': startTime.toIso8601String(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'avg_speed_kmh': avgSpeedKmh,
      'max_speed_kmh': maxSpeedKmh,
      'min_speed_kmh': minSpeedKmh,
      'is_manual': isManual,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Serialize for local SharedPreferences storage (includes syncStatus).
  Map<String, dynamic> toLocalJson() {
    return {
      ...toJson(),
      'sync_status': syncStatus == SyncStatus.synced ? 'synced' : 'pending',
    };
  }

  /// Deserialize from local SharedPreferences storage.
  factory RideModel.fromLocalJson(Map<String, dynamic> json) {
    return RideModel(
      id: json['id'] as int?,
      clientId: json['client_id'] as String?,
      startTime: DateTime.parse(json['start_time'].toString()),
      durationSeconds: (json['duration_seconds'] as num).toInt(),
      distanceMeters: (json['distance_meters'] as num).toDouble(),
      avgSpeedKmh: (json['avg_speed_kmh'] as num).toDouble(),
      maxSpeedKmh: (json['max_speed_kmh'] as num).toDouble(),
      minSpeedKmh: (json['min_speed_kmh'] as num).toDouble(),
      isManual: json['is_manual'] as bool? ?? false,
      syncStatus: json['sync_status'] == 'synced'
          ? SyncStatus.synced
          : SyncStatus.pending,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RideModel &&
          runtimeType == other.runtimeType &&
          clientId == other.clientId;

  @override
  int get hashCode => clientId.hashCode;
}
