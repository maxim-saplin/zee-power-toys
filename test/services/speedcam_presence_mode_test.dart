import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  const hostLat = 53.9;
  const hostLon = 27.5;

  /// ~111 m north of host.
  const aheadCamFacingUs = SpeedcamPoint(
    id: 'into',
    lat: hostLat + 0.001,
    lon: hostLon,
    direction: 'S',
  );
  const aheadCamSameWay = SpeedcamPoint(
    id: 'away',
    lat: hostLat + 0.001,
    lon: hostLon,
    direction: 'N',
  );
  /// ~111 m south — behind when heading north.
  const behindCam = SpeedcamPoint(
    id: 'behind',
    lat: hostLat - 0.001,
    lon: hostLon,
    direction: 'S',
  );

  const hostNorth = SpeedcamHostPose(
    lat: hostLat,
    lon: hostLon,
    headingDeg: 0,
  );

  group('scan geometry (front hemisphere)', () {
    test('ahead cam is in scan set; behind is not', () {
      expect(
        isCamInScanSet(
          host: hostNorth,
          cam: aheadCamFacingUs,
          radiusM: 500,
        ),
        isTrue,
      );
      expect(
        isCamInScanSet(
          host: hostNorth,
          cam: behindCam,
          radiusM: 500,
        ),
        isFalse,
      );
    });

    test('nearestDanger defaults to ahead + facing', () {
      final d = nearestDanger(
        host: hostNorth,
        cams: const [aheadCamSameWay, aheadCamFacingUs, behindCam],
      );
      expect(d?.cam.id, 'into');
      expect(d?.insideApproach, isTrue);
    });

    test('behind-only facing-relevant cam is not selected', () {
      expect(
        nearestDanger(host: hostNorth, cams: const [behindCam]),
        isNull,
      );
    });
  });

  group('presence mode gates', () {
    test('Dangerous: facing-relevant ahead only', () {
      expect(
        camPassesPresenceMode(
          mode: SpeedcamPresenceMode.dangerous,
          host: hostNorth,
          cam: aheadCamFacingUs,
          approachRadiusM: 500,
        ),
        isTrue,
      );
      expect(
        camPassesPresenceMode(
          mode: SpeedcamPresenceMode.dangerous,
          host: hostNorth,
          cam: aheadCamSameWay,
          approachRadiusM: 500,
        ),
        isFalse,
      );
      expect(
        nearestForPresenceMode(
          mode: SpeedcamPresenceMode.dangerous,
          host: hostNorth,
          cams: const [aheadCamSameWay, aheadCamFacingUs],
        )?.cam.id,
        'into',
      );
    });

    test('Any: ahead including same-direction (no facing mute)', () {
      expect(
        camPassesPresenceMode(
          mode: SpeedcamPresenceMode.any,
          host: hostNorth,
          cam: aheadCamSameWay,
          approachRadiusM: 500,
        ),
        isTrue,
      );
      expect(
        nearestForPresenceMode(
          mode: SpeedcamPresenceMode.any,
          host: hostNorth,
          cams: const [aheadCamSameWay],
        )?.cam.id,
        'away',
      );
      // Dangerous still mute:
      expect(
        nearestForPresenceMode(
          mode: SpeedcamPresenceMode.dangerous,
          host: hostNorth,
          cams: const [aheadCamSameWay],
        ),
        isNull,
      );
    });

    test('Off: nothing', () {
      expect(
        camPassesPresenceMode(
          mode: SpeedcamPresenceMode.off,
          host: hostNorth,
          cam: aheadCamFacingUs,
          approachRadiusM: 500,
        ),
        isFalse,
      );
      expect(
        nearestForPresenceMode(
          mode: SpeedcamPresenceMode.off,
          host: hostNorth,
          cams: const [aheadCamFacingUs],
        ),
        isNull,
      );
      expect(
        resolvePresenceDanger(
          mode: SpeedcamPresenceMode.off,
          host: hostNorth,
          cams: const [aheadCamFacingUs],
          approachRadiusM: 500,
          serviceDanger: SpeedcamDanger(
            cam: aheadCamFacingUs,
            distanceM: 100,
            bearingDeg: 0,
            insideApproach: true,
          ),
        ),
        isNull,
      );
    });

    test('resolvePresenceDanger Any ignores facing mute on serviceDanger miss',
        () {
      final anyHit = resolvePresenceDanger(
        mode: SpeedcamPresenceMode.any,
        host: hostNorth,
        cams: const [aheadCamSameWay],
        approachRadiusM: 500,
        serviceDanger: null,
      );
      expect(anyHit?.cam.id, 'away');
      expect(anyHit?.insideApproach, isTrue);
    });
  });

  group('SpeedcamConfig prefs (0060)', () {
    test('defaults HUD=Any, sound=Dangerous', () {
      const cfg = SpeedcamConfig();
      expect(cfg.hudMode, SpeedcamPresenceMode.any);
      expect(cfg.soundMode, SpeedcamPresenceMode.dangerous);
      expect(cfg.hudRadarEnabled, isTrue);
      expect(cfg.soundEnabled, isTrue);
    });

    test('JSON round-trip modes', () {
      const cfg = SpeedcamConfig(
        hudMode: SpeedcamPresenceMode.dangerous,
        soundMode: SpeedcamPresenceMode.any,
      );
      expect(SpeedcamConfig.fromJson(cfg.toJson()), equals(cfg));
    });

    test('migrates legacy bool prefs', () {
      final fromOn = SpeedcamConfig.fromJson({
        'hudRadarEnabled': true,
        'soundEnabled': true,
      });
      expect(fromOn.hudMode, SpeedcamPresenceMode.any);
      expect(fromOn.soundMode, SpeedcamPresenceMode.dangerous);

      final fromOff = SpeedcamConfig.fromJson({
        'hudRadarEnabled': false,
        'soundEnabled': false,
      });
      expect(fromOff.hudMode, SpeedcamPresenceMode.off);
      expect(fromOff.soundMode, SpeedcamPresenceMode.off);
    });

    test('copyWith legacy bool shim', () {
      const base = SpeedcamConfig();
      expect(
        base.copyWith(hudRadarEnabled: false).hudMode,
        SpeedcamPresenceMode.off,
      );
      expect(
        base.copyWith(soundEnabled: false).soundMode,
        SpeedcamPresenceMode.off,
      );
      expect(
        base
            .copyWith(soundEnabled: false)
            .copyWith(soundEnabled: true)
            .soundMode,
        SpeedcamPresenceMode.dangerous,
      );
    });
  });
}
