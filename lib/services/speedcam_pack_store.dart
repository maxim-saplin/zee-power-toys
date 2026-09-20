import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'speedcam.dart';

/// On-device cam cache id (legacy file key `by.json` kept for migration).
abstract final class SpeedcamPackIds {
  /// Historical BY pack file name — still the on-disk cache id.
  static const by = 'by';

  /// Alias — same file; prefer this name in new call sites.
  static const local = by;
}

/// Default harvest radius (Maxim 0047).
const double kSpeedcamHarvestRadiusKm = 300;

/// Fallback harvest center when no host pose / prior center (Minsk).
const double kSpeedcamDefaultCenterLat = 53.9045;
const double kSpeedcamDefaultCenterLon = 27.5615;

/// Overpass around-query helpers (0047).
abstract final class SpeedcamHarvestArea {
  static String overpassQl({
    required double lat,
    required double lon,
    double radiusKm = kSpeedcamHarvestRadiusKm,
  }) {
    final radiusM = (radiusKm * 1000).round();
    return '''
[out:json][timeout:90];
node["highway"="speed_camera"](around:$radiusM,$lat,$lon);
out body;
''';
  }

  /// Merge [incoming] into [existing] by cam [SpeedcamPoint.id] (upsert).
  /// Cams only in [existing] are retained — no purge outside the new circle.
  static List<SpeedcamPoint> mergeById(
    List<SpeedcamPoint> existing,
    List<SpeedcamPoint> incoming,
  ) {
    final byId = <String, SpeedcamPoint>{
      for (final c in existing) c.id: c,
    };
    for (final c in incoming) {
      byId[c.id] = c;
    }
    return byId.values.toList();
  }
}

class SpeedcamPackMeta {
  const SpeedcamPackMeta({
    required this.id,
    required this.version,
    required this.fetchedAt,
    required this.camCount,
    this.source = 'overpass',
    this.regionLabel = 'within 300 km',
    this.radiusKm = kSpeedcamHarvestRadiusKm,
    this.centerLat,
    this.centerLon,
    this.lastHarvestCount,
  });

  final String id;
  final String version;
  final DateTime fetchedAt;
  final int camCount;
  final String source;

  /// Human coverage label — radius honesty, not country ISO.
  final String regionLabel;

  /// Last harvest radius in km (default 300).
  final double radiusKm;

  /// Center of last harvest (host pose / fallback).
  final double? centerLat;
  final double? centerLon;

  /// Cams returned by the last Overpass fetch (before merge).
  final int? lastHarvestCount;

  /// Age of the pack relative to [now].
  Duration age({DateTime? now}) =>
      (now ?? DateTime.now().toUtc()).difference(fetchedAt.toUtc());

  bool isStale({required int afterDays, DateTime? now}) =>
      age(now: now) >= Duration(days: afterDays);

  /// Honest coverage line for DHU meta (no BY / ISO).
  String get coverageLabel {
    final r = radiusKm == radiusKm.roundToDouble()
        ? radiusKm.round().toString()
        : radiusKm.toStringAsFixed(0);
    return 'within $r km';
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'version': version,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'camCount': camCount,
        'source': source,
        'regionLabel': regionLabel,
        'radiusKm': radiusKm,
        if (centerLat != null) 'centerLat': centerLat,
        if (centerLon != null) 'centerLon': centerLon,
        if (lastHarvestCount != null) 'lastHarvestCount': lastHarvestCount,
      };

  factory SpeedcamPackMeta.fromJson(Map<String, Object?> json) {
    final legacyLabel = json['regionLabel'] as String?;
    final radius =
        (json['radiusKm'] as num?)?.toDouble() ?? kSpeedcamHarvestRadiusKm;
    // Migrate old BY labels → radius honesty.
    final label = (legacyLabel == null ||
            legacyLabel.contains('BY') ||
            legacyLabel.contains('Belarus'))
        ? 'within ${radius == radius.roundToDouble() ? radius.round() : radius.toStringAsFixed(0)} km'
        : legacyLabel;
    return SpeedcamPackMeta(
      id: json['id'] as String? ?? '',
      version: json['version'] as String? ?? '',
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      camCount: (json['camCount'] as num?)?.toInt() ?? 0,
      source: json['source'] as String? ?? 'overpass',
      regionLabel: label,
      radiusKm: radius,
      centerLat: (json['centerLat'] as num?)?.toDouble(),
      centerLon: (json['centerLon'] as num?)?.toDouble(),
      lastHarvestCount: (json['lastHarvestCount'] as num?)?.toInt(),
    );
  }
}

/// OSM cam cache download / merge / update (0031 → 0047).
abstract class SpeedcamPackStore {
  Future<SpeedcamPackMeta?> current(String packId);
  Future<List<SpeedcamPoint>> loadCams(String packId);

  /// Harvest around [centerLat]/[centerLon] and **merge** into cache.
  Future<SpeedcamPackMeta> updatePack(
    String packId, {
    double? centerLat,
    double? centerLon,
    double radiusKm = kSpeedcamHarvestRadiusKm,
  });

  Stream<SpeedcamPackMeta?> watch(String packId);

  /// Refresh when missing or stale. [ifStale]=false → never auto-fetch.
  Future<SpeedcamPackMeta?> refreshIfNeeded({
    required String packId,
    required bool ifStale,
    required int staleAfterDays,
    DateTime? now,
    double? centerLat,
    double? centerLon,
  });
}

/// On-disk JSON pack under [root]/{id}.json — atomic replace via .tmp.
class FileSpeedcamPackStore implements SpeedcamPackStore {
  FileSpeedcamPackStore({
    required this.root,
    http.Client? client,
    this.overpassUrl = 'https://overpass-api.de/api/interpreter',
    DateTime Function()? clock,
  })  : _client = client ?? http.Client(),
        _clock = clock ?? DateTime.now;

  final Directory root;
  final http.Client _client;
  final String overpassUrl;
  final DateTime Function() _clock;
  final _ctrl = StreamController<SpeedcamPackMeta?>.broadcast();

  File _file(String packId) => File('${root.path}/$packId.json');
  File _tmp(String packId) => File('${root.path}/$packId.json.tmp');

  @override
  Stream<SpeedcamPackMeta?> watch(String packId) async* {
    yield await current(packId);
    yield* _ctrl.stream.where((m) => m == null || m.id == packId);
  }

  @override
  Future<SpeedcamPackMeta?> current(String packId) async {
    final f = _file(packId);
    if (!await f.exists()) return null;
    try {
      final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      final meta = map['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;
      return SpeedcamPackMeta.fromJson(Map<String, Object?>.from(meta));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SpeedcamPoint>> loadCams(String packId) async {
    final f = _file(packId);
    if (!await f.exists()) return const <SpeedcamPoint>[];
    final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    final cams = map['cams'] as List<dynamic>? ?? const [];
    return cams
        .map((e) => SpeedcamPoint.fromJson(Map<String, Object?>.from(e as Map)))
        .toList();
  }

  @override
  Future<SpeedcamPackMeta> updatePack(
    String packId, {
    double? centerLat,
    double? centerLon,
    double radiusKm = kSpeedcamHarvestRadiusKm,
  }) async {
    if (packId != SpeedcamPackIds.by && packId != SpeedcamPackIds.local) {
      throw ArgumentError('unsupported packId=$packId');
    }
    await root.create(recursive: true);

    final prior = await current(packId);
    final lat = centerLat ??
        prior?.centerLat ??
        kSpeedcamDefaultCenterLat;
    final lon = centerLon ??
        prior?.centerLon ??
        kSpeedcamDefaultCenterLon;

    final harvested = await _downloadAround(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
    if (harvested.isEmpty && prior == null) {
      throw StateError(
        'Overpass returned 0 speed_camera nodes within ${radiusKm.round()} km',
      );
    }

    final existing = await loadCams(packId);
    final merged = SpeedcamHarvestArea.mergeById(existing, harvested);

    final now = _clock().toUtc();
    final rLabel =
        'within ${radiusKm == radiusKm.roundToDouble() ? radiusKm.round() : radiusKm.toStringAsFixed(0)} km';
    final meta = SpeedcamPackMeta(
      id: packId,
      version: now.toIso8601String(),
      fetchedAt: now,
      camCount: merged.length,
      source: 'overpass',
      regionLabel: rLabel,
      radiusKm: radiusKm,
      centerLat: lat,
      centerLon: lon,
      lastHarvestCount: harvested.length,
    );
    final body = jsonEncode(<String, Object?>{
      'meta': meta.toJson(),
      'cams': merged.map((c) => c.toJson()).toList(),
    });
    final tmp = _tmp(packId);
    await tmp.writeAsString(body, flush: true);
    await tmp.rename(_file(packId).path);
    _ctrl.add(meta);
    return meta;
  }

  /// Parse Overpass JSON elements → [SpeedcamPoint].
  static List<SpeedcamPoint> parseOverpassElements(List<dynamic> elements) {
    final out = <SpeedcamPoint>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      if (m['type'] != 'node') continue;
      final lat = (m['lat'] as num?)?.toDouble();
      final lon = (m['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) continue;
      final tags = Map<String, dynamic>.from(m['tags'] as Map? ?? const {});
      if (tags['highway'] != 'speed_camera') continue;
      final id = 'osm-${m['id']}';
      final maxRaw = tags['maxspeed'];
      int? maxspeed;
      if (maxRaw is String) {
        maxspeed = int.tryParse(maxRaw.replaceAll(RegExp(r'[^0-9]'), ''));
      } else if (maxRaw is num) {
        maxspeed = maxRaw.toInt();
      }
      final direction =
          tags['direction'] as String? ?? tags['traffic_sign'] as String?;
      out.add(SpeedcamPoint(
        id: id,
        lat: lat,
        lon: lon,
        maxspeed: maxspeed,
        direction: direction,
      ));
    }
    return out;
  }

  /// Load pack from a fixture file (tests / Overpass flaky).
  Future<SpeedcamPackMeta> installFixture({
    required String packId,
    required String jsonBody,
    String source = 'fixture',
  }) async {
    await root.create(recursive: true);
    final map = jsonDecode(jsonBody) as Map<String, dynamic>;
    List<SpeedcamPoint> cams;
    if (map.containsKey('elements')) {
      cams = parseOverpassElements(map['elements'] as List<dynamic>);
      final now = _clock().toUtc();
      final meta = SpeedcamPackMeta(
        id: packId,
        version: now.toIso8601String(),
        fetchedAt: now,
        camCount: cams.length,
        source: source,
        regionLabel: 'within ${kSpeedcamHarvestRadiusKm.round()} km',
        radiusKm: kSpeedcamHarvestRadiusKm,
        centerLat: kSpeedcamDefaultCenterLat,
        centerLon: kSpeedcamDefaultCenterLon,
        lastHarvestCount: cams.length,
      );
      final body = jsonEncode(<String, Object?>{
        'meta': meta.toJson(),
        'cams': cams.map((c) => c.toJson()).toList(),
      });
      final tmp = _tmp(packId);
      await tmp.writeAsString(body, flush: true);
      await tmp.rename(_file(packId).path);
      _ctrl.add(meta);
      return meta;
    }
    // Already in our pack shape — write as-is (tests plant aged packs).
    final meta = SpeedcamPackMeta.fromJson(
      Map<String, Object?>.from(map['meta'] as Map),
    );
    final tmp = _tmp(packId);
    await tmp.writeAsString(jsonBody, flush: true);
    await tmp.rename(_file(packId).path);
    _ctrl.add(meta);
    return meta;
  }

  Future<List<SpeedcamPoint>> _downloadAround({
    required double lat,
    required double lon,
    required double radiusKm,
  }) async {
    final ql = SpeedcamHarvestArea.overpassQl(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
    final res = await _client.post(
      Uri.parse(overpassUrl),
      headers: const {
        'Content-Type': 'application/x-www-form-urlencoded',
        // Overpass returns HTTP 406 without a User-Agent (QA T2 @ 07f7389).
        'User-Agent':
            'zee-power-toys/0.1 (speedcam-pack; contact=github.com/maxim-saplin/zee-power-toys)',
        'Accept': 'application/json',
      },
      body: 'data=${Uri.encodeQueryComponent(ql)}',
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw HttpException(
        'Overpass HTTP ${res.statusCode}: ${res.body.length > 200 ? res.body.substring(0, 200) : res.body}',
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final elements = map['elements'] as List<dynamic>? ?? const [];
    return parseOverpassElements(elements);
  }

  @override
  Future<SpeedcamPackMeta?> refreshIfNeeded({
    required String packId,
    required bool ifStale,
    required int staleAfterDays,
    DateTime? now,
    double? centerLat,
    double? centerLon,
  }) async {
    final meta = await current(packId);
    if (!ifStale) return meta;
    if (meta == null || meta.isStale(afterDays: staleAfterDays, now: now)) {
      return updatePack(
        packId,
        centerLat: centerLat,
        centerLon: centerLon,
      );
    }
    return meta;
  }

  void dispose() {
    _client.close();
    _ctrl.close();
  }
}
