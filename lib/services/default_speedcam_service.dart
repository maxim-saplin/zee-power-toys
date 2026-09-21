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

  /// 0071: master gate for YNavi ingest (default OFF via config).
  bool get ynaviEnrichEnabled => _ynaviEnrichEnabled;

  void setYnaviEnrichEnabled(bool enabled) {
    if (_ynaviEnrichEnabled == enabled) return;
    _ynaviEnrichEnabled = enabled;
    if (!enabled) {
      clearYnaviOverlay();
    }
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
    if (cams.isNotEmpty) {
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

  /// Spike: route-only YNavi Windshield events beside OSM.
  void ingestYnaviEvent(Map<Object?, Object?> raw) {
    if (!_ynaviEnrichEnabled) return;
    final kind = raw['kind'] as String? ?? '';
    final tMs = (raw['t_ms'] as num?)?.toInt();
    if (tMs != null) {
      lastYnaviBridgeFire =
          DateTime.fromMillisecondsSinceEpoch(tMs, isUtc: false);
    }
    if (kind == 'heartbeat' || kind == 'status') {
      _emit();
      return;
    }
    if (kind != 'cam') return;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lon = (raw['lon'] as num?)?.toDouble();
    if (lat == null || lon == null) return;
    final eventId = (raw['eventId'] as String?)?.trim();
    final id = (eventId != null && eventId.isNotEmpty)
        ? 'ynavi:$eventId'
        : 'ynavi:${lat.toStringAsFixed(5)}_${lon.toStringAsFixed(5)}';
    final limit = (raw['speedLimit'] as num?)?.toInt();
    final point = SpeedcamPoint(
      id: id,
      lat: lat,
      lon: lon,
      maxspeed: (limit != null && limit > 0) ? limit : null,
      source: (raw['source'] as String?) ?? 'ynavi',
    );
    // Cross-feed eventId dedupe: ghost + getCurrentRoute may deliver the same id.
    final existingIdx = _ynaviOverlay.indexWhere((c) => c.id == id);
    if (existingIdx >= 0) {
      final prev = _ynaviOverlay[existingIdx];
      if (prev.lat == point.lat &&
          prev.lon == point.lon &&
          prev.maxspeed == point.maxspeed) {
        return; // already have this cam — no double blip / session bump
      }
    }
    ynaviSessionEvents += 1;
    _upsertYnavi(point);
    // Rebuild from current pack base + overlay without async pack IO when possible.
    final base = _camSource.startsWith('pack')
        ? _cams.where((c) => c.source != 'ynavi' && !(c.id.startsWith('ynavi:'))).toList()
        : <SpeedcamPoint>[];
    if (base.isEmpty && _camSource == 'fallback') {
      _cams = List<SpeedcamPoint>.unmodifiable(
        mergeOsmWithYnavi(_fallback, _ynaviOverlay),
      );
      _camSource = 'fallback+ynavi';
    } else {
      _cams = List<SpeedcamPoint>.unmodifiable(
        mergeOsmWithYnavi(base.isEmpty ? _cams.where((c) => !c.id.startsWith('ynavi:')).toList() : base, _ynaviOverlay),
      );
      _camSource = base.isEmpty && _ynaviOverlay.isNotEmpty ? 'ynavi' : 'pack+ynavi';
    }
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
        ));
      } else {
        out.add(o.source == null ? SpeedcamPoint(
          id: o.id,
          lat: o.lat,
          lon: o.lon,
          maxspeed: o.maxspeed,
          direction: o.direction,
          source: 'overpass',
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
            cams: _cams,
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
