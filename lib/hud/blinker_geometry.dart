import 'dart:ui' show Path, Rect, Size;

import '../services/car_signals.dart' show BlinkerState;
import '../services/config_store.dart' show BlinkerConfig, BlinkerShape;

// ---------------------------------------------------------------------------
// Blinker geometry — pure functions extracted from BlinkerWidget.
//
// Mirrors the pattern in lib/services/minimap_viewport.dart: sizing/placement
// math lives here as pure functions of plain values (no BuildContext, no
// Canvas painting side effects beyond returning a Path), so it can be probed
// directly by relationship assertions instead of only through
// find.byKey(...) on the rendered widget tree.
//
// The blinker widget's own shared wrapper keys (`blinker-mark-left/right`)
// sit *above* the shape switch, so they pass whether the painter draws a
// legible triangle, a circle, or nothing at all — that gap is exactly what
// let a broken bracket-shaped arrow path (and a blink animation that never
// blinked) ship undetected. Every function below is meant to be asserted
// against directly.
// ---------------------------------------------------------------------------

/// Base mark diameter in logical px at sizeScale = 1.0. Kept in sync with
/// [BlinkerWidget]'s own `_kBaseDiameter` — a real dashboard turn indicator is
/// small and crisp, not a billboard.
const double kBlinkerBaseDiameter = 18.0;

/// Blink half-cycle: matches BlinkerOverlayView.BLINK_INTERVAL_MS (production
/// embedded value) — 450ms on, 450ms off, 120 BPM cadence.
const Duration kBlinkerHalfCycle = Duration(milliseconds: 450);

/// Minimum mark diameter, in logical px, below which the shape stops being
/// legible. Also the floor the caller-supplied `slotH` must clear (as
/// `slotH * 0.5`) for that floor to be honoured without crashing.
const double _kMinDiameter = 8.0;

/// Computes the blinker mark's diameter for a slot [slotH] logical-px tall and
/// a [sizeScale] multiplier (1.0 = the calibrated neat indicator size).
///
/// `sizeScale` multiplies an *absolute* dp value ([kBlinkerBaseDiameter])
/// rather than a slot fraction, so the mark never bloats just because the
/// Safe Area / BLINKER slot happens to be tall — see [BlinkerWidget] doc
/// comment for the full rationale.
///
/// Clamped to `[8.0, slotH * 0.5]` so it can never overflow a very short
/// slot. Slots under 16dp tall (`slotH * 0.5 < 8.0`) would invert that clamp
/// range and crash — instead of propagating that crash, this degrades
/// gracefully and returns the smaller `slotH * 0.5`, i.e. the mark shrinks
/// below the nominal minimum rather than the app dying on an unusually
/// cramped Safe Area.
double blinkerMarkDiameter({required double slotH, required double sizeScale}) {
  final upperBound = slotH * 0.5;
  if (upperBound <= 0.0) return 0.0;
  if (upperBound < _kMinDiameter) {
    // Inverted-clamp guard: slot too short to honour the nominal minimum.
    return upperBound;
  }
  final requested = kBlinkerBaseDiameter * sizeScale;
  return requested.clamp(_kMinDiameter, upperBound);
}

/// Computes the render-box size for [shape] given a mark [diameter].
///
/// `dots` and `smiley` are drawn in a square box. `arrows` is drawn in a
/// `1.2 × diameter` wide box: wide enough that the triangle reads as a
/// sideways-pointing wedge rather than a symmetric dart, but nowhere near the
/// old `1.4×` — that ratio was inherited from a shape whose width was mostly
/// spent on a rectangular tail (see [blinkerArrowPath]). A plain triangle has
/// no tail to fill that extra width, so `1.4×` just stretched it into a flat,
/// shallow sliver. `1.2×` keeps a visible taper while staying close enough to
/// square that the glyph still reads as a compact indicator, not a chevron
/// banner.
Size blinkerMarkBox(BlinkerShape shape, double diameter) {
  switch (shape) {
    case BlinkerShape.dots:
      return Size(diameter, diameter);
    case BlinkerShape.arrows:
      return Size(diameter * 1.2, diameter);
    case BlinkerShape.smiley:
      return Size(diameter, diameter);
  }
}

/// Builds the filled turn-signal triangle path for a mark of [size], pointing
/// left ([isLeft] = true) or right ([isLeft] = false).
///
/// This replaces an earlier pentagon (tip + rectangular tail) ported from a
/// phase0 SVG that was authored as an *outline* meant to be stroked, not
/// filled. Filled solid, that tail dominated the silhouette and the "arrow"
/// read as a luggage tag or banner, not a turn indicator — rejected on
/// exactly that basis. The tail's own defining feature (the notch that used
/// to make it read as an arrow when stroked) was a ~4.8px sliver in the
/// authored viewport; at the default mark size (`kBlinkerBaseDiameter` =
/// 18px), any tail detail of that kind is sub-2px and mushes into a blob on
/// this emissive projector (fine detail disappears — see CONTEXT.md). A
/// plain solid triangle — the ISO 2575 idiom for a turn-signal arrow — has no
/// such fine detail to lose: it is legible at any size down to a handful of
/// pixels, which is why it has no tail at all rather than a shrunken one.
///
/// Tip sits at the outward edge of the box (left mark points left, right
/// mark points right); the base is a vertical edge at the inward side,
/// filling the box's full height. No intermediate authoring viewport is
/// needed (unlike the old pentagon) — the triangle is simple enough to
/// describe directly in the box's own coordinate space, so it never distorts
/// regardless of [size]'s actual aspect ratio.
Path blinkerArrowPath(Size size, {required bool isLeft}) {
  final w = size.width;
  final h = size.height;
  final path = Path();
  if (isLeft) {
    // Tip at the left (outward) edge; vertical base on the right (inward).
    path.moveTo(w, 0);
    path.lineTo(0, h / 2);
    path.lineTo(w, h);
  } else {
    // Mirror: tip at the right (outward) edge; vertical base on the left.
    path.moveTo(0, 0);
    path.lineTo(w, h / 2);
    path.lineTo(0, h);
  }
  path.close();
  return path;
}

/// Computes the on-screen rects for the left/right blinker marks within a
/// BLINKER slot of size [slotW] × [slotH], for the given [shape], [config]
/// (sizing/placement knobs), and current [state] (which side(s) are active).
///
/// Returns `null` for a side that shouldn't render (e.g. `left` while
/// [state] is [BlinkerState.right]); [BlinkerState.hazard] yields both,
/// [BlinkerState.off] yields neither.
///
/// Mirrors the `Positioned` placement in [BlinkerWidget].build: `left` is
/// [BlinkerConfig.sidePadFrac] of [slotW] in from the left edge; `right` is
/// the same inward padding from the right edge (i.e. its rect's left edge is
/// `slotW - padX - box.width`). Both are vertically centred at
/// `slotH * config.vertFrac`.
({Rect? left, Rect? right}) blinkerMarkRects({
  required double slotW,
  required double slotH,
  required BlinkerShape shape,
  required BlinkerConfig config,
  required BlinkerState state,
}) {
  final diameter = blinkerMarkDiameter(slotH: slotH, sizeScale: config.sizeScale);
  final box = blinkerMarkBox(shape, diameter);
  final top = slotH * config.vertFrac - box.height / 2;
  final padX = slotW * config.sidePadFrac;

  final showLeft = state == BlinkerState.left || state == BlinkerState.hazard;
  final showRight = state == BlinkerState.right || state == BlinkerState.hazard;

  return (
    left: showLeft ? Rect.fromLTWH(padX, top, box.width, box.height) : null,
    right: showRight
        ? Rect.fromLTWH(slotW - padX - box.width, top, box.width, box.height)
        : null,
  );
}

/// Pure blink-state function of elapsed time: on for `[0, half)`, off for
/// `[half, 2*half)`, repeating — i.e. on during even half-cycles, off during
/// odd ones. `on` at `elapsed = 0` matches [BlinkerWidget]'s requirement that
/// the first rendered frame is visible immediately when a side goes active.
///
/// This is the piece an `AnimationController.repeat()` (which never emits
/// `AnimationStatus.completed`/`.dismissed`) was previously missing a link
/// to: nothing derived blink state from *time*, so the mark rendered steady
/// on forever. Callers drive this off the controller's current elapsed time
/// within a `2 * half` cycle (repeat()'s value already wraps at that period,
/// so cycle-local elapsed and true wall-clock elapsed agree modulo the
/// period — this function is periodic in exactly that period).
bool blinkOnAt(Duration elapsed, {Duration half = kBlinkerHalfCycle}) {
  final halfMicros = half.inMicroseconds;
  if (halfMicros <= 0) return true;
  final cycles = elapsed.inMicroseconds ~/ halfMicros;
  return cycles.isEven;
}
