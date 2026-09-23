import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  late DefaultSpeedcamService s;

  setUp(() {
    s = DefaultSpeedcamService(
      packStore: FakeSpeedcamPackStore(cams: const []),
      fallbackCams: const [],
      approachRadiusM: 2000,
    );
  });

  test('A2: pure YNavi SPEED alerts with mute OFF', () async {
    s.setAlertLaneCams(false);
    s.applyHarnessFixture(
      source: 'ynavi',
      camType: 'SPEED_CONTROL',
      lat: 53.907996,
      lon: 27.424118,
      eventId: 'a2',
      maxspeed: 60,
    );
    expect(s.ynaviEnrichEnabled, isTrue);
    expect(s.snapshot.cams, hasLength(1));
    expect(isLaneCam(s.snapshot.cams.single), isFalse);
    expect(s.camsForAlert, hasLength(1));
    await s.approachCam(s.snapshot.cams.single, distanceM: 200, speedKmh: 50);
    expect(s.snapshot.danger, isNotNull);
    expect(s.snapshot.danger!.cam.id, 'ynavi:a2');
  });

  test('A3: pure YNavi LANE muted when alertLaneCams OFF', () async {
    s.setAlertLaneCams(false);
    s.applyHarnessFixture(
      source: 'ynavi',
      camType: 'LANE',
      lat: 53.907996,
      lon: 27.424118,
      eventId: 'a3',
    );
    expect(s.snapshot.cams, hasLength(1));
    expect(isLaneCam(s.snapshot.cams.single), isTrue);
    expect(s.camsForAlert, isEmpty);
    await s.approachCam(s.snapshot.cams.single, distanceM: 200, speedKmh: 50);
    expect(s.snapshot.danger, isNull);
  });

  test('A4: LANE alerts when alertLaneCams ON', () async {
    s.setAlertLaneCams(true);
    s.applyHarnessFixture(
      source: 'ynavi',
      camType: 'LANE',
      lat: 53.907996,
      lon: 27.424118,
      eventId: 'a4',
    );
    expect(s.camsForAlert, hasLength(1));
    await s.approachCam(s.snapshot.cams.single, distanceM: 200, speedKmh: 50);
    expect(s.snapshot.danger, isNotNull);
  });

  test('A5: OSM+YNavi LANE stamps mute OFF', () async {
    s.setAlertLaneCams(false);
    s.applyHarnessFixture(
      source: 'osm+ynavi',
      camType: 'LANE',
      lat: 53.907996,
      lon: 27.424118,
      eventId: 'a5',
    );
    final cam = s.snapshot.cams.single;
    expect(cam.source, 'osm+ynavi');
    expect(isLaneCam(cam), isTrue);
    expect(s.camsForAlert, isEmpty);
  });

  test('A6: OSM+YNavi pure SPEED stays SPEED; mute OFF still alerts', () async {
    s.setAlertLaneCams(false);
    s.applyHarnessFixture(
      source: 'osm+ynavi',
      camType: 'SPEED_CONTROL',
      lat: 53.907996,
      lon: 27.424118,
      eventId: 'a6',
    );
    final cam = s.snapshot.cams.single;
    expect(cam.source, 'osm+ynavi');
    expect(isLaneCam(cam), isFalse);
    expect(s.camsForAlert, hasLength(1));
    await s.approachCam(cam, distanceM: 200, speedKmh: 50);
    expect(s.snapshot.danger, isNotNull);
  });

  test('B1: same eventId twice → one ynavi id', () {
    s.applyHarnessFixture(
      source: 'ynavi',
      camType: 'SPEED',
      lat: 53.9,
      lon: 27.4,
      eventId: 'dup',
      clearOthers: true,
    );
    s.applyHarnessFixture(
      source: 'ynavi',
      camType: 'SPEED',
      lat: 53.9,
      lon: 27.4,
      eventId: 'dup',
      clearOthers: false,
    );
    expect(s.snapshot.cams.where((c) => c.id == 'ynavi:dup'), hasLength(1));
    expect(s.ynaviSessionEvents, 1);
  });
}
