import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ITelemetryService {
  String? get currentSessionId;
  int get bufferSize => 0;
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
  List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;
  bool _isFlushing = false;

  static const String _prefTelemetryQueueKey = 'telemetry_queue';
  static const int _maxQueueSize = 500;

  @override
  int get bufferSize => _buffer.length;

  TelemetryService([SupabaseClient? client]) : _client = client {
    _loadPersistedQueue();
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

  /// Load persisted telemetry queue from SharedPreferences on startup.
  Future<void> _loadPersistedQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefTelemetryQueueKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        final restored = decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        // Prepend restored items before any new buffer entries
        _buffer = [...restored, ..._buffer];
        // Enforce max queue size
        if (_buffer.length > _maxQueueSize) {
          _buffer = _buffer.sublist(_buffer.length - _maxQueueSize);
        }
      }
    } catch (_) {
      // Ignore deserialization errors
    }
  }

  /// Persist current buffer to SharedPreferences for crash recovery.
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_buffer.isEmpty) {
        await prefs.remove(_prefTelemetryQueueKey);
      } else {
        // Enforce max queue size before persisting
        final toStore = _buffer.length > _maxQueueSize
            ? _buffer.sublist(_buffer.length - _maxQueueSize)
            : _buffer;
        await prefs.setString(_prefTelemetryQueueKey, jsonEncode(toStore));
      }
    } catch (_) {}
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

    // Enforce max queue size
    if (_buffer.length > _maxQueueSize) {
      _buffer = _buffer.sublist(_buffer.length - _maxQueueSize);
    }

    // Persist after adding entry
    _persistQueue();
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;
    _isFlushing = true;
    final List<Map<String, dynamic>> batch =
        List<Map<String, dynamic>>.from(_buffer);

    try {
      final client = _activeClient;
      if (client != null) {
        await client.from('ride_logs').insert(batch);
        // Only clear buffer after successful upload
        _buffer.clear();
        await _persistQueue();
      }
      // If client is null (no network), keep buffer for retry
    } catch (e) {
      // Transport failures: keep the buffer intact for retry
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
    // Persist remaining buffer on dispose
    _persistQueue();
  }
}
