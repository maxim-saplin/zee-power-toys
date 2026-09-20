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

/// Fixture-only Minsk center — NOT used as silent harvest fallback (0050).
/// Prefer live host pose, else prior pack center, else fail honestly.
const double kSpeedcamDefaultCenterLat = 53.9045;
const double kSpeedcamDefaultCenterLon = 27.5615;

/// Overpass around-query helpers (0047 → 0052).
abstract final class SpeedcamHarvestArea {
  static String overpassQl({
    required double lat,
    required double lon,
    double radiusKm = kSpeedcamHarvestRadiusKm,
  }) {
    final radiusM = (radiusKm * 1000).round();
    // highway=speed_camera nodes PLUS enforcement=maxspeed relation device
    // members (0052). Relations stay in the result so parse can fall back to
    // relation maxspeed/direction when the device node lacks them.
    return '''
[out:json][timeout:90];
(
  node["highway"="speed_camera"](around:$radiusM,$lat,$lon);
  relation["enforcement"="maxspeed"](around:$radiusM,$lat,$lon);
)->.base;
(
  .base;
  node(r.base:"device");
);
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
    final lat = centerLat ?? prior?.centerLat;
    final lon = centerLon ?? prior?.centerLon;
    if (lat == null || lon == null) {
      throw StateError(
        'No harvest center: need live host pose or a prior pack center '
        '(refusing silent Minsk fallback)',
      );
    }

    final harvested = await _downloadAround(
      lat: lat,
      lon: lon,
      radiusKm: radiusKm,
    );
    if (harvested.isEmpty && prior == null) {
      throw StateError(
        'Overpass returned 0 cameras within ${radiusKm.round()} km',
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
  ///
  /// Accepts `highway=speed_camera` nodes and `enforcement=maxspeed` relation
  /// **device** member nodes (0052). Dedupes by `osm-{id}`. maxspeed/direction
  /// prefer device tags, then fall back to the parent relation tags.
  static List<SpeedcamPoint> parseOverpassElements(List<dynamic> elements) {
    final nodesById = <int, Map<String, dynamic>>{};
    final relations = <Map<String, dynamic>>[];
    for (final raw in elements) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final type = m['type'];
      if (type == 'node') {
        final id = (m['id'] as num?)?.toInt();
        if (id != null) nodesById[id] = m;
      } else if (type == 'relation') {
        relations.add(m);
      }
    }

    final byId = <String, SpeedcamPoint>{};

    void put(SpeedcamPoint point) {
      final existing = byId[point.id];
      if (existing == null) {
        byId[point.id] = point;
        return;
      }
      // Enrich missing tags; keep first lat/lon (highway node preferred if first).
      byId[point.id] = SpeedcamPoint(
        id: existing.id,
        lat: existing.lat,
        lon: existing.lon,
        maxspeed: existing.maxspeed ?? point.maxspeed,
        direction: existing.direction ?? point.direction,
      );
    }

    for (final m in nodesById.values) {
      final tags = Map<String, dynamic>.from(m['tags'] as Map? ?? const {});
      if (tags['highway'] != 'speed_camera') continue;
      final point = _pointFromNode(m, primaryTags: tags);
      if (point != null) put(point);
    }

    for (final rel in relations) {
      final relTags = Map<String, dynamic>.from(rel['tags'] as Map? ?? const {});
      if (relTags['enforcement'] != 'maxspeed') continue;
      final members = rel['members'] as List<dynamic>? ?? const [];
      for (final memRaw in members) {
        if (memRaw is! Map) continue;
        final mem = Map<String, dynamic>.from(memRaw);
        if (mem['role'] != 'device' || mem['type'] != 'node') continue;
        final nodeId = (mem['ref'] as num?)?.toInt();
        if (nodeId == null) continue;
        final node = nodesById[nodeId];
        if (node == null) continue;
        final deviceTags =
            Map<String, dynamic>.from(node['tags'] as Map? ?? const {});
        final point = _pointFromNode(
          node,
          primaryTags: deviceTags,
          fallbackTags: relTags,
        );
        if (point != null) put(point);
      }
    }

    return byId.values.toList();
  }

  static SpeedcamPoint? _pointFromNode(
    Map<String, dynamic> node, {
    required Map<String, dynamic> primaryTags,
    Map<String, dynamic>? fallbackTags,
  }) {
    final lat = (node['lat'] as num?)?.toDouble();
    final lon = (node['lon'] as num?)?.toDouble();
    final idNum = node['id'];
    if (lat == null || lon == null || idNum == null) return null;
    final maxspeed = _parseMaxspeed(primaryTags['maxspeed']) ??
        (fallbackTags != null ? _parseMaxspeed(fallbackTags['maxspeed']) : null);
    final direction = _parseDirection(primaryTags) ??
        (fallbackTags != null ? _parseDirection(fallbackTags) : null);
    return SpeedcamPoint(
      id: 'osm-$idNum',
      lat: lat,
      lon: lon,
      maxspeed: maxspeed,
      direction: direction,
    );
  }

  static int? _parseMaxspeed(Object? maxRaw) {
    if (maxRaw is String) {
      return int.tryParse(maxRaw.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (maxRaw is num) return maxRaw.toInt();
    return null;
  }

  static String? _parseDirection(Map<String, dynamic> tags) =>
      tags['direction'] as String? ?? tags['traffic_sign'] as String?;

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
