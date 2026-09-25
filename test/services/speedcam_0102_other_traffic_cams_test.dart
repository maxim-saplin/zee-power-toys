import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

/// P2 from 0102 RCA — crossing / other traffic cam false alert pin.
const _p2Lat = 53.908212;
const _p2Lon = 27.423801;

void main() {
  group('isOtherTrafficCam', () {
    SpeedcamPoint cam(String? type) => SpeedcamPoint(
          id: 't',
          lat: _p2Lat,
          lon: _p2Lon,
          camType: type,
          source: 'ynavi',
        );

    test('true for CROSS_ROAD / ROAD_MARKING / NO_STOPPING / TRAFFIC tokens', () {
      expect(
        isOtherTrafficCam(cam('SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE')),
        isTrue,
      );
      expect(
        isOtherTrafficCam(cam('SPEED_CONTROL,ROAD_MARKING_CONTROL,POLICE')),
        isTrue,
      );
      expect(
        isOtherTrafficCam(cam('SPEED_CONTROL,NO_STOPPING_CONTROL,POLICE')),
        isTrue,
      );
      expect(
        isOtherTrafficCam(cam('TRAFFIC_CONTROL,POLICE')),
        isTrue,
      );
      expect(
        isOtherTrafficCam(cam('cross_road_control')),
        isTrue,
      );
    });

    test('true for LANE (0092 preserved under same taxonomy)', () {
      expect(isOtherTrafficCam(cam('LANE')), isTrue);
      expect(
        isOtherTrafficCam(cam('SPEED_CONTROL,LANE_CONTROL,POLICE')),
        isTrue,
      );
      expect(isLaneCam(cam('SPEED_CONTROL,LANE_CONTROL,POLICE')), isTrue);
    });

    test('false for pure SPEED_CONTROL / SPEED_CONTROL,POLICE / null', () {
      expect(isOtherTrafficCam(cam('SPEED_CONTROL')), isFalse);
      expect(isOtherTrafficCam(cam('SPEED_CONTROL,POLICE')), isFalse);
      expect(isOtherTrafficCam(cam('speed_camera')), isFalse);
      expect(isOtherTrafficCam(cam(null)), isFalse);
      expect(isOtherTrafficCam(cam('')), isFalse);
    });

    test('MOBILE_CONTROL alone is not other-traffic (left out intentionally)', () {
      // MapKit enum only; no strong field false-alert evidence in-repo.
      expect(isOtherTrafficCam(cam('MOBILE_CONTROL,POLICE')), isFalse);
      expect(isOtherTrafficCam(cam('SPEED_CONTROL,MOBILE_CONTROL,POLICE')), isFalse);
    });
  });

  group('0102 P2 CROSS_ROAD fixture alert mute', () {
    late DefaultSpeedcamService s;

    setUp(() {
      s = DefaultSpeedcamService(
        packStore: FakeSpeedcamPackStore(cams: const []),
        fallbackCams: const [],
        approachRadiusM: 2000,
      );
      s.setYnaviEnrichEnabled(true);
      s.setYnaviAlertEnabled(true);
      s.setYnaviCollectEnabled(true);
    });

    test('defaults: CROSS_ROAD at P2 does NOT alert; stays on map/store', () async {
      s.setAlertLaneCams(false);
      s.applyHarnessFixture(
        source: 'ynavi',
        camType: 'SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE',
        lat: _p2Lat,
        lon: _p2Lon,
        eventId: 'qa-0102-cross-p2',
        maxspeed: 60,
      );
      expect(s.snapshot.cams, hasLength(1));
      expect(s.snapshot.cams.single.id, 'ynavi:qa-0102-cross-p2');
      expect(s.snapshot.cams.single.camType, contains('CROSS_ROAD_CONTROL'));
      expect(isLaneCam(s.snapshot.cams.single), isFalse);
      expect(isOtherTrafficCam(s.snapshot.cams.single), isTrue);
      expect(s.camsForAlert, isEmpty);

      await s.approachCam(s.snapshot.cams.single, distanceM: 150, speedKmh: 50);
      expect(s.snapshot.danger, isNull);
    });

    test('toggle ON: CROSS_ROAD at P2 alerts', () async {
      s.setAlertLaneCams(true);
      s.applyHarnessFixture(
        source: 'ynavi',
        camType: 'SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE',
        lat: _p2Lat,
        lon: _p2Lon,
        eventId: 'qa-0102-cross-p2-on',
        maxspeed: 60,
      );
      expect(s.camsForAlert, hasLength(1));
      await s.approachCam(s.snapshot.cams.single, distanceM: 150, speedKmh: 50);
      expect(s.snapshot.danger, isNotNull);
      expect(s.snapshot.danger!.cam.id, 'ynavi:qa-0102-cross-p2-on');
    });

    test('defaults: synthetic LANE still muted (0092 control)', () async {
      s.setAlertLaneCams(false);
      s.applyHarnessFixture(
        source: 'ynavi',
        camType: 'LANE',
        lat: _p2Lat,
        lon: _p2Lon,
        eventId: 'qa-0102-lane-control',
      );
      expect(isLaneCam(s.snapshot.cams.single), isTrue);
      expect(isOtherTrafficCam(s.snapshot.cams.single), isTrue);
      expect(s.camsForAlert, isEmpty);
      await s.approachCam(s.snapshot.cams.single, distanceM: 150, speedKmh: 50);
      expect(s.snapshot.danger, isNull);
    });

    test('defaults: pure SPEED_CONTROL,POLICE still alerts', () async {
      s.setAlertLaneCams(false);
      s.applyHarnessFixture(
        source: 'ynavi',
        camType: 'SPEED_CONTROL,POLICE',
        lat: _p2Lat,
        lon: _p2Lon,
        eventId: 'qa-0102-speed',
        maxspeed: 60,
      );
      expect(isOtherTrafficCam(s.snapshot.cams.single), isFalse);
      expect(s.camsForAlert, hasLength(1));
      await s.approachCam(s.snapshot.cams.single, distanceM: 150, speedKmh: 50);
      expect(s.snapshot.danger, isNotNull);
    });

    test('applyOtherTrafficCamAlertFilter drops CROSS_ROAD for HUD/sound', () {
      const cross = SpeedcamPoint(
        id: 'ynavi:cross',
        lat: _p2Lat,
        lon: _p2Lon,
        maxspeed: 60,
        source: 'ynavi',
        camType: 'SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE',
      );
      const speed = SpeedcamPoint(
        id: 'ynavi:speed',
        lat: 53.91,
        lon: 27.43,
        maxspeed: 60,
        source: 'ynavi',
        camType: 'SPEED_CONTROL,POLICE',
      );
      final filtered = applyOtherTrafficCamAlertFilter(
        const [cross, speed],
        alertOtherTrafficCams: false,
      );
      expect(filtered.map((c) => c.id), ['ynavi:speed']);
      expect(
        applyLaneCamAlertFilter(const [cross, speed], alertLaneCams: false)
            .map((c) => c.id),
        ['ynavi:speed'],
      );
    });

    test('merge stamps CROSS_ROAD onto osm+ynavi so mute applies', () {
      final osm = [
        const SpeedcamPoint(
          id: 'osm-p2',
          lat: _p2Lat,
          lon: _p2Lon,
          maxspeed: 60,
          source: 'overpass',
        ),
      ];
      final ynavi = [
        const SpeedcamPoint(
          id: 'ynavi:cross',
          lat: _p2Lat,
          lon: _p2Lon,
          maxspeed: 60,
          source: 'ynavi',
          camType: 'SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE',
        ),
      ];
      final merged = DefaultSpeedcamService.mergeOsmWithYnavi(osm, ynavi);
      expect(merged.single.source, 'osm+ynavi');
      expect(merged.single.camType, contains('CROSS_ROAD_CONTROL'));
      expect(isOtherTrafficCam(merged.single), isTrue);
    });
  });
}
