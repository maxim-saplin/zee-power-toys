import 'dart:async';
import 'dart:math' as math;

import 'fakes/fake_speedcam_service.dart';
import 'speedcam.dart';
import 'speedcam_pack_store.dart';

/// Production Service — pack cams + pose → danger (bearing/distance; radius from DHU range).
class DefaultSpeedcamService implements SpeedcamService {
  DefaultSpeedcamService({
    required SpeedcamPackStore packStore,
    this.packId = SpeedcamPackIds.by,
    List<SpeedcamPoint>? fallbackCams,
    double approachRadiusM = 500,
    DateTime Function()? clock,
  })  : _pack = packStore,
        _fallback = List<SpeedcamPoint>.unmodifiable(
          fallbackCams ?? FakeSpeedcamService.kFakeBySampleCams,
        ),
        _passGate = SpeedcamPassClearGate(clock: clock),
        _ctrl = StreamController<SpeedcamSnapshot>.broadcast() {
    _approachRadiusM = approachRadiusM;
    _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
    _camSource = 'fallback';
    _emit();
    // Fire-and-forget initial pack load; callers may await reloadFromPack.
    unawaited(reloadFromPack());
  }

  final SpeedcamPackStore _pack;
  final String packId;
  final List<SpeedcamPoint> _fallback;
  late double _approachRadiusM;
  final SpeedcamPassClearGate _passGate;
  final StreamController<SpeedcamSnapshot> _ctrl;

  double get approachRadiusM => _approachRadiusM;

  /// DHU range slider → when cams enter alert/presence.
  void setApproachRadiusM(double metres) {
    final next = metres.clamp(100.0, 5000.0);
    if (next == _approachRadiusM) return;
    _approachRadiusM = next;
    _emit();
  }

  List<SpeedcamPoint> _cams = const [];
  String _camSource = 'none';
  bool _enabled = true;
  SpeedcamHostPose? _host;
  /// When true, live GPS/YNavi poses are ignored until [clearHostPose].
  bool _holdManualPose = false;
  /// Fired after [clearHostPose] so live GPS can re-seed (0050 HARD).
  void Function()? onHostPoseCleared;
  SpeedcamSnapshot _snapshot = const SpeedcamSnapshot();
  final List<SpeedcamPoint> _ynaviOverlay = <SpeedcamPoint>[];
  DateTime? lastYnaviBridgeFire;
  int ynaviSessionEvents = 0;
  bool _ynaviEnrichEnabled = false;
  bool _ynaviCollectEnabled = true;
  bool _ynaviAlertEnabled = true;
  bool _alertLaneCams = false;
  int _ynaviPointTtlDays = 7;

  /// 0071: master gate for YNavi ingest (default OFF via config).
  bool get ynaviEnrichEnabled => _ynaviEnrichEnabled;
  bool get ynaviCollectEnabled => _ynaviCollectEnabled;
  bool get ynaviAlertEnabled => _ynaviAlertEnabled;
  /// 0088: alert on YNavi lane cams (default OFF).
  bool get alertLaneCams => _alertLaneCams;
  int get ynaviPointTtlDays => _ynaviPointTtlDays;

  /// 0072: OSM/pack points (not pure ynavi: ids).
  int get osmCamCount =>
      _cams.where((c) => !c.id.startsWith('ynavi:') && c.source != 'ynavi').length;

  /// 0072: YNavi-influenced points (source ynavi / osm+ynavi / ynavi: id).
  int get ynaviCamCount => _cams.where((c) => c.isYnaviSourced).length;

  void setYnaviEnrichEnabled(bool enabled) {
    if (_ynaviEnrichEnabled == enabled) return;
    _ynaviEnrichEnabled = enabled;
    if (!enabled) {
      clearYnaviOverlay();
    }
  }

  void setYnaviCollectEnabled(bool enabled) {
    if (_ynaviCollectEnabled == enabled) return;
    _ynaviCollectEnabled = enabled;
  }

  void setYnaviAlertEnabled(bool enabled) {
    if (_ynaviAlertEnabled == enabled) return;
    _ynaviAlertEnabled = enabled;
    _emit();
  }

  void setAlertLaneCams(bool enabled) {
    if (_alertLaneCams == enabled) return;
    _alertLaneCams = enabled;
    _emit();
  }

  void setYnaviPointTtlDays(int days) {
    final next = days.clamp(1, 30);
    final changed = _ynaviPointTtlDays != next;
    _ynaviPointTtlDays = next;
    _pruneAgedYnavi();
    if (changed || _ynaviOverlay.isNotEmpty) {
      _rebuildMerged();
    }
    _emit();
  }

  void clearYnaviOverlay() {
    if (_ynaviOverlay.isEmpty) return;
    _ynaviOverlay.clear();
    // Rebuild cams without ynavi points.
    final base = _cams
        .where((c) => c.source != 'ynavi' && !c.id.startsWith('ynavi:'))
        .toList();
    if (base.isNotEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(base);
      _camSource = 'pack';
    } else if (_camSource.contains('ynavi')) {
      _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
      _camSource = 'fallback';
    }
    _emit();
  }

  @override
  Stream<SpeedcamSnapshot> get snapshots => _ctrl.stream;

  @override
  SpeedcamSnapshot get snapshot => _snapshot;

  @override
  Future<void> setEnabled(bool on) async {
    _enabled = on;
    _emit();
  }

  @override
  Future<void> setHostPose(SpeedcamHostPose pose, {bool fromLive = false}) async {
    if (fromLive && _holdManualPose) return;
    if (!fromLive) _holdManualPose = true;
    _host = pose;
    _emit();
  }

  @override
  Future<void> clearHostPose() async {
    _host = null;
    _holdManualPose = false;
    _emit();
    onHostPoseCleared?.call();
  }

  @override
  void applyRelaySnapshot(SpeedcamSnapshot snapshot) {
    _enabled = snapshot.enabled;
    _host = snapshot.host;
    if (snapshot.cams.isNotEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(snapshot.cams);
    } else if (snapshot.danger != null) {
      _cams = List<SpeedcamPoint>.unmodifiable([snapshot.danger!.cam]);
    }
    _camSource = snapshot.camSource;
    _snapshot = SpeedcamSnapshot(
      enabled: snapshot.enabled,
      cams: snapshot.enabled
          ? (_cams.isNotEmpty
              ? _cams
              : (snapshot.danger != null ? [snapshot.danger!.cam] : const []))
          : const <SpeedcamPoint>[],
      host: snapshot.host,
      danger: snapshot.enabled ? snapshot.danger : null,
      approachRadiusM: snapshot.approachRadiusM,
      camSource: snapshot.camSource,
    );
    _ctrl.add(_snapshot);
  }

  @override
  Future<void> reloadFromPack() async {
    final cams = await _pack.loadCams(packId);
    if (_harnessOsmOverride != null) {
      _cams = List<SpeedcamPoint>.unmodifiable(
        mergeOsmWithYnavi(_harnessOsmOverride!, _ynaviOverlay),
      );
      _camSource =
          _ynaviOverlay.isEmpty ? 'harness-osm' : 'harness-osm+ynavi';
    } else if (cams.isNotEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(
        mergeOsmWithYnavi(cams, _ynaviOverlay),
      );
      _camSource = _ynaviOverlay.isEmpty ? 'pack' : 'pack+ynavi';
    } else if (_ynaviOverlay.isNotEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(_ynaviOverlay);
      _camSource = 'ynavi';
    } else {
      _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
      _camSource = 'fallback';
    }
    _emit();
  }

  /// 0096 harness: plant a shaped SPEED/LANE cam without OCR (T2).
  ///
  /// [source]: `ynavi` | `osm` | `osm+ynavi`.
  /// [camType]: e.g. `SPEED` / `LANE` / `SPEED_CONTROL` (isLaneCam keys on LANE).
  /// When [clearOthers] is true (default), drops prior harness OSM override +
  /// YNavi overlay so the fixture is the only planted cam.
  /// Does **not** flip ynaviEnrich/collect/alert — set those via setConfig
  /// first (A7/A8). Pass [lastSeenEpochMs] for aging rows (C1/C2).
  /// Returns the merged cam list after plant (for RPC echo).
  List<SpeedcamPoint> applyHarnessFixture({
    required String source,
    required String camType,
    required double lat,
    required double lon,
    String? eventId,
    int? maxspeed,
    bool clearOthers = true,
    int? lastSeenEpochMs,
  }) {
    final src = source.trim().toLowerCase();
    final type = camType.trim().isEmpty ? null : camType.trim();
    final eid = (eventId != null && eventId.trim().isNotEmpty)
        ? eventId.trim()
        : 'fix';
    final seen = lastSeenEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    final limit = (maxspeed != null && maxspeed > 0) ? maxspeed : 60;

    if (clearOthers) {
      _harnessOsmOverride = null;
      _ynaviOverlay.clear();
    }

    // 0096 beta: do NOT auto-force enrich/collect ON — A7/A8 need those
    // gates left as set via set-config. ingestYnaviEvent already no-ops when
    // enrich/collect are OFF (A7 prove).
    if (src == 'ynavi' || src == 'osm+ynavi' || src == 'osm_ynavi') {
      ingestYnaviEvent(<Object?, Object?>{
        'kind': 'cam',
        'lat': lat,
        'lon': lon,
        'eventId': eid,
        'speedLimit': limit,
        'type': type,
        'source': 'ynavi',
        't_ms': seen,
      });
    }

    if (src == 'osm' || src == 'osm+ynavi' || src == 'osm_ynavi') {
      final osmId = 'osm-fixture-$eid';
      final osmPoint = SpeedcamPoint(
        id: osmId,
        lat: lat,
        lon: lon,
        maxspeed: limit,
        source: 'overpass',
        camType: (src == 'osm') ? type : null,
        lastSeenEpochMs: seen,
      );
      final base = <SpeedcamPoint>[
        if (!clearOthers && _harnessOsmOverride != null) ..._harnessOsmOverride!,
        if (!clearOthers && _harnessOsmOverride == null)
          ..._cams.where(
            (c) => c.source != 'ynavi' && !c.id.startsWith('ynavi:'),
          ),
        osmPoint,
      ];
      // Dedupe by id — last write wins.
      final byId = <String, SpeedcamPoint>{};
      for (final c in base) {
        byId[c.id] = c;
      }
      _harnessOsmOverride = List<SpeedcamPoint>.unmodifiable(byId.values);
      _rebuildMergedFromHarness();
      _emit();
    } else if (src != 'ynavi') {
      throw ArgumentError(
        'fixture source must be ynavi|osm|osm+ynavi (got $source)',
      );
    }

    return List<SpeedcamPoint>.from(_cams);
  }

  /// Drop harness OSM override + YNavi overlay; reload pack base.
  Future<void> clearHarnessFixture() async {
    _harnessOsmOverride = null;
    _ynaviOverlay.clear();
    await reloadFromPack();
  }

  List<SpeedcamPoint>? _harnessOsmOverride;

  void _rebuildMergedFromHarness() {
    final osmBase = _harnessOsmOverride ??
        _cams
            .where((c) => c.source != 'ynavi' && !c.id.startsWith('ynavi:'))
            .toList();
    if (osmBase.isEmpty && _ynaviOverlay.isEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
      _camSource = 'fallback';
      return;
    }
    if (osmBase.isEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(_ynaviOverlay);
      _camSource = 'ynavi';
      return;
    }
    _cams = List<SpeedcamPoint>.unmodifiable(
      mergeOsmWithYnavi(osmBase, _ynaviOverlay),
    );
    _camSource = _ynaviOverlay.isEmpty ? 'harness-osm' : 'harness-osm+ynavi';
  }

  /// YNavi SPEEDCAM_DATA beside OSM (0071/72/73/74).
  void ingestYnaviEvent(Map<Object?, Object?> raw) {
    if (!_ynaviEnrichEnabled) return;
    final kind = raw['kind'] as String? ?? '';
    final tMs = (raw['t_ms'] as num?)?.toInt();
    final wallNowMs = DateTime.now().millisecondsSinceEpoch;
    final seenMs = tMs ?? wallNowMs;
    if (tMs != null) {
      lastYnaviBridgeFire =
          DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: false);
    }
    if (kind == 'heartbeat' || kind == 'status') {
      _pruneAgedYnavi(nowMs: wallNowMs);
      _rebuildMerged();
      _emit();
      return;
    }
    if (kind != 'cam') return;
    if (!_ynaviCollectEnabled) return;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    final eventId = (raw['eventId'] as String?)?.trim();
    final id = (eventId != null && eventId.isNotEmpty)
        ? 'ynavi:$eventId'
        : 'ynavi:${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
    final limit = (raw['speedLimit'] as num?)?.toInt();
    final camTypeRaw = (raw['type'] as String?) ?? (raw['tags'] as String?);
    final camType =
        (camTypeRaw != null && camTypeRaw.trim().isNotEmpty) ? camTypeRaw : null;
    final point = SpeedcamPoint(
      id: id,
      lat: lat,
      lon: lon,
      maxspeed: (limit != null && limit > 0) ? limit : null,
      source: (raw['source'] as String?) ?? 'ynavi',
      lastSeenEpochMs: seenMs,
      camType: camType,
    );
    final existingIdx = _ynaviOverlay.indexWhere((c) => c.id == id);
    if (existingIdx >= 0) {
      final prev = _ynaviOverlay[existingIdx];
      if (prev.lat == point.lat &&
          prev.lon == point.lon &&
          prev.maxspeed == point.maxspeed) {
        _ynaviOverlay[existingIdx] = SpeedcamPoint(
          id: prev.id,
          lat: prev.lat,
          lon: prev.lon,
          maxspeed: prev.maxspeed,
          direction: prev.direction,
          source: prev.source ?? 'ynavi',
          lastSeenEpochMs: seenMs,
          camType: point.camType ?? prev.camType,
        );
        _pruneAgedYnavi(nowMs: wallNowMs);
        _rebuildMerged();
        _emit();
        return;
      }
    }
    ynaviSessionEvents += 1;
    _upsertYnavi(point);
    _pruneAgedYnavi(nowMs: wallNowMs);
    _rebuildMerged();
    _emit();
  }

  void _upsertYnavi(SpeedcamPoint point) {
    final i = _ynaviOverlay.indexWhere((c) => c.id == point.id);
    if (i >= 0) {
      _ynaviOverlay[i] = point;
    } else {
      _ynaviOverlay.add(point);
    }
  }

  void _pruneAgedYnavi({int? nowMs}) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final ttlMs = _ynaviPointTtlDays * 24 * 60 * 60 * 1000;
    _ynaviOverlay.removeWhere((c) {
      final seen = c.lastSeenEpochMs;
      if (seen == null) return false;
      return now - seen > ttlMs;
    });
  }

  void _rebuildMerged() {
    final osmBase = _harnessOsmOverride ??
        _cams
            .where((c) => c.source != 'ynavi' && !c.id.startsWith('ynavi:'))
            .toList();
    if (osmBase.isEmpty && _ynaviOverlay.isEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
      _camSource = 'fallback';
      return;
    }
    if (osmBase.isEmpty) {
      _cams = List<SpeedcamPoint>.unmodifiable(_ynaviOverlay);
      _camSource = 'ynavi';
      return;
    }
    _cams = List<SpeedcamPoint>.unmodifiable(
      mergeOsmWithYnavi(osmBase, _ynaviOverlay),
    );
    _camSource = _ynaviOverlay.isEmpty ? 'pack' : 'pack+ynavi';
  }

  /// Cams used for alert/HUD danger when YNavi alert is gated (0074/0088/0092).
  List<SpeedcamPoint> get camsForAlert {
    List<SpeedcamPoint> list;
    if (_ynaviEnrichEnabled && _ynaviAlertEnabled) {
      list = _cams;
    } else {
      list = _cams.where((c) => !c.isYnaviSourced).toList();
    }
    // 0092: drop *all* isLaneCam (pure YNavi and osm+ynavi with stamped LANE).
    // Field: lane cams still alerted as 60 because HUD/sound used snap.cams and
    // bd54d10 kept OSM typing on merge — filter must cover both.
    if (_ynaviEnrichEnabled && _ynaviAlertEnabled) {
      list = applyLaneCamAlertFilter(list, alertLaneCams: _alertLaneCams);
    }
    return list;
  }

  /// Prefer OSM id when geo-close (~20 m); else keep both under distinct ids.
  static List<SpeedcamPoint> mergeOsmWithYnavi(
    List<SpeedcamPoint> osm,
    List<SpeedcamPoint> ynavi,
  ) {
    if (ynavi.isEmpty) return List<SpeedcamPoint>.from(osm);
    final out = <SpeedcamPoint>[];
    final claimedYnavi = <String>{};
    for (final o in osm) {
      SpeedcamPoint? match;
      for (final y in ynavi) {
        if (claimedYnavi.contains(y.id)) continue;
        if (_approxMeters(o.lat, o.lon, y.lat, y.lon) <= 20) {
          match = y;
          break;
        }
      }
      if (match != null) {
        claimedYnavi.add(match.id);
        out.add(SpeedcamPoint(
          id: o.id,
          lat: o.lat,
          lon: o.lon,
          maxspeed: o.maxspeed ?? match.maxspeed,
          direction: o.direction,
          source: 'osm+ynavi',
          lastSeenEpochMs: match.lastSeenEpochMs,
          // 0092: if YNavi says LANE, stamp it so camsForAlert can mute.
          // Otherwise keep OSM typing (usually null) — do not invent LANE.
          camType: isLaneCam(match) ? match.camType : o.camType,
        ));
      } else {
        out.add(o.source == null ? SpeedcamPoint(
          id: o.id,
          lat: o.lat,
          lon: o.lon,
          maxspeed: o.maxspeed,
          direction: o.direction,
          source: 'overpass',
          camType: o.camType,
        ) : o);
      }
    }
    for (final y in ynavi) {
      if (!claimedYnavi.contains(y.id)) out.add(y);
    }
    return out;
  }

  static double _approxMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = (lat1 - lat2) * 111320.0;
    final midLat = (lat1 + lat2) * 0.5 * math.pi / 180.0;
    final dLon = (lon1 - lon2) * 111320.0 * math.cos(midLat);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  /// Place host [distanceM] due south of [cam] (approach from south → bearing ~0).
  Future<void> approachCam(
    SpeedcamPoint cam, {
    required double distanceM,
    double? speedKmh,
  }) {
    final dLat = distanceM / 111320.0;
    return setHostPose(SpeedcamHostPose(
      lat: cam.lat - dLat,
      lon: cam.lon,
      speedKmh: speedKmh,
      headingDeg: 0,
    ));
  }

  void _emit() {
    final host = _host;
    final danger = (_enabled && host != null)
        ? _passGate.resolve(
            host: host,
            cams: camsForAlert,
            approachRadiusM: _approachRadiusM,
          )
        : null;
    if (host == null) _passGate.reset();
    _snapshot = SpeedcamSnapshot(
      enabled: _enabled,
      cams: _enabled ? _cams : const <SpeedcamPoint>[],
      host: host,
      danger: danger,
      approachRadiusM: _approachRadiusM,
      camSource: _enabled ? _camSource : 'none',
    );
    _ctrl.add(_snapshot);
  }

  void dispose() => _ctrl.close();
}
