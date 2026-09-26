import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_crt_geometry.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  test('0116: old prefs in 0.6–1.6 load identity (no sudden jump)', () {
    for (final v in [0.6, 1.0, 1.2, 1.6]) {
      final back = SpeedcamConfig.fromJson({'overlaySizeScale': v});
      expect(back.overlaySizeScale, closeTo(v, 1e-9),
          reason: 'stored $v must stay pixel-identical');
      final pxOldRange = speedcamOverlayWindowSizePx(sizeScale: v, density: 2.0);
      // Same helper — absolute scale vs 280dp; expanding max does not remap.
      expect(pxOldRange.width, greaterThan(0));
    }
  });

  test('0116: new max 8.0 round-trips; above-max clamps', () {
    final atMax = SpeedcamConfig.fromJson({'overlaySizeScale': 8.0});
    expect(atMax.overlaySizeScale, closeTo(8.0, 1e-9));
    final over = SpeedcamConfig.fromJson({'overlaySizeScale': 12.0});
    expect(over.overlaySizeScale, closeTo(kSpeedcamOverlaySizeScaleMax, 1e-9));
    final under = SpeedcamConfig.fromJson({'overlaySizeScale': 0.05});
    expect(under.overlaySizeScale, closeTo(kSpeedcamOverlaySizeScaleMin, 1e-9));
  });

  test('0116: toJson/fromJson preserves mid-new-range value', () {
    final c = const SpeedcamConfig().copyWith(overlaySizeScale: 4.0);
    final back = SpeedcamConfig.fromJson(c.toJson());
    expect(back.overlaySizeScale, closeTo(4.0, 1e-9));
  });
}
