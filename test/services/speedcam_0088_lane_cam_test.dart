import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  group('isLaneCam', () {
    test('true when camType contains LANE (any case)', () {
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 'y1',
          lat: 53.9,
          lon: 27.4,
          camType: 'LANE',
        )),
        isTrue,
      );
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 'y2',
          lat: 53.9,
          lon: 27.4,
          camType: 'speed,lane,control',
        )),
        isTrue,
      );
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 'y3',
          lat: 53.9,
          lon: 27.4,
          camType: 'LaneCam',
        )),
        isTrue,
      );
    });

    test('false for speed-only / null / empty', () {
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 's1',
          lat: 53.9,
          lon: 27.4,
          camType: 'speed_camera',
        )),
        isFalse,
      );
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 's2',
          lat: 53.9,
          lon: 27.4,
        )),
        isFalse,
      );
      expect(
        isLaneCam(const SpeedcamPoint(
          id: 's3',
          lat: 53.9,
          lon: 27.4,
          camType: '',
        )),
        isFalse,
      );
    });
  });

  group('SpeedcamPoint camType', () {
    test('json / copyWith / equality', () {
      const a = SpeedcamPoint(
        id: 'ynavi:1',
        lat: 1,
        lon: 2,
        camType: 'LANE',
      );
      final json = a.toJson();
      expect(json['camType'], 'LANE');
      expect(SpeedcamPoint.fromJson(json), a);
      expect(a.copyWith(camType: 'SPEED'), isNot(a));
      expect(a.copyWith(maxspeed: 60).camType, 'LANE');
    });
  });

  group('SpeedcamConfig.alertLaneCams', () {
    test('defaults false and persists', () {
      const c = SpeedcamConfig();
      expect(c.alertLaneCams, isFalse);
      final on = c.copyWith(alertLaneCams: true);
      expect(on.alertLaneCams, isTrue);
      expect(SpeedcamConfig.fromJson(on.toJson()).alertLaneCams, isTrue);
      expect(SpeedcamConfig.fromJson(const {}).alertLaneCams, isFalse);
    });
  });

  group('camsForAlert lane filter', () {
    DefaultSpeedcamService svc() => DefaultSpeedcamService(
          packStore: FakeSpeedcamPackStore(cams: const []),
          fallbackCams: const [
            SpeedcamPoint(
              id: 'osm:1',
              lat: 53.9,
              lon: 27.56,
              maxspeed: 60,
              source: 'overpass',
            ),
          ],
        );

    Map<Object?, Object?> cam({
      required String id,
      required String type,
      double lat = 59.84,
      double lon = 30.37,
    }) =>
        {
          'kind': 'cam',
          'lat': lat,
          'lon': lon,
          'speedLimit': 60,
          'eventId': id,
          'source': 'ynavi',
          'type': type,
          'tags': type,
          't_ms': DateTime.now().millisecondsSinceEpoch,
        };

    test('default OFF excludes LANE from camsForAlert; keeps speed', () {
      final s = svc();
      s.setYnaviEnrichEnabled(true);
      s.setYnaviCollectEnabled(true);
      s.setYnaviAlertEnabled(true);
      // default alertLaneCams false
      s.ingestYnaviEvent(cam(id: 'lane', type: 'LANE', lat: 59.84, lon: 30.37));
      s.ingestYnaviEvent(
          cam(id: 'speed', type: 'speed_camera', lat: 59.85, lon: 30.38));

      expect(s.snapshot.cams.any((c) => c.id == 'ynavi:lane'), isTrue);
      expect(s.camsForAlert.any((c) => c.id == 'ynavi:lane'), isFalse);
      expect(s.camsForAlert.any((c) => c.id == 'ynavi:speed'), isTrue);
    });

    test('alertLaneCams ON includes LANE in camsForAlert', () {
      final s = svc();
      s.setYnaviEnrichEnabled(true);
      s.setYnaviAlertEnabled(true);
      s.setAlertLaneCams(true);
      s.ingestYnaviEvent(cam(id: 'lane2', type: 'LANE'));
      expect(s.camsForAlert.any((c) => c.id == 'ynavi:lane2'), isTrue);
    });

    test('ingestYnaviEvent sets camType from type', () {
      final s = svc();
      s.setYnaviEnrichEnabled(true);
      s.ingestYnaviEvent(cam(id: 't', type: 'LANE,CONTROL'));
      final hit = s.snapshot.cams.firstWhere((c) => c.id == 'ynavi:t');
      expect(hit.camType, 'LANE,CONTROL');
      expect(isLaneCam(hit), isTrue);
    });
  });

  group('0092 osm+ynavi LANE stamp + filter', () {
    test('merge stamps YNavi LANE onto osm+ynavi at known pin', () {
      final osm = [
        const SpeedcamPoint(
          id: 'osm-1',
          lat: 53.907996,
          lon: 27.424118,
          maxspeed: 60,
          source: 'overpass',
        ),
      ];
      final ynavi = [
        const SpeedcamPoint(
          id: 'ynavi:lane',
          lat: 53.907996,
          lon: 27.424118,
          maxspeed: 60,
          source: 'ynavi',
          camType: 'SPEED_CONTROL,LANE_CONTROL,POLICE',
        ),
      ];
      final merged = DefaultSpeedcamService.mergeOsmWithYnavi(osm, ynavi);
      expect(merged, hasLength(1));
      expect(merged.single.source, 'osm+ynavi');
      expect(merged.single.camType, 'SPEED_CONTROL,LANE_CONTROL,POLICE');
      expect(isLaneCam(merged.single), isTrue);
    });

    test('merge does not invent LANE when YNavi is speed-only', () {
      final osm = [
        const SpeedcamPoint(
          id: 'osm-speed',
          lat: 53.9,
          lon: 27.56,
          maxspeed: 60,
          source: 'overpass',
        ),
      ];
      final ynavi = [
        const SpeedcamPoint(
          id: 'ynavi:speed',
          lat: 53.9,
          lon: 27.56,
          maxspeed: 60,
          source: 'ynavi',
          camType: 'SPEED_CONTROL,POLICE',
        ),
      ];
      final merged = DefaultSpeedcamService.mergeOsmWithYnavi(osm, ynavi);
      expect(merged.single.camType, isNull);
      expect(isLaneCam(merged.single), isFalse);
    });

    test('camsForAlert excludes osm+ynavi LANE when alertLaneCams OFF', () {
      final s = DefaultSpeedcamService(
        packStore: FakeSpeedcamPackStore(cams: const []),
        fallbackCams: const [
          SpeedcamPoint(
            id: 'osm-x',
            lat: 53.9,
            lon: 27.4,
            maxspeed: 60,
            source: 'osm+ynavi',
            camType: 'LANE',
          ),
        ],
      );
      s.setYnaviEnrichEnabled(true);
      s.setYnaviAlertEnabled(true);
      expect(s.camsForAlert.any((c) => c.id == 'osm-x'), isFalse);
      s.setAlertLaneCams(true);
      expect(s.camsForAlert.any((c) => c.id == 'osm-x'), isTrue);
    });

    test('applyLaneCamAlertFilter drops LANE for HUD/sound lists', () {
      const lane = SpeedcamPoint(
        id: 'ynavi:pin',
        lat: 53.907996,
        lon: 27.424118,
        maxspeed: 60,
        source: 'ynavi',
        camType: 'SPEED_CONTROL,LANE_CONTROL,POLICE',
      );
      const speed = SpeedcamPoint(
        id: 'ynavi:speed',
        lat: 53.91,
        lon: 27.43,
        maxspeed: 60,
        source: 'ynavi',
        camType: 'SPEED_CONTROL,POLICE',
      );
      final filtered = applyLaneCamAlertFilter(
        const [lane, speed],
        alertLaneCams: false,
      );
      expect(filtered.map((c) => c.id), ['ynavi:speed']);
      expect(
        applyLaneCamAlertFilter(const [lane, speed], alertLaneCams: true),
        hasLength(2),
      );
    });
  });
}
