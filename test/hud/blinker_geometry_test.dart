// Tests for lib/hud/blinker_geometry.dart — the pure-function seam extracted
// from BlinkerWidget (Block 0027, blinker shape + blink-cadence fix).
//
// These assert *relationships*, not existence, following the pattern set by
// test/minimap_viewport_test.dart. The 35 pre-existing blinker tests in
// test/widgets/hud_root_test.dart only assert
// find.byKey(ValueKey('blinker-mark-left'/'-right')) — those keys sit on the
// shared wrapper, above the shape switch, so they pass whether the painter
// draws a legible triangle, a hollow bracket, or nothing at all. That gap is
// exactly how two real bugs shipped:
//   1. the arrow path filled an SVG *outline* verbatim, carving a notch out
//      of the tail — a fill of that path is a hollow bracket, not a solid
//      turn arrow.
//   2. the blink cadence was driven by an AnimationController status
//      listener, but `repeat()` never emits AnimationStatus.completed/
//      .dismissed, so the mark rendered steady on forever.
//
// The first bug's fix (filling the notch) shipped as a 5-point pentagon —
// tip + full rectangular tail — which was itself rejected on redesign review:
// filled solid, the tail dominated the silhouette and it read as a banner or
// luggage tag, not a turn indicator. The `blinkerArrowPath — solid triangle`
// group below asserts the *replacement* shape instead: a plain tailless
// triangle. Its defining property is taper — tip and base-centre inside the
// silhouette, but the corners nearest the tip (cut off by the taper) outside
// it — which is exactly what a tailed pentagon and a plain rectangle both
// fail to exhibit, so these assertions would catch either an unintended
// reversion.
//
// ⚠️ Never call tester.pumpAndSettle() on a subtree containing BlinkerWidget
// — its AnimationController.repeat() never settles. Use explicit
// tester.pump(Duration(...)) instead (see test/support/harness.dart).

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zee_power_toys/hud/blinker_geometry.dart';
import 'package:zee_power_toys/hud/blinker_widget.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  // ---------------------------------------------------------------------
  // blinkerArrowPath — solid silhouette, not a bracket
  // ---------------------------------------------------------------------

  group('blinkerArrowPath — solid triangle, tapered not tailed', () {
    // A generously-sized box (as if diameter = 100) so probe coordinates
    // have comfortable margin — the shape is a simple triangle described
    // directly in the box's own coordinate space (no intermediate authoring
    // viewport), so its relative proportions are identical at any size; the
    // small production size isn't what's under test here.
    final box = blinkerMarkBox(BlinkerShape.arrows, 100.0);
    final w = box.width;
    final h = box.height;

    test('left mark: tip (outward edge, vertical centre) is inside the '
        'silhouette', () {
      final path = blinkerArrowPath(box, isLeft: true);
      // Tip vertex is at (0, h/2); a hair inside it is still the point.
      expect(path.contains(Offset(2, h / 2)), isTrue);
    });

    test('left mark: base centre (inward edge, vertical centre) is inside '
        'the silhouette', () {
      final path = blinkerArrowPath(box, isLeft: true);
      // Base is the full vertical edge at x=w; a hair inside it is still
      // solid fill — this is what "fill the box height fully" means.
      expect(path.contains(Offset(w - 2, h / 2)), isTrue);
    });

    test('left mark: the outward corners (top-left / bottom-left) are '
        'outside — this is the taper, the whole point of a triangle over a '
        'tailed pentagon', () {
      final path = blinkerArrowPath(box, isLeft: true);
      // Only the single point (0, h/2) touches the outward edge; the
      // corners above/below it are cut off by the tip's diagonal edges.
      // A tailed shape (or a plain rectangle) would *not* exclude these.
      expect(path.contains(Offset(2, 2)), isFalse);
      expect(path.contains(Offset(2, h - 2)), isFalse);
    });

    test('right mark: tip (outward edge) is inside the silhouette', () {
      final path = blinkerArrowPath(box, isLeft: false);
      expect(path.contains(Offset(w - 2, h / 2)), isTrue);
    });

    test('right mark: base centre (inward edge) is inside the silhouette',
        () {
      final path = blinkerArrowPath(box, isLeft: false);
      expect(path.contains(Offset(2, h / 2)), isTrue);
    });

    test('right mark: the outward corners (top-right / bottom-right) are '
        'outside (mirror of the left-mark taper check)', () {
      final path = blinkerArrowPath(box, isLeft: false);
      expect(path.contains(Offset(w - 2, 2)), isFalse);
      expect(path.contains(Offset(w - 2, h - 2)), isFalse);
    });
  });

  group('blinkerArrowPath — mirrored left/right', () {
    final box = blinkerMarkBox(BlinkerShape.arrows, 100.0);
    final w = box.width;
    final h = box.height;

    test('left and right silhouettes have equal size (mirror, not distinct '
        'shapes)', () {
      final leftBounds = blinkerArrowPath(box, isLeft: true).getBounds();
      final rightBounds = blinkerArrowPath(box, isLeft: false).getBounds();
      expect(leftBounds.width, closeTo(rightBounds.width, 0.01));
      expect(leftBounds.height, closeTo(rightBounds.height, 0.01));
    });

    test('tip is on the left for isLeft=true, on the right for isLeft=false',
        () {
      final left = blinkerArrowPath(box, isLeft: true);
      final right = blinkerArrowPath(box, isLeft: false);

      // Both triangles span the full box width (each reaches from one edge
      // to the other), so the discriminating probe isn't "past each other's
      // extent" (as it was for the old tailed pentagon) — it's *which side
      // is the sharp tip vs. the flat base*. A point hugging the left edge,
      // near the vertical centre, sits inside the right mark's wide base but
      // is squeezed into the left mark's narrow tip wedge; a point that far
      // off-centre vertically falls outside the tip wedge while still being
      // within the base's full-height edge.
      final nearLeftEdgeOffCentre = Offset(w * 0.05, h * 0.15);
      expect(right.contains(nearLeftEdgeOffCentre), isTrue,
          reason: 'right mark has its (wide) base on the left edge');
      expect(left.contains(nearLeftEdgeOffCentre), isFalse,
          reason: "left mark's tip wedge is narrow here, near its point");

      // Mirror: same probe reflected onto the right edge.
      final nearRightEdgeOffCentre = Offset(w * 0.95, h * 0.15);
      expect(left.contains(nearRightEdgeOffCentre), isTrue,
          reason: 'left mark has its (wide) base on the right edge');
      expect(right.contains(nearRightEdgeOffCentre), isFalse,
          reason: "right mark's tip wedge is narrow here, near its point");
    });
  });

  // ---------------------------------------------------------------------
  // blinkerMarkDiameter
  // ---------------------------------------------------------------------

  group('blinkerMarkDiameter', () {
    test('sizeScale=1.0 in a roomy slot returns the calibrated base diameter',
        () {
      expect(
        blinkerMarkDiameter(slotH: 200.0, sizeScale: 1.0),
        closeTo(kBlinkerBaseDiameter, 0.001),
      );
    });

    test('sizeScale scales the requested diameter up', () {
      final base = blinkerMarkDiameter(slotH: 200.0, sizeScale: 1.0);
      final scaled = blinkerMarkDiameter(slotH: 200.0, sizeScale: 2.0);
      expect(scaled, greaterThan(base));
    });

    test('clamps to slotH * 0.5 in a slot too short for the requested size',
        () {
      // slotH=20 → upper bound 10.0, below the 18.0 requested at scale 1.0.
      expect(blinkerMarkDiameter(slotH: 20.0, sizeScale: 1.0), closeTo(10.0, 0.001));
    });

    test('degrades gracefully (no crash) when slotH * 0.5 < 8.0', () {
      // A Safe Area under 16dp tall would invert the [8.0, slotH*0.5] clamp
      // range and crash. This must return a sane (smaller) value instead.
      expect(() => blinkerMarkDiameter(slotH: 10.0, sizeScale: 1.0), returnsNormally);
      final d = blinkerMarkDiameter(slotH: 10.0, sizeScale: 1.0);
      expect(d, closeTo(5.0, 0.001)); // slotH * 0.5, below the nominal 8.0 floor
    });

    test('zero/negative slotH returns zero rather than crashing', () {
      expect(blinkerMarkDiameter(slotH: 0.0, sizeScale: 1.0), 0.0);
      expect(blinkerMarkDiameter(slotH: -5.0, sizeScale: 1.0), 0.0);
    });
  });

  // ---------------------------------------------------------------------
  // blinkerMarkBox
  // ---------------------------------------------------------------------

  group('blinkerMarkBox', () {
    test('dots and smiley are square (diameter × diameter)', () {
      expect(blinkerMarkBox(BlinkerShape.dots, 18.0), const Size(18.0, 18.0));
      expect(blinkerMarkBox(BlinkerShape.smiley, 18.0), const Size(18.0, 18.0));
    });

    test('arrows are 1.2× wider than tall — enough taper to read as a '
        'triangle, not so wide it reads as a flat wedge', () {
      final box = blinkerMarkBox(BlinkerShape.arrows, 18.0);
      expect(box.height, 18.0);
      expect(box.width, closeTo(18.0 * 1.2, 0.001));
    });
  });

  // ---------------------------------------------------------------------
  // blinkerMarkRects — relationship / monotonicity assertions
  // ---------------------------------------------------------------------

  group('blinkerMarkRects', () {
    const slotW = 400.0;
    const slotH = 200.0;

    test('off state yields neither rect', () {
      final r = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(),
        state: BlinkerState.off,
      );
      expect(r.left, isNull);
      expect(r.right, isNull);
    });

    test('hazard yields both rects', () {
      final r = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(),
        state: BlinkerState.hazard,
      );
      expect(r.left, isNotNull);
      expect(r.right, isNotNull);
    });

    test('left state yields only the left rect; right state only the right',
        () {
      final left = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(),
        state: BlinkerState.left,
      );
      expect(left.left, isNotNull);
      expect(left.right, isNull);

      final right = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(),
        state: BlinkerState.right,
      );
      expect(right.left, isNull);
      expect(right.right, isNotNull);
    });

    test('sizeScale up produces a wider box for both sides', () {
      final small = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.arrows,
        config: const BlinkerConfig(sizeScale: 1.0),
        state: BlinkerState.hazard,
      );
      final big = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.arrows,
        config: const BlinkerConfig(sizeScale: 2.0),
        state: BlinkerState.hazard,
      );
      expect(big.left!.width, greaterThan(small.left!.width));
      expect(big.right!.width, greaterThan(small.right!.width));
    });

    test('sidePadFrac up moves the left rect right and the right rect left',
        () {
      final tight = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(sidePadFrac: 0.02),
        state: BlinkerState.hazard,
      );
      final loose = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(sidePadFrac: 0.10),
        state: BlinkerState.hazard,
      );
      // Left rect's left edge moves inward (rightward) as padding grows.
      expect(loose.left!.left, greaterThan(tight.left!.left));
      // Right rect's left edge moves inward (leftward) as padding grows.
      expect(loose.right!.left, lessThan(tight.right!.left));
    });

    test('vertFrac = 0.5 centres the mark vertically in the slot', () {
      final r = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(vertFrac: 0.5),
        state: BlinkerState.left,
      );
      final rectCenterY = r.left!.top + r.left!.height / 2;
      expect(rectCenterY, closeTo(slotH * 0.5, 0.001));
    });

    test('vertFrac above 0.5 moves the mark down; below 0.5 moves it up', () {
      final top = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(vertFrac: 0.2),
        state: BlinkerState.left,
      );
      final bottom = blinkerMarkRects(
        slotW: slotW,
        slotH: slotH,
        shape: BlinkerShape.dots,
        config: const BlinkerConfig(vertFrac: 0.8),
        state: BlinkerState.left,
      );
      expect(bottom.left!.top, greaterThan(top.left!.top));
    });
  });

  // ---------------------------------------------------------------------
  // blinkOnAt
  // ---------------------------------------------------------------------

  group('blinkOnAt', () {
    test('on at elapsed = 0 (first frame visible immediately)', () {
      expect(blinkOnAt(Duration.zero), isTrue);
    });

    test('off at elapsed = half (450ms)', () {
      expect(blinkOnAt(const Duration(milliseconds: 450)), isFalse);
    });

    test('on again at elapsed = 2 * half (900ms)', () {
      expect(blinkOnAt(const Duration(milliseconds: 900)), isTrue);
    });

    test('stays off for the whole second half of the cycle', () {
      expect(blinkOnAt(const Duration(milliseconds: 600)), isFalse);
      expect(blinkOnAt(const Duration(milliseconds: 899)), isFalse);
    });

    test('stays on for the whole first half of the cycle', () {
      expect(blinkOnAt(const Duration(milliseconds: 1)), isTrue);
      expect(blinkOnAt(const Duration(milliseconds: 449)), isTrue);
    });

    test('honours a custom half-cycle duration', () {
      const half = Duration(milliseconds: 100);
      expect(blinkOnAt(Duration.zero, half: half), isTrue);
      expect(blinkOnAt(const Duration(milliseconds: 100), half: half), isFalse);
      expect(blinkOnAt(const Duration(milliseconds: 200), half: half), isTrue);
    });
  });

  // ---------------------------------------------------------------------
  // Widget-level pixel probe: renders the actual BlinkerWidget and reads
  // real pixels via RenderRepaintBoundary.toImage(). This is the level above
  // the pure functions — it confirms the painter actually calls
  // blinkerArrowPath and that the former notch location is now genuinely
  // opaque on screen, not just in the geometry function's own coordinate
  // space.
  // ---------------------------------------------------------------------

  group('BlinkerWidget arrows — pixel probe (real 18px default, taper visible)',
      () {
    testWidgets('left arrow at the true default size: base is opaque, the '
        'outward corner (cut by the taper) stays transparent', (tester) async {
      final signals = FakeCarSignals();
      const config = AppConfig(blinker: BlinkerConfig(shape: BlinkerShape.arrows));
      final boundaryKey = GlobalKey();

      // forceBlinkOn: true — deterministic, no need to pump wall-clock time
      // through the blink cycle for this probe.
      await pumpHud(
        tester,
        wrapWithProviders(
          RepaintBoundary(
            key: boundaryKey,
            child: const SizedBox(
              width: 400,
              height: 200,
              child: BlinkerWidget(forceBlinkOn: true),
            ),
          ),
          config: config,
          signals: signals,
        ),
        size: const Size(400, 200),
      );

      signals.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 10));

      final boundary =
          boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;

      // toImage()/toByteData() do real (non-fake-clock) async engine work —
      // must run inside tester.runAsync(), or the future never resolves
      // under flutter_test's FakeAsync zone.
      late ui.Image image;
      late Uint8List pixels;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        pixels = byteData!.buffer.asUint8List();
      });

      int alphaAt(int x, int y) {
        final idx = (y * image.width + x) * 4;
        return pixels[idx + 3];
      }

      // Recompute the mark's on-screen rect exactly as BlinkerWidget does,
      // via the same pure functions under test. sizeScale defaults to 1.0 and
      // slotH=200 is roomy, so blinkerMarkDiameter returns the real
      // production default (kBlinkerBaseDiameter = 18px) — this probe is
      // exercising the actual small size the mark renders at on the HUD, not
      // an inflated test-only size.
      final diameter =
          blinkerMarkDiameter(slotH: 200.0, sizeScale: config.blinker.sizeScale);
      expect(diameter, closeTo(kBlinkerBaseDiameter, 0.001),
          reason: 'this probe is only meaningful if it exercises the real '
              'default mark size, not some larger stand-in');
      final box = blinkerMarkBox(BlinkerShape.arrows, diameter);
      final rects = blinkerMarkRects(
        slotW: 400.0,
        slotH: 200.0,
        shape: BlinkerShape.arrows,
        config: config.blinker,
        state: BlinkerState.left,
      );
      final rect = rects.left!;

      // Base centre (inward edge, i.e. the mark's right side for the left
      // arrow): must be opaque — the base fills the box's full height.
      final baseX = (rect.left + box.width - 2).round().clamp(0, image.width - 1);
      final centreY = (rect.top + box.height / 2).round().clamp(0, image.height - 1);
      expect(alphaAt(baseX, centreY), greaterThan(0),
          reason: 'the vertical base at the inward edge must be solid fill '
              'at the true 18px default size');

      // Outward corner (top-left, near the tip): must be transparent — this
      // is the taper that makes the shape a triangle rather than a
      // rectangle. If this corner were opaque, the "tip" wouldn't actually
      // taper and the mark would read as a slab again.
      final tipCornerX = (rect.left + 2).round().clamp(0, image.width - 1);
      final tipCornerY = (rect.top + 2).round().clamp(0, image.height - 1);
      expect(alphaAt(tipCornerX, tipCornerY), 0,
          reason: 'the outward corner must be cut off by the taper, not '
              'painted — a solid corner here would mean no taper at all');

      // A pixel safely above the whole mark must remain transparent — the
      // widget must not paint outside its shape's silhouette.
      final aboveY = (rect.top - 10).round().clamp(0, image.height - 1);
      expect(alphaAt(baseX, aboveY), 0,
          reason: 'nothing should be painted above the mark');
    });
  });
}
