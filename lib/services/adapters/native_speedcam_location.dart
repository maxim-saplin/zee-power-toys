import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../speedcam.dart';

/// Android bridge: live car GPS → [SpeedcamService.setHostPose].
///
/// EventChannel `zee/speedcam/location` events are maps:
///   lat        : double
///   lon        : double
///   speedKmh   : double?  (from Location.speed m/s × 3.6)
///   headingDeg : double?  (from Location.bearing)
///   source     : String?  ("ynavi" preferred; "android_gps" LocationManager fallback)
///
/// Live poses use `fromLive: true` so Demo / inject / drive-sim (manual) still
/// win until [SpeedcamService.clearHostPose].
class NativeSpeedcamLocation {
  NativeSpeedcamLocation(this._service);

  static const EventChannel _channel = EventChannel('zee/speedcam/location');

  final SpeedcamService _service;
  StreamSubscription<dynamic>? _sub;
  int _events = 0;
  String? _lastSource;
  SpeedcamHostPose? _lastPose;

  int get eventCount => _events;
  SpeedcamHostPose? get lastPose => _lastPose;
  String? get lastSource => _lastSource;
  bool get isListening => _sub != null;

  /// Subscribe to native location. Safe to call once; no-op if already listening.
  void start() {
    if (_sub != null) return;
    _sub = _channel.receiveBroadcastStream().listen(
      _onEvent,
      onError: (Object e, StackTrace st) {
        debugPrint('NativeSpeedcamLocation stream error: $e');
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() => stop();

  void _onEvent(dynamic raw) {
    if (raw is! Map) return;
    final m = Map<String, Object?>.from(raw);
    final lat = (m['lat'] as num?)?.toDouble();
    final lon = (m['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    final pose = SpeedcamHostPose(
      lat: lat,
      lon: lon,
      speedKmh: (m['speedKmh'] as num?)?.toDouble(),
      headingDeg: (m['headingDeg'] as num?)?.toDouble(),
    );
    _lastPose = pose;
    _lastSource = m['source'] as String? ?? 'android_gps';
    _events++;
    // ignore: discarded_futures
    _service.setHostPose(pose, fromLive: true);
  }

  Map<String, Object?> debugJson() => <String, Object?>{
        'listening': isListening,
        'events': _events,
        'source': _lastSource,
        'lastPose': _lastPose?.toJson(),
      };
}
