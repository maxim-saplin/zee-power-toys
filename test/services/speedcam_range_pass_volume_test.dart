import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_alert.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  group('approach radius from DHU range', () {
    test('inside set range → insideApproach; outside → not', () async {
      final svc = FakeSpeedcamService(approachRadiusM: 1000);
      final cam = svc.snapshot.cams.firstWhere((c) => c.id == 'by-sample-2');

      await svc.approachCam(cam, distanceM: 800);
      expect(svc.snapshot.approachRadiusM, 1000);
      expect(svc.snapshot.danger!.insideApproach, isTrue);

      await svc.approachCam(cam, distanceM: 1200);
      expect(svc.snapshot.danger!.insideApproach, isFalse);
      svc.dispose();
    });

    test('setApproachRadiusM changes presence threshold live', () async {
      final svc = FakeSpeedcamService(approachRadiusM: 500);
      final cam = svc.snapshot.cams.firstWhere((c) => c.id == 'by-sample-2');
      await svc.approachCam(cam, distanceM: 800);
      expect(svc.snapshot.danger!.insideApproach, isFalse);

      svc.setApproachRadiusM(1000);
      expect(svc.snapshot.approachRadiusM, 1000);
      expect(svc.snapshot.danger!.insideApproach, isTrue);
      svc.dispose();
    });
  });

  group('pass-clear grace', () {
    test('behind cam stays ~4s then clears', () async {
      var now = DateTime.utc(2026, 9, 20, 12, 0, 0);
      const cam = SpeedcamPoint(id: 'pass-1', lat: 53.91, lon: 27.58);
      final svc = FakeSpeedcamService(
        sampleCams: const [cam],
        approachRadiusM: 500,
        clock: () => now,
      );

      // Approach from south, heading north — ahead.
      await svc.setHostPose(SpeedcamHostPose(
        lat: cam.lat - 200 / 111320.0,
        lon: cam.lon,
        headingDeg: 0,
      ));
      expect(svc.snapshot.danger?.cam.id, 'pass-1');
      expect(svc.snapshot.danger!.insideApproach, isTrue);

      // Pass: host north of cam, still heading north → cam behind.
      await svc.setHostPose(SpeedcamHostPose(
        lat: cam.lat + 50 / 111320.0,
        lon: cam.lon,
        headingDeg: 0,
      ));
      expect(svc.snapshot.danger?.cam.id, 'pass-1', reason: 'still in grace');
      expect(svc.snapshot.danger!.insideApproach, isTrue);

      now = now.add(const Duration(seconds: 5));
      await svc.setHostPose(SpeedcamHostPose(
        lat: cam.lat + 50 / 111320.0,
        lon: cam.lon,
        headingDeg: 0,
      ));
      expect(svc.snapshot.danger, isNull, reason: 'cleared after pass grace');
      svc.dispose();
    });
  });

  group('alert volume', () {
    test('SpeedcamConfig persists soundVolume; mute skips play', () async {
      const cfg = SpeedcamConfig(soundVolume: 0.4);
      final round = SpeedcamConfig.fromJson(cfg.toJson());
      expect(round.soundVolume, closeTo(0.4, 1e-9));

      final alert = FakeSpeedcamAlert();
      await alert.setVolume(0);
      await alert.playSting();
      expect(alert.playCount, 0);
      await alert.setVolume(0.7);
      await alert.playSting();
      expect(alert.playCount, 1);
      expect(alert.volume, closeTo(0.7, 1e-9));
    });
  });
}
