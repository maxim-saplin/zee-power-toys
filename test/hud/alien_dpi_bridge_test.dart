import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/speedcam_crt_geometry.dart';
import 'package:zee_power_toys/hud/speedcam_radar_widget.dart';

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

  test('alienCrtPlateScale keeps km type fraction equal across plate sizes', () {
    const design = 160.0;
    const kmDesign = 22.0;
    final hud = const Size(146, 106);
    final plate = speedcamCrtPlateSize(maxW: 280, maxH: 280);
    final overlay = Size(plate.width, plate.height);
    final preview = Size(plate.width, plate.height);

    final sHud = alienCrtPlateScale(hud);
    final sOv = alienCrtPlateScale(overlay);
    final sPrev = alienCrtPlateScale(preview);

    expect(sHud, closeTo(hud.shortestSide / design, 1e-9));
    expect(sPrev, closeTo(sOv, 1e-9));

    final fracHud = (kmDesign * sHud) / hud.shortestSide;
    final fracOv = (kmDesign * sOv) / overlay.shortestSide;
    expect(fracHud, closeTo(kmDesign / design, 1e-9));
    expect(fracOv, closeTo(fracHud, 1e-9));
  });
}
