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

/// Intrinsic horizontal scale for the arrow asset geometry. This shrinks the
/// glyph in its own coordinate system; it is not a runtime transform.
const double kBlinkerArrowHorizontalScale = 0.70;

/// Computes the render-box size for [shape] given a mark [diameter].
///
/// `dots` and `smiley` are drawn in a square box. `arrows` is drawn in a
/// `1.12 × diameter` wide box — 70% of the previous horizontal span. The
/// head-plus-stem indicator glyph (see
/// [blinkerArrowPath]) needs the extra width for its stem; the head alone
/// occupies [kBlinkerArrowHeadWidthFrac] of it, so the visible head keeps
/// near-square proportions and the glyph matches the wide-but-compact aspect
/// of a real cluster indicator.
Size blinkerMarkBox(BlinkerShape shape, double diameter) {
  switch (shape) {
    case BlinkerShape.dots:
      return Size(diameter, diameter);
    case BlinkerShape.arrows:
      return Size(diameter * 1.6 * kBlinkerArrowHorizontalScale, diameter);
    case BlinkerShape.smiley:
      return Size(diameter, diameter);
  }
}

/// Fraction of the arrow box width taken by the triangular head; the rest is
/// the stem. Head-dominant, like the ISO 2575 cluster glyph.
const double kBlinkerArrowHeadWidthFrac = 0.55;

/// Stem thickness as a fraction of the arrow box height. Bold on purpose:
/// at the default mark size (box 20.16×18 px) the stem is 9 px thick — far
/// above the ~2 px floor where detail mushes on the emissive projector.
const double kBlinkerArrowStemHeightFrac = 0.5;

/// Builds the filled turn-signal arrow path for a mark of [size], pointing
/// left ([isLeft] = true) or right ([isLeft] = false).
///
/// Shape: the standard car-cluster indicator glyph (ISO 2575 idiom) — a
/// solid triangular head with a short, bold rectangular stem. The head spans
/// the box's full height from the outward tip back to
/// [kBlinkerArrowHeadWidthFrac] of the width; the stem is a centred bar
/// [kBlinkerArrowStemHeightFrac] of the height running to the inward edge.
///
/// History, so this does not oscillate again:
/// 1. A phase0 SVG pentagon (outline filled verbatim, with a ~sub-2px notch)
///    was rejected — the notch mushed to nothing on the emissive projector
///    and the filled tail dominated ("luggage tag").
/// 2. The replacement plain tailless triangle fixed the mush but read as an
///    abstract wedge, not a car indicator (Maxim, 2026-11-20: "awkward").
/// This glyph is neither: it has the stem a real indicator needs, and every
/// feature (stem 0.5·h thick, head 0.55·w long) is far above the fine-detail
/// floor at the default 18 px mark size. Described directly in the box's own
/// coordinate space — no authoring viewport, no distortion at any size.
Path blinkerArrowPath(Size size, {required bool isLeft}) {
  final w = size.width;
  final h = size.height;
  final headW = w * kBlinkerArrowHeadWidthFrac;
  final stemTop = h * (0.5 - kBlinkerArrowStemHeightFrac / 2);
  final stemBottom = h * (0.5 + kBlinkerArrowStemHeightFrac / 2);
  final path = Path();
  if (isLeft) {
    // Tip at the left (outward) edge; stem runs to the right (inward) edge.
    path.moveTo(0, h / 2);
    path.lineTo(headW, 0);
    path.lineTo(headW, stemTop);
    path.lineTo(w, stemTop);
    path.lineTo(w, stemBottom);
    path.lineTo(headW, stemBottom);
    path.lineTo(headW, h);
  } else {
    // Mirror: tip at the right (outward) edge; stem runs to the left.
    path.moveTo(w, h / 2);
    path.lineTo(w - headW, 0);
    path.lineTo(w - headW, stemTop);
    path.lineTo(0, stemTop);
    path.lineTo(0, stemBottom);
    path.lineTo(w - headW, stemBottom);
    path.lineTo(w - headW, h);
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
  final bias = slotW * config.horizBiasFrac;
  final leftPad = (slotW * config.sidePadFrac + bias).clamp(0.0, slotW);
  final rightPad = (slotW * config.sidePadFrac - bias).clamp(0.0, slotW);

  final showLeft = state == BlinkerState.left || state == BlinkerState.hazard;
  final showRight = state == BlinkerState.right || state == BlinkerState.hazard;

  return (
    left: showLeft ? Rect.fromLTWH(leftPad, top, box.width, box.height) : null,
    right: showRight
        ? Rect.fromLTWH(slotW - rightPad - box.width, top, box.width, box.height)
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
