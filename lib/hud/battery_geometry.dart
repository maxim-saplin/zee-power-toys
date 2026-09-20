import 'dart:ui' show Rect;

import '../services/config_store.dart' show BatteryPlacement;

// ---------------------------------------------------------------------------
// Battery cluster geometry — pure functions for HudRoot placement.
//
// Mirrors blinker_geometry / minimap_viewport: sizing/placement math lives
// here so relationship tests can assert rects without pumping the widget tree.
// The BATTERY slot is a tall-narrow box; BatteryWidget fits its cluster
// (icon + % + temp + charging kW) inside it. Temp and charging move with
// the cluster because they are children of BatteryWidget, not separate slots.
// ---------------------------------------------------------------------------

/// Slot width as a fraction of Safe Area width (today's hard-coded 12%).
const double kBatterySlotWidthFrac = 0.12;

/// Slot height as a fraction of Safe Area height (today's hard-coded 60%).
const double kBatterySlotHeightFrac = 0.6;

/// Whether [placement] anchors the cluster on the left Safe-Area edge.
bool batteryPlacementIsLeft(BatteryPlacement placement) =>
    placement == BatteryPlacement.left;

/// Computes the on-screen rect for the BATTERY cluster slot inside a Safe
/// Area of size [saW] × [saH].
///
/// [vertFrac] is the top edge of the slot as a fraction of [saH] (0 = top).
/// [sidePadFrac] is the inward padding from the active edge (left for
/// [BatteryPlacement.left], right otherwise), as a fraction of [saW].
/// [horizBiasFrac] shifts both edges toward the right when positive (same
/// convention as [BlinkerConfig.horizBiasFrac]).
Rect batteryClusterRect({
  required double saW,
  required double saH,
  required BatteryPlacement placement,
  required double vertFrac,
  required double sidePadFrac,
  double horizBiasFrac = 0.0,
  double widthFrac = kBatterySlotWidthFrac,
  double heightFrac = kBatterySlotHeightFrac,
}) {
  if (saW <= 0 || saH <= 0) return Rect.zero;

  final w = (saW * widthFrac).clamp(0.0, saW);
  final top = (saH * vertFrac).clamp(0.0, saH);
  final h = (saH * heightFrac).clamp(0.0, saH - top);
  final isLeft = batteryPlacementIsLeft(placement);
  final bias = saW * horizBiasFrac;
  final pad = isLeft
      ? (saW * sidePadFrac + bias).clamp(0.0, saW)
      : (saW * sidePadFrac - bias).clamp(0.0, saW);
  final left = isLeft ? pad : (saW - pad - w).clamp(0.0, saW);
  return Rect.fromLTWH(left, top, w, h);
}

/// Horizontal stroke/pad used by the pack painter (squarish bold outline).
/// Kept here so the dual-color % clip (0062) shares the fill boundary with paint.
double batteryPackStrokeW(double bodyH) => bodyH * 0.14;

/// Inner padding from outline stroke to continuous-fill rect.
double batteryPackInnerPad(double bodyH) =>
    batteryPackStrokeW(bodyH) + bodyH * 0.08;

/// X of the continuous-fill right edge inside a pack of [bodyW]×[bodyH].
///
/// Matches `_BatteryPainter` continuous fill. Used to clip dual-color % text
/// (black on filled portion, white on empty) at the fill boundary.
double batteryPackFillEdgeX({
  required double bodyW,
  required double bodyH,
  required double fillFrac,
}) {
  final innerPad = batteryPackInnerPad(bodyH);
  final innerW = bodyW - innerPad * 2;
  if (innerW <= 0) return 0.0;
  final f = fillFrac.clamp(0.0, 1.0);
  return innerPad + innerW * f;
}

