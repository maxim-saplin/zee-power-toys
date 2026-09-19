import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/default_speedcam_service.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_pack_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';
import 'package:zee_power_toys/services/speedcam_pack_store.dart';

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

  group('initialBearingDegrees', () {
    test('due north ≈ 0', () {
      final b = initialBearingDegrees(53.9, 27.5, 54.0, 27.5);
      expect(b, closeTo(0, 1));
    });

    test('due east ≈ 90', () {
      final b = initialBearingDegrees(53.9, 27.5, 53.9, 27.6);
      expect(b, closeTo(90, 2));
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

    test('approach inside 500m flips insideApproach + bearing', () async {
      final cam = svc.snapshot.cams.first;
      await svc.approachCam(cam, distanceM: 200);
      final d = svc.snapshot.danger!;
      expect(d.cam.id, cam.id);
      expect(d.distanceM, closeTo(200, 5));
      expect(d.insideApproach, isTrue);
      expect(d.bearingDeg, closeTo(0, 2)); // approach from south → north
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

  group('DefaultSpeedcamService pack wiring', () {
    test('reloadFromPack uses pack cams; approach real pack cam', () async {
      final pack = FakeSpeedcamPackStore(
        cams: const [
          SpeedcamPoint(id: 'osm-pack-1', lat: 53.91, lon: 27.57, maxspeed: 60),
          SpeedcamPoint(id: 'osm-pack-2', lat: 53.92, lon: 27.58),
        ],
      );
      await pack.updatePack(SpeedcamPackIds.by);
      final svc = DefaultSpeedcamService(packStore: pack);
      await svc.reloadFromPack();
      expect(svc.snapshot.camSource, 'pack');
      expect(svc.snapshot.cams, hasLength(2));
      expect(svc.snapshot.cams.first.id, 'osm-pack-1');

      await svc.approachCam(svc.snapshot.cams.first, distanceM: 200);
      final d = svc.snapshot.danger!;
      expect(d.cam.id, 'osm-pack-1');
      expect(d.insideApproach, isTrue);
      expect(d.distanceM, closeTo(200, 5));
      expect(d.bearingDeg, closeTo(0, 2));

      await svc.approachCam(svc.snapshot.cams.first, distanceM: 800);
      expect(svc.snapshot.danger!.insideApproach, isFalse);
      svc.dispose();
      pack.dispose();
    });

    test('empty pack falls back to sample cams', () async {
      final pack = FakeSpeedcamPackStore();
      // no updatePack → empty
      final svc = DefaultSpeedcamService(packStore: pack);
      await svc.reloadFromPack();
      expect(svc.snapshot.camSource, 'fallback');
      expect(svc.snapshot.cams, isNotEmpty);
      svc.dispose();
      pack.dispose();
    });
  });
}
