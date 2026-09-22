import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_crt_geometry.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';
import 'package:zee_power_toys/services/fakes/fake_speedcam_service.dart';
import 'package:zee_power_toys/services/speedcam.dart';

void main() {
  test('alienDhuDpiBridge is always identity (DPI-agnostic CRT)', () {
    expect(
      alienDhuDpiBridge(devicePixelRatio: 1.0, surfaceLogicalWidth: 1024),
      1.0,
    );
    expect(
      alienDhuDpiBridge(devicePixelRatio: 2.0, surfaceLogicalWidth: 2560),
      1.0,
    );
    expect(
      alienDhuDpiBridge(devicePixelRatio: 1.0, surfaceLogicalWidth: 2560),
      1.0,
    );
  });

  test('alienCrtPlateScale on canonical plate is design fraction 22/160', () {
    const design = 160.0;
    const kmDesign = 22.0;
    final plate = const Size(kSpeedcamCrtPlateW, kSpeedcamCrtPlateH);
    final s = alienCrtPlateScale(plate);
    expect(s, closeTo(plate.shortestSide / design, 1e-9));
    expect((kmDesign * s) / plate.shortestSide, closeTo(kmDesign / design, 1e-9));
    expect(kmDesign / design, closeTo(0.1375, 1e-9));
  });

  test('pickSpeedcamDemoCam prefers maxspeed 60 over unknown-facing 70', () {
    final cam = pickSpeedcamDemoCam(FakeSpeedcamService.kFakeBySampleCams);
    expect(cam.maxspeed, kSpeedcamDemoMaxspeed);
    expect(cam.maxspeed, 60);
    // Must not be by-sample-2 (70, null direction) which HUD Demo used to pick.
    expect(cam.id, isNot('by-sample-2'));
    expect(SpeedcamRadarWidget.demoDanger.cam.maxspeed, cam.maxspeed);
  });
}
