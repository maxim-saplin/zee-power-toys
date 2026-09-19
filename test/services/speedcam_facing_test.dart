import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  group('parseCamFacingDegrees', () {
    test('compass and numeric', () {
      expect(parseCamFacingDegrees('N'), 0);
      expect(parseCamFacingDegrees('E'), 90);
      expect(parseCamFacingDegrees('S'), 180);
      expect(parseCamFacingDegrees('180'), 180);
      expect(parseCamFacingDegrees(null), isNull);
      expect(parseCamFacingDegrees('forward'), isNull);
    });
  });

  group('facing mute', () {
    const hostLat = 53.9;
    const hostLon = 27.5;

    test('cam facing into our traffic alerts', () {
      // Host heading north (0); cam faces south (180) → into our traffic.
      final host = const SpeedcamHostPose(
        lat: hostLat,
        lon: hostLon,
        headingDeg: 0,
      );
      final cam = const SpeedcamPoint(
        id: 'into',
        lat: hostLat + 0.001, // ~111m north
        lon: hostLon,
        direction: 'S',
      );
      expect(isCamRelevantForHost(host, cam), isTrue);
      final d = nearestDanger(host: host, cams: [cam])!;
      expect(d.insideApproach, isTrue);
      expect(d.cam.id, 'into');
    });

    test('cam facing same way we travel is muted', () {
      // Host north; cam faces north → other line.
      final host = const SpeedcamHostPose(
        lat: hostLat,
        lon: hostLon,
        headingDeg: 0,
      );
      final cam = const SpeedcamPoint(
        id: 'away',
        lat: hostLat + 0.001,
        lon: hostLon,
        direction: 'N',
      );
      expect(isCamRelevantForHost(host, cam), isFalse);
      expect(nearestDanger(host: host, cams: [cam]), isNull);
    });

    test('unknown facing fail-open', () {
      final host = const SpeedcamHostPose(
        lat: hostLat,
        lon: hostLon,
        headingDeg: 0,
      );
      final cam = const SpeedcamPoint(
        id: 'unk',
        lat: hostLat + 0.001,
        lon: hostLon,
      );
      expect(isCamRelevantForHost(host, cam), isTrue);
      expect(nearestDanger(host: host, cams: [cam])!.cam.id, 'unk');
    });

    test('unknown heading fail-open even if facing opposite-line', () {
      final host = const SpeedcamHostPose(lat: hostLat, lon: hostLon);
      final cam = const SpeedcamPoint(
        id: 'away',
        lat: hostLat + 0.001,
        lon: hostLon,
        direction: 'N',
      );
      expect(isCamRelevantForHost(host, cam), isTrue);
    });

    test('FakeService approach with heading mutes opposite', () async {
      final svc = FakeSpeedcamService(
        sampleCams: const [
          SpeedcamPoint(
            id: 'northbound-cam',
            lat: 53.901,
            lon: 27.5,
            direction: 'N', // faces north = mutes host heading 0
          ),
          SpeedcamPoint(
            id: 'southbound-cam',
            lat: 53.901,
            lon: 27.5,
            direction: 'S', // faces us when heading north
          ),
        ],
      );
      // 200 m south of cams, heading north
      await svc.setHostPose(const SpeedcamHostPose(
        lat: 53.901 - 200 / 111320.0,
        lon: 27.5,
        headingDeg: 0,
      ));
      expect(svc.snapshot.danger?.cam.id, 'southbound-cam');
      expect(svc.snapshot.danger?.insideApproach, isTrue);

      await svc.setHostPose(const SpeedcamHostPose(
        lat: 53.901 - 200 / 111320.0,
        lon: 27.5,
        headingDeg: 0,
      ));
      // Only north-facing cam in list
      final onlyAway = FakeSpeedcamService(
        sampleCams: const [
          SpeedcamPoint(id: 'away', lat: 53.901, lon: 27.5, direction: 'N'),
        ],
      );
      await onlyAway.setHostPose(const SpeedcamHostPose(
        lat: 53.901 - 200 / 111320.0,
        lon: 27.5,
        headingDeg: 0,
      ));
      expect(onlyAway.snapshot.danger, isNull);
      svc.dispose();
      onlyAway.dispose();
    });
  });
}
