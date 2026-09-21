import 'dart:math' as math;

/// One OSM / sample speed camera.
class SpeedcamPoint {
  const SpeedcamPoint({
    required this.id,
    required this.lat,
    required this.lon,
    this.maxspeed,
    this.direction,
    this.source,
    this.lastSeenEpochMs,
  });

  final String id;
  final double lat;
  final double lon;
  final int? maxspeed;
  final String? direction;

  /// Pack origin: `overpass` / `ynavi` / `osm+ynavi` / null (legacy OSM).
  final String? source;

  /// 0073: last ingest/renewal epoch ms (YNavi overlay aging). OSM pack cams omit this.
  final int? lastSeenEpochMs;

  bool get isYnaviSourced =>
      source == 'ynavi' ||
      source == 'osm+ynavi' ||
      id.startsWith('ynavi:');

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'lat': lat,
        'lon': lon,
        if (maxspeed != null) 'maxspeed': maxspeed,
        if (direction != null) 'direction': direction,
        if (source != null) 'source': source,
        if (lastSeenEpochMs != null) 'lastSeenEpochMs': lastSeenEpochMs,
      };

  factory SpeedcamPoint.fromJson(Map<String, Object?> json) => SpeedcamPoint(
        id: json['id'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        maxspeed: (json['maxspeed'] as num?)?.toInt(),
        direction: json['direction'] as String?,
        source: json['source'] as String?,
        lastSeenEpochMs: (json['lastSeenEpochMs'] as num?)?.toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is SpeedcamPoint &&
      other.id == id &&
      other.lat == lat &&
      other.lon == lon &&
      other.maxspeed == maxspeed &&
      other.direction == direction &&
      other.source == source &&
      other.lastSeenEpochMs == lastSeenEpochMs;

  @override
  int get hashCode =>
      Object.hash(id, lat, lon, maxspeed, direction, source, lastSeenEpochMs);
}

/// Host vehicle position for proximity (T1 inject / later GPS).
class SpeedcamHostPose {
  const SpeedcamHostPose({
    required this.lat,
    required this.lon,
    this.speedKmh,
    this.headingDeg,
  });

  final double lat;
  final double lon;
  final double? speedKmh;

  /// Optional host heading degrees clockwise from north [0, 360).
  final double? headingDeg;

  Map<String, Object?> toJson() => <String, Object?>{
        'lat': lat,
        'lon': lon,
        if (speedKmh != null) 'speedKmh': speedKmh,
        if (headingDeg != null) 'headingDeg': headingDeg,
      };

  factory SpeedcamHostPose.fromJson(Map<String, Object?> json) =>
      SpeedcamHostPose(
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        speedKmh: (json['speedKmh'] as num?)?.toDouble(),
        headingDeg: (json['headingDeg'] as num?)?.toDouble(),
      );
}

/// Nearest cam with distance + bearing; [insideApproach] when ≤ radius.
class SpeedcamDanger {
  const SpeedcamDanger({
    required this.cam,
    required this.distanceM,
    required this.bearingDeg,
    required this.insideApproach,
  });

  final SpeedcamPoint cam;
  final double distanceM;

  /// Initial bearing host → cam, degrees clockwise from north [0, 360).
  final double bearingDeg;
  final bool insideApproach;

  Map<String, Object?> toJson() => <String, Object?>{
        'cam': cam.toJson(),
        'distanceM': distanceM,
        'bearingDeg': bearingDeg,
        'insideApproach': insideApproach,
      };

  factory SpeedcamDanger.fromJson(Map<String, Object?> json) => SpeedcamDanger(
        cam: SpeedcamPoint.fromJson(
          Map<String, Object?>.from(json['cam']! as Map),
        ),
        distanceM: (json['distanceM'] as num).toDouble(),
        bearingDeg: (json['bearingDeg'] as num).toDouble(),
        insideApproach: json['insideApproach'] as bool? ?? false,
      );
}

/// Snapshot for dumpState / readViewModel.
class SpeedcamSnapshot {
  const SpeedcamSnapshot({
    this.enabled = false,
    this.cams = const <SpeedcamPoint>[],
    this.host,
    this.danger,
    this.approachRadiusM = 500,
    this.camSource = 'none',
  });

  final bool enabled;
  final List<SpeedcamPoint> cams;
  final SpeedcamHostPose? host;
  final SpeedcamDanger? danger;
  final double approachRadiusM;

  /// `pack` | `fallback` | `none`
  final String camSource;

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'camCount': cams.length,
        'camSource': camSource,
        // Cap dump size — full list is huge for BY (~1k); keep first 20 for FL.
        'cams': cams.take(20).map((c) => c.toJson()).toList(),
        'host': host?.toJson(),
        'danger': danger?.toJson(),
        'approachRadiusM': approachRadiusM,
      };

  /// Compact envelope for DHU→HUD relay.
  ///
  /// Includes host + danger plus **all cams within [radarRadiusM]** of the host
  /// (capped) so Alien HUD can paint route-bright + other-in-range dim (0042).
  Map<String, Object?> toRelayJson({double radarRadiusM = 2000}) {
    final relayCams = <SpeedcamPoint>[];
    final hostPose = host;
    if (hostPose != null && cams.isNotEmpty) {
      final ranked = <(SpeedcamPoint, double)>[
        for (final cam in cams)
          (cam, haversineMetres(hostPose.lat, hostPose.lon, cam.lat, cam.lon)),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      for (final pair in ranked) {
        if (pair.$2 > radarRadiusM) break;
        relayCams.add(pair.$1);
        if (relayCams.length >= 48) break;
      }
    }
    // Ensure on-route danger cam is present even if outside sort quirks.
    if (danger != null && !relayCams.any((c) => c.id == danger!.cam.id)) {
      relayCams.insert(0, danger!.cam);
    }
    return <String, Object?>{
      'enabled': enabled,
      'camSource': camSource,
      'approachRadiusM': approachRadiusM,
      'host': host?.toJson(),
      'danger': danger?.toJson(),
      'cams': relayCams.map((c) => c.toJson()).toList(),
    };
  }

  factory SpeedcamSnapshot.fromJson(Map<String, Object?> json) {
    final camsRaw = json['cams'] as List<dynamic>? ?? const [];
    return SpeedcamSnapshot(
      enabled: json['enabled'] as bool? ?? false,
      cams: camsRaw
          .map((e) => SpeedcamPoint.fromJson(Map<String, Object?>.from(e as Map)))
          .toList(),
      host: json['host'] is Map
          ? SpeedcamHostPose.fromJson(Map<String, Object?>.from(json['host']! as Map))
          : null,
      danger: json['danger'] is Map
          ? SpeedcamDanger.fromJson(Map<String, Object?>.from(json['danger']! as Map))
          : null,
      approachRadiusM: (json['approachRadiusM'] as num?)?.toDouble() ?? 500,
      camSource: json['camSource'] as String? ?? 'none',
    );
  }
}

/// Great-circle distance in metres (WGS84 sphere).
double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371000.0;
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dp = (lat2 - lat1) * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dp / 2) * math.sin(dp / 2) +
      math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
  return 2 * r * math.asin(math.sqrt(a));
}

/// Initial bearing from (lat1,lon1) → (lat2,lon2), degrees [0, 360).
double initialBearingDegrees(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final p1 = lat1 * math.pi / 180;
  final p2 = lat2 * math.pi / 180;
  final dl = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) -
      math.sin(p1) * math.cos(p2) * math.cos(dl);
  final deg = math.atan2(y, x) * 180 / math.pi;
  return (deg + 360) % 360;
}



/// Signed relative bearing: absolute cam bearing minus host heading, degrees
/// in (-180, 180]. Unknown heading → treat absolute as already relative
/// (north-up / demo).
double relativeBearingDegrees(double absoluteBearingDeg, double? headingDeg) {
  final raw = headingDeg == null
      ? absoluteBearingDeg
      : absoluteBearingDeg - headingDeg;
  var b = raw % 360;
  if (b > 180) b -= 360;
  if (b < -180) b += 360;
  return b;
}

/// Smallest absolute angle between two bearings [0, 180].
double smallestAngleDeg(double a, double b) {
  var d = (a - b).abs() % 360;
  if (d > 180) d = 360 - d;
  return d;
}

/// Parse OSM `direction` / compass text to degrees clockwise from north.
/// Returns null when unknown → callers **fail-open** (still alert).
double? parseCamFacingDegrees(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toUpperCase();
  if (s.isEmpty) return null;
  final asNum = double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  if (asNum != null && raw.trim().contains(RegExp(r'[0-9]'))) {
    return (asNum % 360 + 360) % 360;
  }
  const compass = <String, double>{
    'N': 0,
    'NNE': 22.5,
    'NE': 45,
    'ENE': 67.5,
    'E': 90,
    'ESE': 112.5,
    'SE': 135,
    'SSE': 157.5,
    'S': 180,
    'SSW': 202.5,
    'SW': 225,
    'WSW': 247.5,
    'W': 270,
    'WNW': 292.5,
    'NW': 315,
    'NNW': 337.5,
  };
  if (compass.containsKey(s)) return compass[s];
  // Multi-value OSM sometimes uses "180;0" — take first known token.
  for (final part in s.split(RegExp(r'[;,/\\s]+'))) {
    if (compass.containsKey(part)) return compass[part];
    final n = double.tryParse(part);
    if (n != null) return (n % 360 + 360) % 360;
  }
  return null;
}

/// Independent HUD paint / alert-sound presence gate (0060).
///
/// **Any scan set** = front hemisphere ([kScanHemisphereHalfAngleDeg] ±90°) ∩
/// approach radius (no facing mute).
/// **Dangerous** = 90° front cone ([kDangerousFrontConeHalfAngleDeg] ±45°) ∩
/// approach radius ∩ facing our traffic when heading is known. If heading is
/// unknown → do **not** apply facing; cone-only (cone also fail-opens without
/// heading). [off]: channel silent / hidden.
enum SpeedcamPresenceMode {
  any,
  dangerous,
  off,
}

/// Front-hemisphere half-angle for [SpeedcamPresenceMode.any] / scan set (°).
const double kScanHemisphereHalfAngleDeg = 90;

/// Dangerous front-cone half-angle: heading ±45° → 90° total cone (°).
const double kDangerousFrontConeHalfAngleDeg = 45;

/// Whether [cam] should alert for [host] travel direction (facing gate).
///
/// Camera facing into our traffic (≈ opposite our heading) → relevant.
/// Camera facing same way we travel (other line) → muted.
/// **Unknown heading → do not apply facing** (caller uses cone-only).
/// Unknown facing with known heading → **fail-open** (relevant).
bool isCamRelevantForHost(SpeedcamHostPose host, SpeedcamPoint cam) {
  final heading = host.headingDeg;
  if (heading == null) return true;
  final facing = parseCamFacingDegrees(cam.direction);
  if (facing == null) return true;
  final intoOurTraffic = (heading + 180) % 360;
  return smallestAngleDeg(facing, intoOurTraffic) <= 90;
}

/// Whether the cam lies within [halfAngleDeg] of host travel heading.
///
/// Default [kScanHemisphereHalfAngleDeg] (±90°) = front hemisphere for Any.
/// Dangerous uses [kDangerousFrontConeHalfAngleDeg] (±45°).
/// Unknown heading → fail-open (treat as in cone / ahead).
bool isCamAheadOfTravel(
  SpeedcamHostPose host,
  double bearingToCamDeg, {
  double halfAngleDeg = kScanHemisphereHalfAngleDeg,
}) {
  final heading = host.headingDeg;
  if (heading == null) return true;
  return smallestAngleDeg(bearingToCamDeg, heading) <= halfAngleDeg;
}

/// Whether [cam] is in the 0060 scan set: ahead of travel and within [radiusM].
bool isCamInScanSet({
  required SpeedcamHostPose host,
  required SpeedcamPoint cam,
  required double radiusM,
  double? distanceM,
  double? bearingDeg,
}) {
  final d = distanceM ??
      haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
  if (d > radiusM) return false;
  final bearing = bearingDeg ??
      initialBearingDegrees(host.lat, host.lon, cam.lat, cam.lon);
  return isCamAheadOfTravel(host, bearing);
}

/// True when [mode] should treat [cam] as an active presence contact.
bool camPassesPresenceMode({
  required SpeedcamPresenceMode mode,
  required SpeedcamHostPose host,
  required SpeedcamPoint cam,
  required double approachRadiusM,
  double? distanceM,
  double? bearingDeg,
}) {
  if (mode == SpeedcamPresenceMode.off) return false;
  final d = distanceM ??
      haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
  if (d > approachRadiusM) return false;
  final bearing = bearingDeg ??
      initialBearingDegrees(host.lat, host.lon, cam.lat, cam.lon);
  final halfAngle = mode == SpeedcamPresenceMode.dangerous
      ? kDangerousFrontConeHalfAngleDeg
      : kScanHemisphereHalfAngleDeg;
  if (!isCamAheadOfTravel(host, bearing, halfAngleDeg: halfAngle)) {
    return false;
  }
  if (mode == SpeedcamPresenceMode.dangerous) {
    // Facing only when heading known; unknown heading → cone-only.
    return isCamRelevantForHost(host, cam);
  }
  // any
  return true;
}

/// Nearest cam for [mode] within the front-hemisphere scan set.
///
/// Returns null when [mode] is [SpeedcamPresenceMode.off] or no candidate
/// matches. [insideApproach] is always true for returned hits (scan ∩ radius).
SpeedcamDanger? nearestForPresenceMode({
  required SpeedcamPresenceMode mode,
  required SpeedcamHostPose host,
  required List<SpeedcamPoint> cams,
  double approachRadiusM = 500,
  Set<String> skipIds = const <String>{},
}) {
  if (mode == SpeedcamPresenceMode.off) return null;
  final requireFacing = mode == SpeedcamPresenceMode.dangerous;
  final aheadHalf = mode == SpeedcamPresenceMode.dangerous
      ? kDangerousFrontConeHalfAngleDeg
      : kScanHemisphereHalfAngleDeg;
  return nearestDanger(
    host: host,
    cams: cams,
    approachRadiusM: approachRadiusM,
    skipIds: skipIds,
    requireFacing: requireFacing,
    requireAhead: true,
    aheadHalfAngleDeg: aheadHalf,
    onlyInsideApproach: true,
  );
}

/// Nearest relevant cam.
///
/// When [requireFacing] is true (default), applies [isCamRelevantForHost]
/// (no-op / fail-open when heading unknown).
/// When [requireAhead] is true (default), applies [isCamAheadOfTravel] with
/// [aheadHalfAngleDeg] (default Dangerous ±45° cone; pass
/// [kScanHemisphereHalfAngleDeg] for Any).
/// When [onlyInsideApproach] is true, skips cams outside [approachRadiusM].
SpeedcamDanger? nearestDanger({
  required SpeedcamHostPose host,
  required List<SpeedcamPoint> cams,
  double approachRadiusM = 500,
  Set<String> skipIds = const <String>{},
  bool requireFacing = true,
  bool requireAhead = true,
  double aheadHalfAngleDeg = kDangerousFrontConeHalfAngleDeg,
  bool onlyInsideApproach = false,
}) {
  SpeedcamDanger? best;
  for (final cam in cams) {
    if (skipIds.contains(cam.id)) continue;
    if (requireFacing && !isCamRelevantForHost(host, cam)) continue;
    final d = haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
    if (onlyInsideApproach && d > approachRadiusM) continue;
    final bearing = initialBearingDegrees(host.lat, host.lon, cam.lat, cam.lon);
    if (requireAhead &&
        !isCamAheadOfTravel(
          host,
          bearing,
          halfAngleDeg: aheadHalfAngleDeg,
        )) {
      continue;
    }
    if (best == null || d < best.distanceM) {
      best = SpeedcamDanger(
        cam: cam,
        distanceM: d,
        bearingDeg: bearing,
        insideApproach: d <= approachRadiusM,
      );
    }
  }
  return best;
}

/// Resolve which danger drives sound/HUD for [mode].
///
/// Prefer [serviceDanger] for [SpeedcamPresenceMode.dangerous] so pass-clear
/// grace from the service remains intact. [any] recomputes without facing mute.
SpeedcamDanger? resolvePresenceDanger({
  required SpeedcamPresenceMode mode,
  required SpeedcamHostPose? host,
  required List<SpeedcamPoint> cams,
  required double approachRadiusM,
  SpeedcamDanger? serviceDanger,
}) {
  switch (mode) {
    case SpeedcamPresenceMode.off:
      return null;
    case SpeedcamPresenceMode.dangerous:
      if (serviceDanger == null || !serviceDanger.insideApproach) return null;
      return serviceDanger;
    case SpeedcamPresenceMode.any:
      if (host == null) {
        return (serviceDanger != null && serviceDanger.insideApproach)
            ? serviceDanger
            : null;
      }
      return nearestForPresenceMode(
        mode: SpeedcamPresenceMode.any,
        host: host,
        cams: cams,
        approachRadiusM: approachRadiusM,
      );
  }
}

/// Default grace after host passes a cam (behind / leaving) before clearing alert.
const Duration kSpeedcamPassClearGrace = Duration(seconds: 4);

/// Keeps a passed-by cam alerted briefly, then suppresses it until re-approach.
///
/// Prefer heading+bearing (behind = relative bearing > 90°). When heading is
/// unknown, fall back to distance trend (was closing, now opening).
class SpeedcamPassClearGate {
  SpeedcamPassClearGate({
    this.grace = kSpeedcamPassClearGrace,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration grace;
  final DateTime Function() _clock;

  String? _graceCamId;
  DateTime? _graceUntil;
  final Set<String> _expired = <String>{};

  String? _trendCamId;
  double? _prevDistanceM;
  bool _wasClosing = false;

  void reset() {
    _graceCamId = null;
    _graceUntil = null;
    _expired.clear();
    _trendCamId = null;
    _prevDistanceM = null;
    _wasClosing = false;
  }

  bool _isLeaving(SpeedcamHostPose host, SpeedcamDanger danger) {
    final heading = host.headingDeg;
    if (heading != null) {
      return !isCamAheadOfTravel(host, danger.bearingDeg);
    }
    // Distance-trend fallback when heading unknown.
    if (_trendCamId != danger.cam.id) {
      _trendCamId = danger.cam.id;
      _prevDistanceM = danger.distanceM;
      _wasClosing = false;
      return false;
    }
    final prev = _prevDistanceM ?? danger.distanceM;
    if (danger.distanceM < prev - 5) _wasClosing = true;
    final leaving = _wasClosing && danger.distanceM > prev + 5;
    _prevDistanceM = danger.distanceM;
    return leaving;
  }

  /// Resolve danger with pass-clear grace. May return null after grace expires.
  SpeedcamDanger? resolve({
    required SpeedcamHostPose host,
    required List<SpeedcamPoint> cams,
    required double approachRadiusM,
  }) {
    // Drop expired suppressions once host is ahead again or far outside range.
    final camById = {for (final c in cams) c.id: c};
    _expired.removeWhere((id) {
      final cam = camById[id];
      if (cam == null) return true;
      final d = haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
      if (d > approachRadiusM * 1.25) return true;
      final bearing = initialBearingDegrees(host.lat, host.lon, cam.lat, cam.lon);
      return isCamAheadOfTravel(host, bearing);
    });

    final skip = Set<String>.from(_expired);
    while (true) {
      // Prefer front-hemisphere scan (0060). If nothing ahead, still consider a
      // behind/leaving facing-relevant cam so pass-clear grace can start/hold.
      var danger = nearestDanger(
        host: host,
        cams: cams,
        approachRadiusM: approachRadiusM,
        skipIds: skip,
        requireAhead: true,
      );
      if (danger == null) {
        final behind = nearestDanger(
          host: host,
          cams: cams,
          approachRadiusM: approachRadiusM,
          skipIds: skip,
          requireAhead: false,
        );
        if (behind != null &&
            behind.insideApproach &&
            _isLeaving(host, behind)) {
          danger = behind;
        }
      }
      if (danger == null) return null;

      final leaving = _isLeaving(host, danger);
      if (!leaving) {
        if (_graceCamId == danger.cam.id) {
          _graceCamId = null;
          _graceUntil = null;
        }
        _expired.remove(danger.cam.id);
        return danger;
      }

      // Behind / leaving but outside approach — report without grace hang.
      if (!danger.insideApproach) {
        _graceCamId = null;
        _graceUntil = null;
        return danger;
      }

      final now = _clock();
      if (_graceCamId == danger.cam.id && _graceUntil != null) {
        if (now.isBefore(_graceUntil!)) return danger;
        _expired.add(danger.cam.id);
        skip.add(danger.cam.id);
        _graceCamId = null;
        _graceUntil = null;
        continue;
      }

      // Start grace — keep alerting 3–5s after pass.
      _graceCamId = danger.cam.id;
      _graceUntil = now.add(grace);
      return danger;
    }
  }
}

/// Speedcam port — nearby cams + danger; enable + host pose + reload pack.
abstract class SpeedcamService {
  Stream<SpeedcamSnapshot> get snapshots;
  SpeedcamSnapshot get snapshot;
  Future<void> setEnabled(bool on);
  /// [fromLive] marks GPS/YNavi updates. Manual inject/demo/drive omit it and
  /// hold off live until [clearHostPose] (T1 tools must keep working on-car).
  Future<void> setHostPose(SpeedcamHostPose pose, {bool fromLive = false});
  Future<void> clearHostPose();

  /// Reload cams from the wired pack store (no-op if none).
  Future<void> reloadFromPack();

  /// HUD isolate: apply a DHU-relayed snapshot (ADR 0003 — events only).
  void applyRelaySnapshot(SpeedcamSnapshot snapshot);
}
