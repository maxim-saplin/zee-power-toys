import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_system_overlay.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('SpeedcamConfig dhuSystemOverlay round-trip', () {
    const c = SpeedcamConfig(dhuSystemOverlay: true);
    final back = SpeedcamConfig.fromJson(c.toJson());
    expect(back.dhuSystemOverlay, isTrue);
    expect(const SpeedcamConfig().dhuSystemOverlay, isFalse);
  });

  test('FakeSpeedcamSystemOverlay tracks enable + update', () async {
    final o = FakeSpeedcamSystemOverlay();
    await o.setEnabled(true);
    await o.update(visible: true, title: '100 m', dangerous: true);
    expect(o.lastVisible, isTrue);
    await o.setEnabled(false);
    expect(o.enabled, isFalse);
  });

  test('camPassesPresenceMode off hides', () {
    const host = SpeedcamHostPose(lat: 53.9, lon: 27.5, headingDeg: 0);
    const cam = SpeedcamPoint(id: '1', lat: 53.901, lon: 27.5);
    expect(
      camPassesPresenceMode(
        mode: SpeedcamPresenceMode.off,
        host: host,
        cam: cam,
        approachRadiusM: 2000,
      ),
      isFalse,
    );
  });
}
