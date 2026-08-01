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
  'large' => 1.0,
  _ => hudSquareSizeFractionDefault, // balanced (= phase0 default)
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
/// [sizeFraction] — optional manual override of the square-size fraction
/// (side = safeH × sizeFraction); null (the default) derives the fraction
/// from [preset] via [hudPresetSizeFraction], preserving prior behaviour for
/// every existing caller. Pass a value here to genuinely change the
/// rendered rect independent of the named preset (the minimap settings
/// screen's continuous Size slider — `MinimapConfig.resolvedSizeFraction`).
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
  double? sizeFraction,
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
  final resolvedSizeFraction = sizeFraction ?? hudPresetSizeFraction(preset);
  final maxSide = (safeRight - safeLeft - 2.0 * paddingPx).clamp(1.0, safeH);
  final side = (safeH * resolvedSizeFraction)
      .clamp(1.0, maxSide)
      .roundToDouble();

  // SQUARE_LEFT: square at safeLeft + padding, vertically centred on Safe Area
  final top = (safeCenterY - side / 2.0).roundToDouble();
  final left = (safeLeft + paddingPx).roundToDouble();

  // Clamp to display bounds
  final clampedLeft = left.clamp(0.0, (displayW - side).clamp(0.0, displayW));
  final clampedTop = top.clamp(0.0, (displayH - side).clamp(0.0, displayH));

  return Rect.fromLTWH(clampedLeft, clampedTop, side, side);
}

/// Compute the minimap viewport rect **relative to the Safe Area itself**,
/// as fractions (0..1) of the Safe Area's own width/height.
///
/// [computeMinimapViewport] needs the full backing-display dimensions and
/// the Safe Area's display-centre offset, because it places the square in
/// absolute display-pixel coordinates. But two Flutter-side callers only
/// ever know the Safe Area's own on-screen size (they lay out in Safe-Area
/// fractions, not full-display pixels): [HudRoot]'s `_HudSlots` (the real
/// minimap-slot placeholder glyph) and [HudPreview] (the DHU preview's
/// schematic glyph). This function gives them the same phase0 placement
/// model — SQUARE_LEFT, vertically centred, side = safeH × sizeFraction —
/// without needing the display's full size or its Safe-Area offset, both of
/// which are irrelevant once you're already working in Safe-Area-local
/// coordinates.
///
/// Reuses [hudSquarePaddingDp] and [hudPresetSizeFraction] — the same
/// constants [computeMinimapViewport] uses — so the two functions cannot
/// drift apart on the underlying geometry, only on which coordinate space
/// they report it in. See `test/minimap_viewport_test.dart` for a
/// relationship test cross-checking the two against each other.
///
/// [dpi] — HUD display density in dpi (default 213, Zeekr S2).
/// [preset] — preset name: 'compact' | 'balanced' | 'large'.
///
/// Returns a [Rect] whose `left`/`top`/`width`/`height` are fractions to be
/// multiplied by the Safe Area's own on-screen width/height respectively —
/// NOT fractions of the full backing display.
/// [sizeFraction] overrides the preset-derived size when non-null — pass
/// `MinimapConfig.resolvedSizeFraction` so the preview glyph tracks the Size
/// slider, not just the preset shortcut. Mirrors [computeMinimapViewport]'s
/// own optional override so the schematic glyph and the real viewport are
/// driven by the same number.
Rect minimapRectInSafeArea({
  double dpi = 213.0,
  String preset = 'balanced',
  double? sizeFraction,
}) {
  final density = dpi / 160.0;
  final paddingPx = hudSquarePaddingDp * density;
  final safeWpx = hudSafeAreaWidthDp * density;
  final safeHpx = hudSafeAreaHeightDp * density;

  final resolvedFraction = sizeFraction ?? hudPresetSizeFraction(preset);
  final maxSide = (safeWpx - 2.0 * paddingPx).clamp(1.0, safeHpx);
  final side = (safeHpx * resolvedFraction).clamp(1.0, maxSide);

  // SQUARE_LEFT: padding in from the Safe Area's own left edge, vertically
  // centred on the Safe Area's own height.
  final leftPx = paddingPx;
  final topPx = (safeHpx - side) / 2.0;

  return Rect.fromLTWH(
    leftPx / safeWpx,
    topPx / safeHpx,
    side / safeWpx,
    side / safeHpx,
  );
}

/// Compute HudSafeArea fractions from phase0 dp constants × real display density.
///
/// Returns the left/top/right/bottom fractions (0..1 relative to display W/H)
/// for the Safe Area on a display of [displayW] × [displayH] at [dpi].
/// Use this to compute the correct fractions for the Flutter HUD overlay at runtime.
({double left, double top, double right, double bottom})
computeHudSafeAreaFracs({
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
  final safeTop = (safeCenterY - safeH / 2.0).clamp(0.0, displayH - safeH);
  return (
    left: safeLeft / displayW,
    top: safeTop / displayH,
    right: (safeLeft + safeW) / displayW,
    bottom: (safeTop + safeH) / displayH,
  );
}
