import 'dart:math' as math;

/// One OSM / sample speed camera.
class SpeedcamPoint {
  const SpeedcamPoint({
    required this.id,
    required this.lat,
    required this.lon,
    this.maxspeed,
    this.direction,
  });

  final String id;
  final double lat;
  final double lon;
  final int? maxspeed;
  final String? direction;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'lat': lat,
        'lon': lon,
        if (maxspeed != null) 'maxspeed': maxspeed,
        if (direction != null) 'direction': direction,
      };

  factory SpeedcamPoint.fromJson(Map<String, Object?> json) => SpeedcamPoint(
        id: json['id'] as String? ?? '',
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        maxspeed: (json['maxspeed'] as num?)?.toInt(),
        direction: json['direction'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      other is SpeedcamPoint &&
      other.id == id &&
      other.lat == lat &&
      other.lon == lon &&
      other.maxspeed == maxspeed &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(id, lat, lon, maxspeed, direction);
}

/// Host vehicle position for proximity (T1 inject / later GPS).
class SpeedcamHostPose {
  const SpeedcamHostPose({required this.lat, required this.lon, this.speedKmh});

  final double lat;
  final double lon;
  final double? speedKmh;

  Map<String, Object?> toJson() => <String, Object?>{
        'lat': lat,
        'lon': lon,
        if (speedKmh != null) 'speedKmh': speedKmh,
      };
}

/// Nearest cam within [approachRadiusM] (default 500 m).
class SpeedcamDanger {
  const SpeedcamDanger({
    required this.cam,
    required this.distanceM,
    required this.insideApproach,
  });

  final SpeedcamPoint cam;
  final double distanceM;
  final bool insideApproach;

  Map<String, Object?> toJson() => <String, Object?>{
        'cam': cam.toJson(),
        'distanceM': distanceM,
        'insideApproach': insideApproach,
      };
}

/// Snapshot for dumpState / readViewModel.
class SpeedcamSnapshot {
  const SpeedcamSnapshot({
    this.enabled = false,
    this.cams = const <SpeedcamPoint>[],
    this.host,
    this.danger,
    this.approachRadiusM = 500,
  });

  final bool enabled;
  final List<SpeedcamPoint> cams;
  final SpeedcamHostPose? host;
  final SpeedcamDanger? danger;
  final double approachRadiusM;

  Map<String, Object?> toJson() => <String, Object?>{
        'enabled': enabled,
        'camCount': cams.length,
        'cams': cams.map((c) => c.toJson()).toList(),
        'host': host?.toJson(),
        'danger': danger?.toJson(),
        'approachRadiusM': approachRadiusM,
      };
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

SpeedcamDanger? nearestDanger({
  required SpeedcamHostPose host,
  required List<SpeedcamPoint> cams,
  double approachRadiusM = 500,
}) {
  SpeedcamDanger? best;
  for (final cam in cams) {
    final d = haversineMetres(host.lat, host.lon, cam.lat, cam.lon);
    if (best == null || d < best.distanceM) {
      best = SpeedcamDanger(
        cam: cam,
        distanceM: d,
        insideApproach: d <= approachRadiusM,
      );
    }
  }
  return best;
}

/// Speedcam port — nearby cams + danger; enable + host pose commands.
abstract class SpeedcamService {
  Stream<SpeedcamSnapshot> get snapshots;
  SpeedcamSnapshot get snapshot;
  Future<void> setEnabled(bool on);
  Future<void> setHostPose(SpeedcamHostPose pose);
  Future<void> clearHostPose();
}
