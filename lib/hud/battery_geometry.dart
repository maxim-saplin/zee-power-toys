import 'dart:ui' show Rect;

import '../services/config_store.dart' show BatteryPlacement;

// ---------------------------------------------------------------------------
// Battery cluster geometry — pure functions for HudRoot placement.
//
// Mirrors blinker_geometry / minimap_viewport: sizing/placement math lives
// here so relationship tests can assert rects without pumping the widget tree.
// The BATTERY slot is a tall-narrow box; BatteryWidget fits its cluster
// (icon + % + temp + charging kW) inside it. While charging the slot grows
// (0067) so three lines stay readable. Temp and charging move with
// the cluster because they are children of BatteryWidget, not separate slots.
// ---------------------------------------------------------------------------

/// Slot width as a fraction of Safe Area width (today's hard-coded 12%).
const double kBatterySlotWidthFrac = 0.12;

/// Slot height as a fraction of Safe Area height (today's hard-coded 60%).
const double kBatterySlotHeightFrac = 0.6;

/// Taller slot while charging so bolt/kW + SoC + temp stay legible (0067).
/// Non-charging keeps [kBatterySlotHeightFrac]; FittedBox was crushing the
/// 3-line cluster into the 2-line box.
const double kBatterySlotHeightFracCharging = 0.82;

/// Slightly wider while charging so kW digits are not clipped.
const double kBatterySlotWidthFracCharging = 0.15;

/// Height/width fracs for the cluster given charging + [sizeScale].
///
/// 0067b: multiply baseline (and charging) fracs by [sizeScale] so the slot
/// grows with the slider. Without this, FittedBox(scaleDown) inside a fixed
/// slot reverses growth past ~1.5× (content bigger than box → crush).
({double widthFrac, double heightFrac}) batteryClusterSlotFracs({
  required bool chargingStatsVisible,
  double sizeScale = 1.0,
}) {
  final scale = sizeScale.clamp(0.5, 2.5);
  final baseW =
      chargingStatsVisible ? kBatterySlotWidthFracCharging : kBatterySlotWidthFrac;
  final baseH = chargingStatsVisible
      ? kBatterySlotHeightFracCharging
      : kBatterySlotHeightFrac;
  // Cap so we never overflow Safe Area (width ≤ 0.28, height ≤ 0.95).
  return (
    widthFrac: (baseW * scale).clamp(0.08, 0.28),
    heightFrac: (baseH * scale).clamp(0.35, 0.95),
  );
}

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

/// Outline stroke for the pack painter (squarish corners from 0056; stroke
/// toned down in 0063 — was bodyH*0.14). Shared with dual-color % clip (0062).
double batteryPackStrokeW(double bodyH) => bodyH * 0.08;

/// Inner padding from outline stroke to continuous-fill rect.
double batteryPackInnerPad(double bodyH) =>
    batteryPackStrokeW(bodyH) + bodyH * 0.08;

/// Height of the continuous-fill / inner pack area (0063: % glyph target).
double batteryPackInnerH(double bodyH) =>
    bodyH - batteryPackInnerPad(bodyH) * 2;

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

