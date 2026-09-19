import 'dart:async';

import '../speedcam.dart';

/// T1 Fake — embedded BY-ish sample cams; FL injects host pose to flip danger.
class FakeSpeedcamService implements SpeedcamService {
  FakeSpeedcamService({
    List<SpeedcamPoint>? sampleCams,
    this.approachRadiusM = 500,
  })  : _cams = List<SpeedcamPoint>.unmodifiable(
          sampleCams ?? kFakeBySampleCams,
        ),
        _ctrl = StreamController<SpeedcamSnapshot>.broadcast() {
    _emit();
  }

  static const approachRadiusMDefault = 500.0;

  /// Tiny Belarus sample (Minsk area) for T1 approach inject.
  static const kFakeBySampleCams = <SpeedcamPoint>[
    SpeedcamPoint(
      id: 'by-sample-1',
      lat: 53.9045,
      lon: 27.5615,
      maxspeed: 60,
      direction: 'NE',
    ),
    SpeedcamPoint(
      id: 'by-sample-2',
      lat: 53.9100,
      lon: 27.5800,
      maxspeed: 70,
    ),
    SpeedcamPoint(
      id: 'by-sample-3',
      lat: 53.9000,
      lon: 27.5500,
      maxspeed: 50,
      direction: 'S',
    ),
    SpeedcamPoint(
      id: 'by-sample-4',
      lat: 52.0975,
      lon: 23.7340,
      maxspeed: 60,
    ), // Brest-ish
    SpeedcamPoint(
      id: 'by-sample-5',
      lat: 55.1848,
      lon: 30.2016,
      maxspeed: 90,
    ), // Vitebsk-ish
  ];

  List<SpeedcamPoint> _cams;
  final double approachRadiusM;
  final StreamController<SpeedcamSnapshot> _ctrl;

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
  Future<void> reloadFromPack() async {
    // Fake owns embedded samples; no pack.
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
    // Prefer relayed danger as-is (bearing/distance already computed on DHU).
    _snapshot = SpeedcamSnapshot(
      enabled: snapshot.enabled,
      cams: snapshot.enabled
          ? (snapshot.cams.isNotEmpty
              ? snapshot.cams
              : (snapshot.danger != null
                  ? [snapshot.danger!.cam]
                  : _cams))
          : const <SpeedcamPoint>[],
      host: snapshot.host,
      danger: snapshot.enabled ? snapshot.danger : null,
      approachRadiusM: snapshot.approachRadiusM,
      camSource: snapshot.camSource,
    );
    _ctrl.add(_snapshot);
  }

  /// Test/FL helper: place host [distanceM] due north of [cam] (approx).
  Future<void> approachCam(SpeedcamPoint cam, {required double distanceM, double? speedKmh}) {
    // 1 deg lat ≈ 111_320 m
    final dLat = distanceM / 111320.0;
    return setHostPose(SpeedcamHostPose(
      lat: cam.lat - dLat,
      lon: cam.lon,
      speedKmh: speedKmh,
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
      camSource: _enabled ? 'fallback' : 'none',
    );
    _ctrl.add(_snapshot);
  }

  void dispose() => _ctrl.close();
}
