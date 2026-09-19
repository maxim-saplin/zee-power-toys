import 'dart:async';

import 'fakes/fake_speedcam_service.dart';
import 'speedcam.dart';
import 'speedcam_pack_store.dart';

/// Production Service — pack cams + pose → danger (bearing/distance, 500 m).
class DefaultSpeedcamService implements SpeedcamService {
  DefaultSpeedcamService({
    required SpeedcamPackStore packStore,
    this.packId = SpeedcamPackIds.by,
    List<SpeedcamPoint>? fallbackCams,
    this.approachRadiusM = 500,
  })  : _pack = packStore,
        _fallback = List<SpeedcamPoint>.unmodifiable(
          fallbackCams ?? FakeSpeedcamService.kFakeBySampleCams,
        ),
        _ctrl = StreamController<SpeedcamSnapshot>.broadcast() {
    _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
    _camSource = 'fallback';
    _emit();
    // Fire-and-forget initial pack load; callers may await reloadFromPack.
    unawaited(reloadFromPack());
  }

  final SpeedcamPackStore _pack;
  final String packId;
  final List<SpeedcamPoint> _fallback;
  final double approachRadiusM;
  final StreamController<SpeedcamSnapshot> _ctrl;

  List<SpeedcamPoint> _cams = const [];
  String _camSource = 'none';
  bool _enabled = true;
  SpeedcamHostPose? _host;
  SpeedcamSnapshot _snapshot = const SpeedcamSnapshot();

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
  Future<void> setHostPose(SpeedcamHostPose pose) async {
    _host = pose;
    _emit();
  }

  @override
  Future<void> clearHostPose() async {
    _host = null;
    _emit();
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
      _cams = List<SpeedcamPoint>.unmodifiable(cams);
      _camSource = 'pack';
    } else {
      _cams = List<SpeedcamPoint>.unmodifiable(_fallback);
      _camSource = 'fallback';
    }
    _emit();
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
        ? nearestDanger(
            host: host,
            cams: _cams,
            approachRadiusM: approachRadiusM,
          )
        : null;
    _snapshot = SpeedcamSnapshot(
      enabled: _enabled,
      cams: _enabled ? _cams : const <SpeedcamPoint>[],
      host: host,
      danger: danger,
      approachRadiusM: approachRadiusM,
      camSource: _enabled ? _camSource : 'none',
    );
    _ctrl.add(_snapshot);
  }

  void dispose() => _ctrl.close();
}
