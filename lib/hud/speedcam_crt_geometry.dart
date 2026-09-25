import 'dart:math' as math;

/// 0083 / 0080 — one CRT plate for HUD Presentation, DHU Radar preview, and
/// system Overlay. Landscape 300×220 (aspect > 1), never square.
const double kSpeedcamCrtPlateW = 300.0;
const double kSpeedcamCrtPlateH = 220.0;
const double kSpeedcamCrtPlateAspect = kSpeedcamCrtPlateW / kSpeedcamCrtPlateH;

/// Fit a landscape CRT plate into [maxW]×[maxH] without changing aspect.
({double width, double height}) speedcamCrtPlateSize({
  required double maxW,
  required double maxH,
}) {
  assert(maxW > 0 && maxH > 0);
  var w = maxW;
  var h = w / kSpeedcamCrtPlateAspect;
  if (h > maxH) {
    h = maxH;
    w = h * kSpeedcamCrtPlateAspect;
  }
  return (width: w, height: h);
}

/// HUD slot: fraction of safe-area, still locked to [kSpeedcamCrtPlateAspect].
({double width, double height}) speedcamCrtHudSlotSize({
  required double safeWidth,
  required double safeHeight,
  double widthFrac = 0.28,
  double heightFrac = 0.42,
}) {
  final maxW = math.min(safeWidth * widthFrac, safeHeight * heightFrac * kSpeedcamCrtPlateAspect);
  return speedcamCrtPlateSize(maxW: maxW, maxH: maxW / kSpeedcamCrtPlateAspect);
}

/// Native overlay window size in px (mirrors Kotlin
/// `OVERLAY_WIDTH_DP * sizeScale * density` + landscape CRT aspect).
/// Base width 280dp; scale clamped to 0.6–1.6 (prefs / slider range).
({int width, int height}) speedcamOverlayWindowSizePx({
  required double sizeScale,
  required double density,
  double widthDp = 280,
}) {
  assert(density > 0);
  final scale = sizeScale.clamp(0.6, 1.6);
  final width = (widthDp * scale * density).round().clamp(1, 1 << 30);
  final height = (width / kSpeedcamCrtPlateAspect).round().clamp(1, 1 << 30);
  return (width: width, height: height);
}
