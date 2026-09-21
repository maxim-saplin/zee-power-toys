import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../default_speedcam_service.dart';
import '../speedcam.dart';

/// Android bridge: YNavi [SpeedCamBroadcaster] → [DefaultSpeedcamService.ingestYnaviEvent].
///
/// EventChannel `zee/speedcam/ynavi` maps:
///   kind: heartbeat | cam | status
///   lat/lon/speedLimit/distance/eventId/source/t_ms/...
///
/// 0071: gated by [setEnrichEnabled] (default OFF). Native drops SPEEDCAM_DATA
/// when disabled; Dart also ignores ingest.
class NativeSpeedcamYnavi {
  NativeSpeedcamYnavi(this._service);

  static const EventChannel _events = EventChannel('zee/speedcam/ynavi');
  static const MethodChannel _ctl = MethodChannel('zee/speedcam/ynavi_ctl');

  final SpeedcamService _service;
  StreamSubscription<dynamic>? _sub;
  int eventCount = 0;
  DateTime? lastBridgeFire;
  bool _enrichEnabled = false;

  bool get isListening => _sub != null;
  bool get enrichEnabled => _enrichEnabled;

  Future<void> setEnrichEnabled(bool enabled) async {
    _enrichEnabled = enabled;
    final svc = _service;
    if (svc is DefaultSpeedcamService) {
      svc.setYnaviEnrichEnabled(enabled);
    }
    try {
      await _ctl.invokeMethod<void>('setEnrichEnabled', <String, Object?>{
        'enabled': enabled,
      });
    } catch (e) {
      debugPrint('NativeSpeedcamYnavi setEnrichEnabled native: $e');
    }
    if (enabled) {
      start();
    } else {
      // Keep EventChannel subscribed so re-enable is instant; native drops.
    }
  }

  void start() {
    if (_sub != null) return;
    final svc = _service;
    if (svc is! DefaultSpeedcamService) {
      debugPrint('NativeSpeedcamYnavi: service is not DefaultSpeedcamService — skip');
      return;
    }
    _sub = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
        if (!_enrichEnabled) return;
        if (raw is! Map) return;
        final map = Map<Object?, Object?>.from(raw);
        eventCount += 1;
        final tMs = (map['t_ms'] as num?)?.toInt();
        if (tMs != null) {
          lastBridgeFire =
              DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: false);
        }
        svc.ingestYnaviEvent(map);
      },
      onError: (Object e, StackTrace st) {
        debugPrint('NativeSpeedcamYnavi stream error: $e');
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  void dispose() => stop();
}
