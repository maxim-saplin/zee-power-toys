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
class NativeSpeedcamYnavi {
  NativeSpeedcamYnavi(this._service);

  static const EventChannel _events = EventChannel('zee/speedcam/ynavi');

  final SpeedcamService _service;
  StreamSubscription<dynamic>? _sub;
  int eventCount = 0;
  DateTime? lastBridgeFire;

  bool get isListening => _sub != null;

  void start() {
    if (_sub != null) return;
    final svc = _service;
    if (svc is! DefaultSpeedcamService) {
      debugPrint('NativeSpeedcamYnavi: service is not DefaultSpeedcamService — skip');
      return;
    }
    _sub = _events.receiveBroadcastStream().listen(
      (dynamic raw) {
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
