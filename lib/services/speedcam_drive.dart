import 'dart:async';
import 'dart:math' as math;

import 'speedcam.dart';

/// Lat/lon waypoint for drive sim.
class SpeedcamWaypoint {
  const SpeedcamWaypoint(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// Densify [waypoints] into poses at [speedKmh] with [tickMs] spacing.
List<SpeedcamHostPose> densifyDrivePath({
  required List<SpeedcamWaypoint> waypoints,
  double speedKmh = 50,
  int tickMs = 100,
}) {
  if (waypoints.isEmpty) return const [];
  if (waypoints.length == 1) {
    return [
      SpeedcamHostPose(
        lat: waypoints.first.lat,
        lon: waypoints.first.lon,
        speedKmh: speedKmh,
      ),
    ];
  }
  final speedMps = speedKmh * 1000 / 3600;
  final stepM = math.max(1.0, speedMps * tickMs / 1000);
  final out = <SpeedcamHostPose>[];
  for (var i = 0; i < waypoints.length - 1; i++) {
    final a = waypoints[i];
    final b = waypoints[i + 1];
    final segLen = haversineMetres(a.lat, a.lon, b.lat, b.lon);
    final bearing = initialBearingDegrees(a.lat, a.lon, b.lat, b.lon);
    final steps = math.max(1, (segLen / stepM).ceil());
    for (var s = 0; s < steps; s++) {
      final t = s / steps;
      final dist = segLen * t;
      final p = offsetByMetres(a.lat, a.lon, bearing, dist);
      out.add(SpeedcamHostPose(
        lat: p.$1,
        lon: p.$2,
        speedKmh: speedKmh,
        headingDeg: bearing,
      ));
    }
  }
  final last = waypoints.last;
  out.add(SpeedcamHostPose(
    lat: last.lat,
    lon: last.lon,
    speedKmh: speedKmh,
  ));
  return out;
}

/// Destination after [distanceM] along [bearingDeg] from (lat,lon).
(double, double) offsetByMetres(
  double lat,
  double lon,
  double bearingDeg,
  double distanceM,
) {
  const r = 6371000.0;
  final br = bearingDeg * math.pi / 180;
  final p1 = lat * math.pi / 180;
  final l1 = lon * math.pi / 180;
  final ang = distanceM / r;
  final p2 = math.asin(
    math.sin(p1) * math.cos(ang) +
        math.cos(p1) * math.sin(ang) * math.cos(br),
  );
  final l2 = l1 +
      math.atan2(
        math.sin(br) * math.sin(ang) * math.cos(p1),
        math.cos(ang) - math.sin(p1) * math.sin(p2),
      );
  return (p2 * 180 / math.pi, l2 * 180 / math.pi);
}

/// Build a path that approaches [cams] in order: start 800 m out, through each
/// cam, 800 m past toward the next (or north if last).
List<SpeedcamWaypoint> pathThroughCams(
  List<SpeedcamPoint> cams, {
  double approachM = 800,
}) {
  if (cams.isEmpty) return const [];
  final wps = <SpeedcamWaypoint>[];
  for (var i = 0; i < cams.length; i++) {
    final cam = cams[i];
    final nextBearing = i + 1 < cams.length
        ? initialBearingDegrees(cam.lat, cam.lon, cams[i + 1].lat, cams[i + 1].lon)
        : 0.0;
    final approachBearing = (nextBearing + 180) % 360;
    final start = offsetByMetres(cam.lat, cam.lon, approachBearing, approachM);
    if (wps.isEmpty) {
      wps.add(SpeedcamWaypoint(start.$1, start.$2));
    } else {
      // Bridge from previous exit toward this approach point
      wps.add(SpeedcamWaypoint(start.$1, start.$2));
    }
    wps.add(SpeedcamWaypoint(cam.lat, cam.lon));
    final exit = offsetByMetres(cam.lat, cam.lon, nextBearing, approachM);
    wps.add(SpeedcamWaypoint(exit.$1, exit.$2));
  }
  return wps;
}

/// Runs densified poses into [SpeedcamService.setHostPose] on a timer.
class SpeedcamDriveSim {
  SpeedcamDriveSim(this._service);

  final SpeedcamService _service;
  Timer? _timer;
  List<SpeedcamHostPose> _poses = const [];
  int _index = 0;
  bool _running = false;

  bool get isRunning => _running;
  int get poseIndex => _index;
  int get poseCount => _poses.length;

  Map<String, Object?> statusJson() => <String, Object?>{
        'running': _running,
        'index': _index,
        'count': _poses.length,
        'progress': _poses.isEmpty ? 0.0 : _index / _poses.length,
      };

  /// Start drive. Cancels any in-flight sim.
  Future<Map<String, Object?>> start({
    required List<SpeedcamWaypoint> waypoints,
    double speedKmh = 50,
    int tickMs = 100,
  }) async {
    stop();
    _poses = densifyDrivePath(
      waypoints: waypoints,
      speedKmh: speedKmh,
      tickMs: tickMs,
    );
    _index = 0;
    if (_poses.isEmpty) {
      return <String, Object?>{'ok': false, 'error': 'empty path'};
    }
    _running = true;
    // Emit first pose immediately so FL/QA see motion start.
    await _service.setHostPose(_poses[_index]);
    _index++;
    _timer = Timer.periodic(Duration(milliseconds: tickMs), (_) {
      if (_index >= _poses.length) {
        stop();
        return;
      }
      final pose = _poses[_index++];
      // ignore: discarded_futures
      _service.setHostPose(pose);
    });
    return <String, Object?>{
      'ok': true,
      'poseCount': _poses.length,
      'tickMs': tickMs,
      'speedKmh': speedKmh,
      'waypointCount': waypoints.length,
    };
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
  }

  void dispose() => stop();
}
