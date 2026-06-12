// Tests for Block 0025 — minimap Safe-Area confinement (phase0 square geometry).
//
// Verifies that computeMinimapViewport() faithfully replicates phase0's
// IAppHostStub.computeViewportRect() model:
//   • Square side = safeH × sizeFraction
//   • Vertically centred on the Safe Area
//   • SQUARE_LEFT placement: safeLeft + paddingDp
//   • Clamped to display bounds
//   • Presets map to expected sizeFractions

import 'package:flutter_test/flutter_test.dart';

import 'package:zee_power_toys/services/minimap_viewport.dart';

void main() {
  // T2 emulator: 1280 × 720 @ 213 dpi  (density = 1.33125)
  const t2W   = 1280.0;
  const t2H   =  720.0;
  const t2Dpi = 213.0;

  // T3 (Zeekr S2 nominal): 1024 × 576 @ 213 dpi
  const t3W   = 1024.0;
  const t3H   =  576.0;
  const t3Dpi = 213.0;

  group('computeMinimapViewport — T2 emulator (1280×720 @ 213 dpi)', () {
    test('balanced preset produces a square', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      expect(r.width, closeTo(r.height, 0.5),
          reason: 'viewport must be a square (w ≈ h)');
    });

    test('balanced preset side ≈ 210 px (safeH*0.9)', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      // safeH = 175 × 1.33125 ≈ 233 px; side = 233 × 0.9 ≈ 209.7 → 210 px
      expect(r.width, closeTo(210.0, 1.0),
          reason: 'side should be safeH × 0.9 ≈ 210 px');
    });

    test('balanced preset left edge inside Safe Area', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      // safeLeft ≈ 237 px; paddingPx ≈ 41 px → square left ≈ 278 px
      final density = t2Dpi / 160.0;
      final safeLeft = t2W / 2 + hudSafeAreaOffsetXDp * density
          - (hudSafeAreaWidthDp * density) / 2;
      expect(r.left, greaterThan(safeLeft),
          reason: 'minimap left must be inside Safe Area (safeLeft + padding)');
    });

    test('balanced preset fits inside Safe Area vertically', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      final density = t2Dpi / 160.0;
      final safeCenterY = t2H / 2 + hudSafeAreaOffsetYDp * density;
      final safeH = hudSafeAreaHeightDp * density;
      final safeTop    = safeCenterY - safeH / 2;
      final safeBottom = safeCenterY + safeH / 2;
      expect(r.top,    greaterThanOrEqualTo(safeTop - 1),
          reason: 'minimap top must be inside (or at) Safe Area top');
      expect(r.bottom, lessThanOrEqualTo(safeBottom + 1),
          reason: 'minimap bottom must be inside (or at) Safe Area bottom');
    });

    test('balanced preset is centred vertically on Safe Area', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      final density = t2Dpi / 160.0;
      final safeCenterY = t2H / 2 + hudSafeAreaOffsetYDp * density;
      final squareCenterY = (r.top + r.bottom) / 2;
      expect(squareCenterY, closeTo(safeCenterY, 1.0),
          reason: 'minimap must be vertically centred on the Safe Area');
    });

    test('result is clamped to display bounds', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top,  greaterThanOrEqualTo(0));
      expect(r.right,  lessThanOrEqualTo(t2W));
      expect(r.bottom, lessThanOrEqualTo(t2H));
    });

    test('no collision with battery region (right side of Safe Area)', () {
      final r = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      // Battery is positioned at ~right 12 % of Safe Area width.
      // Safe Area right ≈ 1057 px; battery left > 900 px.
      // Minimap right ≈ 488 px → well clear.
      const batteryApproxLeft = 900.0;
      expect(r.right, lessThan(batteryApproxLeft),
          reason: 'minimap must not overlap battery (right side of Safe Area)');
    });

    test('compact preset produces smaller side than balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      final compact = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'compact',
      );
      expect(compact.width, lessThan(balanced.width),
          reason: 'compact must be smaller than balanced');
    });

    test('large preset produces larger side than balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      final large = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'large',
      );
      expect(large.width, greaterThan(balanced.width),
          reason: 'large must be bigger than balanced');
    });

    test('unknown preset falls back to balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'balanced',
      );
      final unknown = computeMinimapViewport(
        displayW: t2W, displayH: t2H, dpi: t2Dpi, preset: 'xyzzy',
      );
      expect(unknown, equals(balanced));
    });
  });

  group('computeMinimapViewport — T3 nominal (1024×576 @ 213 dpi)', () {
    test('balanced preset produces a square', () {
      final r = computeMinimapViewport(
        displayW: t3W, displayH: t3H, dpi: t3Dpi, preset: 'balanced',
      );
      expect(r.width, closeTo(r.height, 0.5));
    });

    test('result is clamped to display bounds', () {
      final r = computeMinimapViewport(
        displayW: t3W, displayH: t3H, dpi: t3Dpi, preset: 'balanced',
      );
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top,  greaterThanOrEqualTo(0));
      expect(r.right,  lessThanOrEqualTo(t3W));
      expect(r.bottom, lessThanOrEqualTo(t3H));
    });
  });

  group('hudPresetSizeFraction', () {
    test('balanced → 0.9', () => expect(hudPresetSizeFraction('balanced'), 0.9));
    test('compact  → 0.75', () => expect(hudPresetSizeFraction('compact'),  0.75));
    test('large    → 1.0', () => expect(hudPresetSizeFraction('large'),    1.0));
    test('unknown  → 0.9 (balanced fallback)',
        () => expect(hudPresetSizeFraction('other'), 0.9));
  });

  group('computeHudSafeAreaFracs — T2 (1280×720 @ 213 dpi)', () {
    test('fracs are within 0..1', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W, displayH: t2H, dpi: t2Dpi,
      );
      expect(f.left,   inInclusiveRange(0.0, 1.0));
      expect(f.top,    inInclusiveRange(0.0, 1.0));
      expect(f.right,  inInclusiveRange(0.0, 1.0));
      expect(f.bottom, inInclusiveRange(0.0, 1.0));
    });

    test('right > left, bottom > top', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W, displayH: t2H, dpi: t2Dpi,
      );
      expect(f.right,  greaterThan(f.left));
      expect(f.bottom, greaterThan(f.top));
    });

    test('Safe Area ≈ 820 × 233 px → fracs match', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W, displayH: t2H, dpi: t2Dpi,
      );
      // safeW = 820 px / 1280 px ≈ 0.641
      final safeWidthFrac = (f.right - f.left);
      expect(safeWidthFrac, closeTo(820.0 / 1280.0, 0.005));
      // safeH = 233 px / 720 px ≈ 0.323
      final safeHeightFrac = (f.bottom - f.top);
      expect(safeHeightFrac, closeTo(233.0 / 720.0, 0.005));
    });
  });
}
