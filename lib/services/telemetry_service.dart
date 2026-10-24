import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ITelemetryService {
  String? get currentSessionId;
  void startSession(String sessionId);
  void logEvent({
    required String eventType,
    double? latitude,
    double? longitude,
    double? speedMps,
    double? accuracy,
    String? reason,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  });
  Future<void> flush();
  Future<void> cleanOldLogs([int days = 14]);
  void dispose();
}

class TelemetryService implements ITelemetryService {
  final SupabaseClient? _client;
  String? _sessionId;
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  TelemetryService([SupabaseClient? client]) : _client = client {
    _startPeriodicFlush();
  }

  SupabaseClient? get _activeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  void _startPeriodicFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      flush();
    });
  }

  @override
  String? get currentSessionId => _sessionId;

  @override
  void startSession(String sessionId) {
    _sessionId = sessionId;
  }

  @override
  void logEvent({
    required String eventType,
    double? latitude,
    double? longitude,
    double? speedMps,
    double? accuracy,
    String? reason,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    final entry = <String, dynamic>{
      'session_id': _sessionId ?? 'unknown_session',
      'event_type': eventType,
      'timestamp': (timestamp ?? DateTime.now()).toUtc().toIso8601String(),
      'latitude': ?latitude,
      'longitude': ?longitude,
      'speed_mps': ?speedMps,
      'accuracy': ?accuracy,
      'reason': ?reason,
      'metadata': metadata ?? <String, dynamic>{},
    };

    _buffer.add(entry);
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;
    _isFlushing = true;
    final List<Map<String, dynamic>> batch =
        List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();

    try {
      final client = _activeClient;
      if (client != null) {
        await client.from('ride_logs').insert(batch);
      }
    } catch (e) {
      // Transport failures are swallowed to not block the UI
      debugPrint('TelemetryService flush error: $e');
    } finally {
      _isFlushing = false;
    }
  }

  @override
  Future<void> cleanOldLogs([int days = 14]) async {
    try {
      final client = _activeClient;
      if (client == null) return;
      final cutoff = DateTime.now().toUtc().subtract(Duration(days: days));
      await client
          .from('ride_logs')
          .delete()
          .lt('timestamp', cutoff.toIso8601String());
    } catch (e) {
      debugPrint('TelemetryService cleanOldLogs error: $e');
    }
  }

  @override
  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
  }
}
