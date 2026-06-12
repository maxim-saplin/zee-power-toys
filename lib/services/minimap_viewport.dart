import 'dart:ui' show Rect;

// ---------------------------------------------------------------------------
// Phase-0 HUD minimap viewport geometry — Block 0025.
//
// Ports IAppHostStub.computeViewportRect() from phase0 faithfully.
// Source of truth: docs/knowledge/hud-presentation-host.md §4 + §5.
// ---------------------------------------------------------------------------

/// HUD optical Safe Area constants — hand-calibrated on Zeekr S2.
/// Source: IAppHostStub.kt L208-211, hud-presentation-host.md §4.
const double hudSafeAreaWidthDp = 616.0;
const double hudSafeAreaHeightDp = 175.0;
/// Safe-area centre offset rightward from display centre.
const double hudSafeAreaOffsetXDp = 5.0;
/// Safe-area centre offset downward from display centre.
const double hudSafeAreaOffsetYDp = 6.0;

/// Default padding from safe-area left/right edge to the minimap square edge (~5 % of safe width).
/// Source: HudSettings.kt squarePaddingDp default.
const double hudSquarePaddingDp = 31.0;

/// Default square-size fraction: side = safeH × fraction.
/// Source: HudSettings.kt squareSizeFraction default.
const double hudSquareSizeFractionDefault = 0.9;

/// Map a preset name to its squareSizeFraction (side = safeH × fraction).
///
/// - compact  : 0.75 — small readable square, more room for other content.
/// - balanced : 0.90 — phase0 default; excellent readability at 213 dpi.
/// - large    : 1.00 — square fills the full safe-area height.
double hudPresetSizeFraction(String preset) => switch (preset) {
  'compact' => 0.75,
  'large'   => 1.0,
  _          => hudSquareSizeFractionDefault,  // balanced (= phase0 default)
};

/// Compute the minimap viewport rect (SQUARE_LEFT) using phase0's model.
///
/// The viewport is a square vertically centred on the Safe Area, placed at
/// [safeLeft + squarePaddingDp] (SQUARE_LEFT mode).  This is the phase0 default
/// placement.  The square side is `safeH × sizeFraction`.
///
/// [displayW] and [displayH] — HUD display dimensions in physical pixels.
/// [dpi]     — HUD display density in dpi (e.g. 213 for Zeekr S2).
/// [preset]  — preset name: 'compact' | 'balanced' | 'large'.
///
/// Returns a Rect with integer-rounded pixel coordinates, clamped to display bounds.
///
/// Example (T2 emulator, 1280 × 720 @ 213 dpi, 'balanced'):
///   density = 1.33125; safeH ≈ 233 px; side ≈ 210 px
///   → Rect(278, 263, 488, 473)  — a 210 × 210 square on the left of the Safe Area.
Rect computeMinimapViewport({
  required double displayW,
  required double displayH,
  required double dpi,
  required String preset,
}) {
  final density = dpi / 160.0;
  final paddingPx = hudSquarePaddingDp * density;

  // Safe Area centre in pixels (with empirical offset from display centre)
  final safeCenterX = displayW / 2.0 + hudSafeAreaOffsetXDp * density;
  final safeCenterY = displayH / 2.0 + hudSafeAreaOffsetYDp * density;

  // Safe Area dimensions, clamped to display
  final safeW = (hudSafeAreaWidthDp * density).clamp(0.0, displayW);
  final safeH = (hudSafeAreaHeightDp * density).clamp(0.0, displayH);

  // Safe Area edges
  final safeLeft = (safeCenterX - safeW / 2.0).clamp(0.0, displayW - safeW);
  final safeRight = (safeLeft + safeW).clamp(0.0, displayW);

  // Square side: safeH × sizeFraction, clamped to available width minus 2× padding
  final sizeFraction = hudPresetSizeFraction(preset);
  final maxSide = (safeRight - safeLeft - 2.0 * paddingPx).clamp(1.0, safeH);
  final side = (safeH * sizeFraction).clamp(1.0, maxSide).roundToDouble();

  // SQUARE_LEFT: square at safeLeft + padding, vertically centred on Safe Area
  final top = (safeCenterY - side / 2.0).roundToDouble();
  final left = (safeLeft + paddingPx).roundToDouble();

  // Clamp to display bounds
  final clampedLeft = left.clamp(0.0, (displayW - side).clamp(0.0, displayW));
  final clampedTop = top.clamp(0.0, (displayH - side).clamp(0.0, displayH));

  return Rect.fromLTWH(clampedLeft, clampedTop, side, side);
}

/// Compute HudSafeArea fractions from phase0 dp constants × real display density.
///
/// Returns the left/top/right/bottom fractions (0..1 relative to display W/H)
/// for the Safe Area on a display of [displayW] × [displayH] at [dpi].
/// Use this to compute the correct fractions for the Flutter HUD overlay at runtime.
({double left, double top, double right, double bottom}) computeHudSafeAreaFracs({
  required double displayW,
  required double displayH,
  required double dpi,
}) {
  final density = dpi / 160.0;
  final safeCenterX = displayW / 2.0 + hudSafeAreaOffsetXDp * density;
  final safeCenterY = displayH / 2.0 + hudSafeAreaOffsetYDp * density;
  final safeW = (hudSafeAreaWidthDp * density).clamp(0.0, displayW);
  final safeH = (hudSafeAreaHeightDp * density).clamp(0.0, displayH);
  final safeLeft = (safeCenterX - safeW / 2.0).clamp(0.0, displayW - safeW);
  final safeTop  = (safeCenterY - safeH / 2.0).clamp(0.0, displayH - safeH);
  return (
    left:   safeLeft / displayW,
    top:    safeTop  / displayH,
    right:  (safeLeft + safeW) / displayW,
    bottom: (safeTop  + safeH) / displayH,
  );
}
