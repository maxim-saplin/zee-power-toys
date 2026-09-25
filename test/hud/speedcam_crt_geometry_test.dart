import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_crt_geometry.dart';

void main() {
  test('CRT plate aspect is landscape 300/220', () {
    expect(kSpeedcamCrtPlateAspect, closeTo(300 / 220, 1e-9));
    expect(kSpeedcamCrtPlateAspect, greaterThan(1.0));
  });

  test('speedcamCrtPlateSize never square', () {
    final a = speedcamCrtPlateSize(maxW: 360, maxH: 280);
    expect(a.width / a.height, closeTo(kSpeedcamCrtPlateAspect, 1e-6));
    final b = speedcamCrtPlateSize(maxW: 200, maxH: 200);
    expect(b.width / b.height, closeTo(kSpeedcamCrtPlateAspect, 1e-6));
    expect(b.width, isNot(equals(b.height)));
  });

  test('HUD slot keeps aspect', () {
    final s = speedcamCrtHudSlotSize(safeWidth: 1024, safeHeight: 576);
    expect(s.width / s.height, closeTo(kSpeedcamCrtPlateAspect, 1e-6));
  });

  test('overlay window px scales with sizeScale (0106)', () {
    final a = speedcamOverlayWindowSizePx(sizeScale: 0.6, density: 2.0);
    final b = speedcamOverlayWindowSizePx(sizeScale: 1.0, density: 2.0);
    final c = speedcamOverlayWindowSizePx(sizeScale: 1.6, density: 2.0);
    // dens 320 → density 2: 280dp × scale × 2
    expect(a.width, 336);
    expect(b.width, 560);
    expect(c.width, 896);
    expect(a.width, lessThan(b.width));
    expect(b.width, lessThan(c.width));
    expect(a.width / a.height, closeTo(kSpeedcamCrtPlateAspect, 0.02));
    expect(c.width / c.height, closeTo(kSpeedcamCrtPlateAspect, 0.02));
  });

  test('overlay window px clamps scale to 0.6–1.6', () {
    final lo = speedcamOverlayWindowSizePx(sizeScale: 0.1, density: 2.0);
    final hi = speedcamOverlayWindowSizePx(sizeScale: 9.0, density: 2.0);
    expect(
      lo.width,
      speedcamOverlayWindowSizePx(sizeScale: 0.6, density: 2.0).width,
    );
    expect(
      hi.width,
      speedcamOverlayWindowSizePx(sizeScale: 1.6, density: 2.0).width,
    );
  });
}
