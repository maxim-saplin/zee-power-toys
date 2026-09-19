import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  group('haversineMetres', () {
    test('same point is ~0', () {
      expect(haversineMetres(53.9, 27.5, 53.9, 27.5), closeTo(0, 0.01));
    });

    test('~111m per 0.001 deg lat', () {
      final d = haversineMetres(53.9, 27.5, 53.901, 27.5);
      expect(d, closeTo(111.2, 2));
    });
  });

  group('FakeSpeedcamService', () {
    late FakeSpeedcamService svc;

    setUp(() {
      svc = FakeSpeedcamService();
    });

    tearDown(() => svc.dispose());

    test('starts enabled with sample cams', () {
      expect(svc.snapshot.enabled, isTrue);
      expect(svc.snapshot.cams, isNotEmpty);
      expect(svc.snapshot.danger, isNull);
    });

    test('approach inside 500m flips insideApproach', () async {
      final cam = svc.snapshot.cams.first;
      await svc.approachCam(cam, distanceM: 200);
      final d = svc.snapshot.danger!;
      expect(d.cam.id, cam.id);
      expect(d.distanceM, closeTo(200, 5));
      expect(d.insideApproach, isTrue);
    });

    test('approach outside 500m is not insideApproach', () async {
      final cam = svc.snapshot.cams.first;
      await svc.approachCam(cam, distanceM: 800);
      final d = svc.snapshot.danger!;
      expect(d.insideApproach, isFalse);
      expect(d.distanceM, closeTo(800, 5));
    });

    test('disable clears cams from snapshot', () async {
      await svc.setEnabled(false);
      expect(svc.snapshot.enabled, isFalse);
      expect(svc.snapshot.cams, isEmpty);
      expect(svc.snapshot.danger, isNull);
    });
  });
}
