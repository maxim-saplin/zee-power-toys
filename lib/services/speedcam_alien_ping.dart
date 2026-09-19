import 'dart:async';

import 'speedcam_alert.dart';

/// Alien motion-tracker loop: faster + higher pitch as distance closes.
Duration alienPingIntervalForDistanceM(double distanceM) {
  final d = distanceM.clamp(20.0, 500.0);
  // ~120ms at 20 m → ~1200ms at 500 m
  final ms = (90 + (d - 20) / 480 * 1100).round();
  return Duration(milliseconds: ms);
}

/// Playback rate ≈ pitch: ~0.75 far → ~2.1 near (tracker whistle climb).
double alienPingPlaybackRateForDistanceM(double distanceM) {
  final d = distanceM.clamp(20.0, 500.0);
  return 0.75 + (500.0 - d) / 480.0 * 1.35;
}

/// Drives periodic [SpeedcamAlert.playAlienPing] while inside approach
/// with Alien look + sound enabled.
class SpeedcamAlienPingLoop {
  SpeedcamAlienPingLoop({required this.alert});

  final SpeedcamAlert alert;
  Timer? _timer;
  double? _lastDistanceM;
  bool _active = false;

  bool get isActive => _active;

  void update({
    required bool enabled,
    required bool alienLook,
    required bool insideApproach,
    required double? distanceM,
  }) {
    final want = enabled && alienLook && insideApproach && distanceM != null;
    if (!want) {
      stop();
      return;
    }
    _lastDistanceM = distanceM;
    if (_timer == null) {
      _active = true;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    final d = _lastDistanceM ?? 500;
    final interval = alienPingIntervalForDistanceM(d);
    _timer = Timer(interval, () async {
      if (!_active) return;
      await alert.playAlienPing(distanceM: _lastDistanceM);
      if (_active) _schedule();
    });
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => stop();
}
