import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../default_speedcam_service.dart';
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
/// MethodChannel `zee/speedcam/location_ctl` (0050 HARD):
///   hasPermission / requestPermission / ensureGpsStarted / reemitLastKnown
///
/// Live poses use `fromLive: true` so Demo / inject / drive-sim (manual) still
/// win until [SpeedcamService.clearHostPose]. After clear / permission grant,
/// [resumeLiveAfterClear] re-applies the cached pose and asks native to
/// re-emit lastKnown so the host is not stuck null until the next GPS tick.
class NativeSpeedcamLocation {
  NativeSpeedcamLocation(this._service) {
    final svc = _service;
    if (svc is DefaultSpeedcamService) {
      svc.onHostPoseCleared = () {
        unawaited(resumeLiveAfterClear());
      };
    }
  }

  static const EventChannel _events = EventChannel('zee/speedcam/location');
  static const MethodChannel _ctl = MethodChannel('zee/speedcam/location_ctl');

  final SpeedcamService _service;
  StreamSubscription<dynamic>? _sub;
  int _eventsCount = 0;
  String? _lastSource;
  SpeedcamHostPose? _lastPose;

  int get eventCount => _eventsCount;
  SpeedcamHostPose? get lastPose => _lastPose;
  String? get lastSource => _lastSource;
  bool get isListening => _sub != null;

  /// Subscribe to native location. Safe to call once; no-op if already listening.
  void start() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen(
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

  Future<bool> hasPermission() async {
    try {
      final v = await _ctl.invokeMethod<bool>('hasPermission');
      return v ?? false;
    } catch (e) {
      debugPrint('NativeSpeedcamLocation.hasPermission: $e');
      return false;
    }
  }

  /// Show the system location dialog if needed; start GPS + reemit on grant.
  /// Returns whether fine/coarse was granted.
  Future<bool> ensurePermission() async {
    try {
      final already = await hasPermission();
      if (already) {
        await _ctl.invokeMethod<void>('ensureGpsStarted');
        await reemitLastKnown();
        return true;
      }
      final raw = await _ctl.invokeMethod<dynamic>('requestPermission');
      final granted = raw is Map && raw['granted'] == true;
      if (granted) {
        await _ctl.invokeMethod<void>('ensureGpsStarted');
        await reemitLastKnown();
      }
      return granted;
    } catch (e) {
      debugPrint('NativeSpeedcamLocation.ensurePermission: $e');
      return false;
    }
  }

  Future<void> reemitLastKnown() async {
    try {
      await _ctl.invokeMethod<void>('reemitLastKnown');
    } catch (e) {
      debugPrint('NativeSpeedcamLocation.reemitLastKnown: $e');
    }
  }

  /// After [SpeedcamService.clearHostPose]: re-seed host from cache + native.
  Future<void> resumeLiveAfterClear() async {
    final cached = _lastPose;
    if (cached != null) {
      await _service.setHostPose(cached, fromLive: true);
    }
    await reemitLastKnown();
  }

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
    _eventsCount++;
    // ignore: discarded_futures
    _service.setHostPose(pose, fromLive: true);
  }

  Map<String, Object?> debugJson() => <String, Object?>{
        'listening': isListening,
        'events': _eventsCount,
        'source': _lastSource,
        'lastPose': _lastPose?.toJson(),
      };
}
