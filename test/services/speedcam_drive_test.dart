import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/services/speedcam_drive.dart';

void main() {
  group('pathThroughCams + densify', () {
    test('two cams produce path that enters 500m twice', () {
      const cams = [
        SpeedcamPoint(id: 'a', lat: 53.90, lon: 27.55),
        SpeedcamPoint(id: 'b', lat: 53.91, lon: 27.56),
      ];
      final wps = pathThroughCams(cams, approachM: 800);
      expect(wps.length, greaterThanOrEqualTo(4));
      final poses = densifyDrivePath(
        waypoints: wps,
        speedKmh: 80,
        tickMs: 200,
      );
      expect(poses.length, greaterThan(10));

      var enteredA = false;
      var exitedA = false;
      var enteredB = false;
      var wasInsideA = false;
      for (final p in poses) {
        final dA = haversineMetres(p.lat, p.lon, cams[0].lat, cams[0].lon);
        final dB = haversineMetres(p.lat, p.lon, cams[1].lat, cams[1].lon);
        final inA = dA <= 500;
        final inB = dB <= 500;
        if (inA && !wasInsideA) enteredA = true;
        if (!inA && wasInsideA) exitedA = true;
        if (inB) enteredB = true;
        wasInsideA = inA;
      }
      expect(enteredA, isTrue);
      expect(exitedA, isTrue);
      expect(enteredB, isTrue);
    });
  });

  group('SpeedcamDriveSim', () {
    test('ticks poses into service then stops', () async {
      final svc = FakeSpeedcamService();
      final sim = SpeedcamDriveSim(svc);
      final start = await sim.start(
        waypoints: const [
          SpeedcamWaypoint(53.90, 27.55),
          SpeedcamWaypoint(53.901, 27.55),
        ],
        speedKmh: 200,
        tickMs: 10,
      );
      expect(start['ok'], isTrue);
      expect(sim.isRunning, isTrue);
      expect(svc.snapshot.host, isNotNull);
      // Poll until finished (short path at 200 km/h).
      for (var i = 0; i < 100 && sim.isRunning; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(sim.isRunning, isFalse);
      expect(sim.poseIndex, sim.poseCount);
      sim.dispose();
      svc.dispose();
    });
  });
}
