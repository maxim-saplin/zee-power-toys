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

  test('overlay window px scales with sizeScale (0106/0116)', () {
    final a = speedcamOverlayWindowSizePx(sizeScale: 0.6, density: 2.0);
    final b = speedcamOverlayWindowSizePx(sizeScale: 1.0, density: 2.0);
    final c = speedcamOverlayWindowSizePx(sizeScale: 1.6, density: 2.0);
    final d = speedcamOverlayWindowSizePx(sizeScale: 8.0, density: 2.0);
    // dens 320 → density 2: 280dp × scale × 2
    expect(a.width, 336);
    expect(b.width, 560);
    expect(c.width, 896);
    expect(d.width, 4480);
    expect(a.width, lessThan(b.width));
    expect(b.width, lessThan(c.width));
    expect(c.width, lessThan(d.width));
    expect(a.width / a.height, closeTo(kSpeedcamCrtPlateAspect, 0.02));
    expect(d.width / d.height, closeTo(kSpeedcamCrtPlateAspect, 0.02));
  });

  test('0116: new max is 5× prior max footprint (linear)', () {
    expect(kSpeedcamOverlaySizeScaleMax / 1.6, closeTo(5.0, 1e-9));
    final priorMax = speedcamOverlayWindowSizePx(sizeScale: 1.6, density: 2.0);
    final newMax = speedcamOverlayWindowSizePx(
      sizeScale: kSpeedcamOverlaySizeScaleMax,
      density: 2.0,
    );
    expect(newMax.width / priorMax.width, closeTo(5.0, 0.01));
    expect(newMax.height / priorMax.height, closeTo(5.0, 0.01));
    // DHU dens≈1: max ~2240×1643 — proper large vs prior 448×329
    final dhuPrior = speedcamOverlayWindowSizePx(sizeScale: 1.6, density: 1.0);
    final dhuNew = speedcamOverlayWindowSizePx(
      sizeScale: kSpeedcamOverlaySizeScaleMax,
      density: 1.0,
    );
    expect(dhuPrior.width, 448);
    expect(dhuNew.width, 2240);
    expect(dhuNew.width / dhuPrior.width, closeTo(5.0, 0.01));
  });

  test('overlay window px clamps scale to 0.6–8.0 (0116)', () {
    final lo = speedcamOverlayWindowSizePx(sizeScale: 0.1, density: 2.0);
    final hi = speedcamOverlayWindowSizePx(sizeScale: 99.0, density: 2.0);
    expect(
      lo.width,
      speedcamOverlayWindowSizePx(
        sizeScale: kSpeedcamOverlaySizeScaleMin,
        density: 2.0,
      ).width,
    );
    expect(
      hi.width,
      speedcamOverlayWindowSizePx(
        sizeScale: kSpeedcamOverlaySizeScaleMax,
        density: 2.0,
      ).width,
    );
  });

  test('0116: mid and min still usable (non-degenerate)', () {
    final minS = speedcamOverlayWindowSizePx(
      sizeScale: kSpeedcamOverlaySizeScaleMin,
      density: 2.0,
    );
    final mid = speedcamOverlayWindowSizePx(sizeScale: 1.0, density: 2.0);
    expect(minS.width, greaterThanOrEqualTo(100));
    expect(mid.width, greaterThan(minS.width));
    expect(mid.width / minS.width, closeTo(1.0 / 0.6, 0.05));
  });
}
