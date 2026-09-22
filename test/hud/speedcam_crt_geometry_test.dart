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
}
