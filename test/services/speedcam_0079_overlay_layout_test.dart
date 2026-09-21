import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_system_overlay.dart';

void main() {
  test('SpeedcamConfig overlay layout defaults + round-trip', () {
    const c = SpeedcamConfig();
    expect(c.overlaySizeScale, 1.0);
    expect(c.overlayPlacement, SpeedcamOverlayPlacement.topEnd);
    final next = c.copyWith(
      overlaySizeScale: 1.2,
      overlayPlacement: SpeedcamOverlayPlacement.bottomStart,
    );
    final back = SpeedcamConfig.fromJson(next.toJson());
    expect(back.overlaySizeScale, closeTo(1.2, 1e-9));
    expect(back.overlayPlacement, SpeedcamOverlayPlacement.bottomStart);
  });

  test('Fake overlay setLayout records scale + placement', () async {
    final o = FakeSpeedcamSystemOverlay();
    await o.setLayout(sizeScale: 0.8, placement: 'topStart');
    expect(o.lastSizeScale, 0.8);
    expect(o.lastPlacement, 'topStart');
  });
}
