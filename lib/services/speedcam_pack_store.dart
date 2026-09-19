import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'speedcam.dart';

/// First OSM region pack (Belarus bbox).
abstract final class SpeedcamPackIds {
  static const by = 'by';
}

/// BY bbox: (south,west)–(north,east) per Overpass.
abstract final class SpeedcamByBbox {
  static const south = 51.2;
  static const west = 23.1;
  static const north = 56.2;
  static const east = 32.8;

  static String get overpassQl => '''
[out:json][timeout:90];
node["highway"="speed_camera"]($south,$west,$north,$east);
out body;
''';
}

class SpeedcamPackMeta {
  const SpeedcamPackMeta({
    required this.id,
    required this.version,
    required this.fetchedAt,
    required this.camCount,
    this.source = 'overpass',
  });

  final String id;
  final String version;
  final DateTime fetchedAt;
  final int camCount;
  final String source;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'version': version,
        'fetchedAt': fetchedAt.toUtc().toIso8601String(),
        'camCount': camCount,
        'source': source,
      };

  factory SpeedcamPackMeta.fromJson(Map<String, Object?> json) =>
      SpeedcamPackMeta(
        id: json['id'] as String? ?? '',
        version: json['version'] as String? ?? '',
        fetchedAt: DateTime.parse(json['fetchedAt'] as String),
        camCount: (json['camCount'] as num?)?.toInt() ?? 0,
        source: json['source'] as String? ?? 'overpass',
      );
}

/// OSM region pack download / cache / update (0031).
abstract class SpeedcamPackStore {
  Future<SpeedcamPackMeta?> current(String packId);
  Future<List<SpeedcamPoint>> loadCams(String packId);
  Future<SpeedcamPackMeta> updatePack(String packId);
  Stream<SpeedcamPackMeta?> watch(String packId);
}

/// On-disk JSON pack under [root]/id}.json — atomic replace via .tmp.
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
  Future<SpeedcamPackMeta> updatePack(String packId) async {
    if (packId != SpeedcamPackIds.by) {
      throw ArgumentError('unsupported packId=$packId');
    }
    await root.create(recursive: true);
    final cams = await _downloadBy();
    if (cams.isEmpty) {
      throw StateError('Overpass returned 0 speed_camera nodes for BY');
    }
    final now = _clock().toUtc();
    final meta = SpeedcamPackMeta(
      id: packId,
      version: now.toIso8601String(),
      fetchedAt: now,
      camCount: cams.length,
      source: 'overpass',
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
      final direction = tags['direction'] as String? ?? tags['traffic_sign'] as String?;
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
    // Already in our pack shape
    final meta = SpeedcamPackMeta.fromJson(
      Map<String, Object?>.from(map['meta'] as Map),
    );
    final tmp = _tmp(packId);
    await tmp.writeAsString(jsonBody, flush: true);
    await tmp.rename(_file(packId).path);
    _ctrl.add(meta);
    return meta;
  }

  Future<List<SpeedcamPoint>> _downloadBy() async {
    final res = await _client.post(
      Uri.parse(overpassUrl),
      headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'data=${Uri.encodeQueryComponent(SpeedcamByBbox.overpassQl)}',
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

  void dispose() {
    _client.close();
    _ctrl.close();
  }
}
