/// Pixel-level probe: Config Preview must paint amber blinker ink even with
/// no CarSignal injected, under the same maxHeight:200 letterbox constraint
/// HudSettingsScreen uses. Catches the "keys exist but marks are transparent
/// / clipped" class of false-green that signed Block 0026 as done.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/blinker_widget.dart';
import 'package:zee_power_toys/widgets/hud_preview.dart';

import '../support/harness.dart';

const _kAmber = Color(0xFFFFC107);

int _countAmber(Uint8List rgba, int width, int height) {
  var n = 0;
  for (var i = 0; i < rgba.length; i += 4) {
    final r = rgba[i];
    final g = rgba[i + 1];
    final b = rgba[i + 2];
    final a = rgba[i + 3];
    // Tight match on phase0 hud_amber; allow tiny compression/blend slack.
    if (a > 200 && r > 240 && g > 180 && g < 210 && b < 30) n++;
  }
  return n;
}

Future<(ui.Image, Uint8List)> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  late ui.Image image;
  late Uint8List pixels;
  await tester.runAsync(() async {
    image = await boundary.toImage(pixelRatio: 1.0);
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    pixels = bd!.buffer.asUint8List();
  });
  return (image, pixels);
}

Future<void> _savePng(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String path,
) async {
  final boundary =
      boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bd!.buffer.asUint8List());
  });
}

void main() {
  setUp(useMockPrefs);

  testWidgets(
    'Config Preview letterbox (HudSettings maxHeight:200) paints amber blinker ink with no signal',
    (tester) async {
      final boundaryKey = GlobalKey();

      // Mirror HudSettingsScreen sticky preview: ConstrainedBox maxHeight 200.
      await pumpHud(
        tester,
        wrapWithProviders(
          Scaffold(
            body: Column(
              children: <Widget>[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: RepaintBoundary(
                    key: boundaryKey,
                    child: const HudPreview(), // forceDemoSignals=true default
                  ),
                ),
              ],
            ),
          ),
        ),
        // Phone-ish DHU width — letterbox height lands well under 200.
        size: const Size(400, 800),
        dpr: 1.0,
      );

      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);

      // Frame 0: AnimationController value=0 → blinkOnAt → ON. Capture ink.
      final (img0, px0) = await _capture(tester, boundaryKey);
      final amber0 = _countAmber(px0, img0.width, img0.height);
      await _savePng(
        tester,
        boundaryKey,
        '/workspace/zee/screenshots/t1_config_preview_t0.png',
      );

      // Advance into the OFF half-cycle (450ms half). Keys stay in tree;
      // color goes transparent — this is what a glance/screenshot can miss.
      await tester.pump(const Duration(milliseconds: 500));
      final (imgOff, pxOff) = await _capture(tester, boundaryKey);
      final amberOff = _countAmber(pxOff, imgOff.width, imgOff.height);
      await _savePng(
        tester,
        boundaryKey,
        '/workspace/zee/screenshots/t1_config_preview_toff.png',
      );

      // Keys still present during OFF (the false-green Block 0026 relied on).
      expect(find.byKey(const ValueKey('blinker-mark-left')), findsOneWidget);
      expect(find.byKey(const ValueKey('blinker-mark-right')), findsOneWidget);

      // Evidence dump for the audit report.
      // ignore: avoid_print
      print('PIXEL_PROBE amber@t0=$amber0 amber@toff=$amberOff '
          'size0=${img0.width}x${img0.height}');

      expect(
        amber0,
        greaterThan(20),
        reason: 'Config Preview must paint amber blinker ink at t=0 with no '
            'CarSignal; found $amber0 amber pixels',
      );

      // If this expectation fails, Config Preview goes dark half the blink
      // cycle — root cause of "no blinkers in preview" despite demo override.
      expect(
        amberOff,
        greaterThan(20),
        reason: 'Config Preview must STAY lit across the blink off-phase so '
            'shape/size edits are always visible (Block 0026 intent). '
            'amber@toff=$amberOff — marks are in the tree but transparent',
      );
    },
  );

  testWidgets(
    'BlinkerWidget forceBlinkOn keeps amber across what would be off-phase',
    (tester) async {
      final boundaryKey = GlobalKey();
      await pumpHud(
        tester,
        wrapWithProviders(
          RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 400,
              height: 175,
              child: BlinkerWidget(forceBlinkOn: true),
            ),
          ),
          signals: null, // default FakeCarSignals — blinker off in snapshot
        ),
        size: const Size(400, 175),
        dpr: 1.0,
      );
      // forceBlinkOn alone does not activate sides — need hazard/left/right.
      // This test documents that forceBlinkOn is necessary but not sufficient;
      // demo override must also force BlinkerState.
      expect(find.byKey(const ValueKey('blinker-mark-left')), findsNothing);
    },
  );
}
