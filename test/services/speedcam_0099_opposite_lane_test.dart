import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

/// 0099 pin — opposite-lane cam visible on pack map, muted on radar.
const k0099PinLat = 53.906458;
const k0099PinLon = 27.449042;

void main() {
  group('0099 opposite-lane collect + radar mute-over-drop', () {
    test('Enrich+Collect stores YNavi cam at pin (facing does not gate)', () {
      final svc = DefaultSpeedcamService(
        packStore: FakeSpeedcamPackStore(),
        fallbackCams: const [],
      );
      svc.setYnaviEnrichEnabled(true);
      svc.setYnaviCollectEnabled(true);
      svc.ingestYnaviEvent({
        'kind': 'cam',
        'lat': k0099PinLat,
        'lon': k0099PinLon,
        'speedLimit': 60,
        'eventId': '0099-pin',
        'source': 'ynavi',
        // YNavi has no facing; even if a direction leaked it must still store.
        'direction': 'N',
      });
      expect(svc.ynaviSessionEvents, 1);
      final stored = svc.snapshot.cams.where((c) => c.id == 'ynavi:0099-pin');
      expect(stored, isNotEmpty);
      expect(stored.first.lat, closeTo(k0099PinLat, 1e-6));
      expect(stored.first.lon, closeTo(k0099PinLon, 1e-6));
      // Collect path never copies facing onto YNavi points today — still stored.
      expect(svc.snapshot.cams.any((c) => c.id == 'ynavi:0099-pin'), isTrue);
    });

    test('collect OFF drops ingest; enrich OFF also drops', () {
      final svc = DefaultSpeedcamService(
        packStore: FakeSpeedcamPackStore(),
        fallbackCams: const [],
      );
      svc.setYnaviEnrichEnabled(true);
      svc.setYnaviCollectEnabled(false);
      svc.ingestYnaviEvent({
        'kind': 'cam',
        'lat': k0099PinLat,
        'lon': k0099PinLon,
        'speedLimit': 60,
        'eventId': '0099-off',
        'source': 'ynavi',
      });
      expect(svc.ynaviSessionEvents, 0);
      expect(svc.snapshot.cams, isEmpty);

      svc.setYnaviCollectEnabled(true);
      svc.setYnaviEnrichEnabled(false);
      svc.ingestYnaviEvent({
        'kind': 'cam',
        'lat': k0099PinLat,
        'lon': k0099PinLon,
        'speedLimit': 60,
        'eventId': '0099-enrich-off',
        'source': 'ynavi',
      });
      expect(svc.ynaviSessionEvents, 0);
    });

    test('opposite-facing OSM cam stays in snap; danger muted; radar blip dim',
        () async {
      // Cam faces north (= other lane when host heads north).
      const cam = SpeedcamPoint(
        id: 'osm-0099',
        lat: k0099PinLat,
        lon: k0099PinLon,
        maxspeed: 60,
        direction: 'N',
        source: 'overpass',
      );
      final svc = FakeSpeedcamService(sampleCams: const [cam]);
      // ~150 m south, heading north toward cam.
      final host = SpeedcamHostPose(
        lat: k0099PinLat - 150 / 111320.0,
        lon: k0099PinLon,
        speedKmh: 50,
        headingDeg: 0,
      );
      await svc.setHostPose(host);

      expect(svc.snapshot.cams.any((c) => c.id == 'osm-0099'), isTrue);
      expect(isCamRelevantForHost(host, cam), isFalse);
      // Service danger uses facing — no sting / not approach danger.
      expect(svc.snapshot.danger, isNull);

      final blips = buildSpeedcamRadarBlips(
        host: host,
        cams: svc.snapshot.cams,
        rangeM: 500,
        danger: svc.snapshot.danger,
      );
      expect(blips, isNotEmpty);
      expect(blips.any((b) => b.highlight), isFalse);
      expect(blips.first.maxspeed, 60);
      expect(blips.first.distanceM, lessThan(200));
      svc.dispose();
    });

    test('facing-relevant cam still highlights as danger on radar', () async {
      const cam = SpeedcamPoint(
        id: 'osm-into',
        lat: k0099PinLat,
        lon: k0099PinLon,
        maxspeed: 70,
        direction: 'S', // faces into northbound traffic
        source: 'overpass',
      );
      final svc = FakeSpeedcamService(sampleCams: const [cam]);
      final host = SpeedcamHostPose(
        lat: k0099PinLat - 150 / 111320.0,
        lon: k0099PinLon,
        headingDeg: 0,
      );
      await svc.setHostPose(host);
      expect(svc.snapshot.danger?.cam.id, 'osm-into');
      expect(svc.snapshot.danger?.insideApproach, isTrue);

      final blips = buildSpeedcamRadarBlips(
        host: host,
        cams: svc.snapshot.cams,
        rangeM: 500,
        danger: svc.snapshot.danger,
      );
      expect(blips.where((b) => b.highlight), hasLength(1));
      expect(blips.firstWhere((b) => b.highlight).maxspeed, 70);
      svc.dispose();
    });

    test('Dangerous presence mute still skips opposite-facing for alert', () {
      const cam = SpeedcamPoint(
        id: 'away',
        lat: k0099PinLat,
        lon: k0099PinLon,
        direction: 'N',
      );
      final host = SpeedcamHostPose(
        lat: k0099PinLat - 100 / 111320.0,
        lon: k0099PinLon,
        headingDeg: 0,
      );
      final d = nearestForPresenceMode(
        mode: SpeedcamPresenceMode.dangerous,
        host: host,
        cams: const [cam],
      );
      expect(d, isNull);
      // Any mode still selects (0060) — facing mute is Dangerous-only.
      final any = nearestForPresenceMode(
        mode: SpeedcamPresenceMode.any,
        host: host,
        cams: const [cam],
      );
      expect(any?.cam.id, 'away');
    });
  });
}
