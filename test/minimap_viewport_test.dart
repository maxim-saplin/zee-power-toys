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
  const t2W = 1280.0;
  const t2H = 720.0;
  const t2Dpi = 213.0;

  // T3 (Zeekr S2 nominal): 1024 × 576 @ 213 dpi
  const t3W = 1024.0;
  const t3H = 576.0;
  const t3Dpi = 213.0;

  group('computeMinimapViewport — T2 emulator (1280×720 @ 213 dpi)', () {
    test('balanced preset produces a square', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      expect(
        r.width,
        closeTo(r.height, 0.5),
        reason: 'viewport must be a square (w ≈ h)',
      );
    });

    test('balanced preset side ≈ 210 px (safeH*0.9)', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      // safeH = 175 × 1.33125 ≈ 233 px; side = 233 × 0.9 ≈ 209.7 → 210 px
      expect(
        r.width,
        closeTo(210.0, 1.0),
        reason: 'side should be safeH × 0.9 ≈ 210 px',
      );
    });

    test('balanced preset left edge inside Safe Area', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      // safeLeft ≈ 237 px; paddingPx ≈ 41 px → square left ≈ 278 px
      final density = t2Dpi / 160.0;
      final safeLeft =
          t2W / 2 +
          hudSafeAreaOffsetXDp * density -
          (hudSafeAreaWidthDp * density) / 2;
      expect(
        r.left,
        greaterThan(safeLeft),
        reason: 'minimap left must be inside Safe Area (safeLeft + padding)',
      );
    });

    test('balanced preset fits inside Safe Area vertically', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      final density = t2Dpi / 160.0;
      final safeCenterY = t2H / 2 + hudSafeAreaOffsetYDp * density;
      final safeH = hudSafeAreaHeightDp * density;
      final safeTop = safeCenterY - safeH / 2;
      final safeBottom = safeCenterY + safeH / 2;
      expect(
        r.top,
        greaterThanOrEqualTo(safeTop - 1),
        reason: 'minimap top must be inside (or at) Safe Area top',
      );
      expect(
        r.bottom,
        lessThanOrEqualTo(safeBottom + 1),
        reason: 'minimap bottom must be inside (or at) Safe Area bottom',
      );
    });

    test('balanced preset is centred vertically on Safe Area', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      final density = t2Dpi / 160.0;
      final safeCenterY = t2H / 2 + hudSafeAreaOffsetYDp * density;
      final squareCenterY = (r.top + r.bottom) / 2;
      expect(
        squareCenterY,
        closeTo(safeCenterY, 1.0),
        reason: 'minimap must be vertically centred on the Safe Area',
      );
    });

    test('result is clamped to display bounds', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(t2W));
      expect(r.bottom, lessThanOrEqualTo(t2H));
    });

    test('no collision with battery region (right side of Safe Area)', () {
      final r = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      // Battery is positioned at ~right 12 % of Safe Area width.
      // Safe Area right ≈ 1057 px; battery left > 900 px.
      // Minimap right ≈ 488 px → well clear.
      const batteryApproxLeft = 900.0;
      expect(
        r.right,
        lessThan(batteryApproxLeft),
        reason: 'minimap must not overlap battery (right side of Safe Area)',
      );
    });

    test('compact preset produces smaller side than balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      final compact = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'compact',
      );
      expect(
        compact.width,
        lessThan(balanced.width),
        reason: 'compact must be smaller than balanced',
      );
    });

    test('large preset produces larger side than balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      final large = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'large',
      );
      expect(
        large.width,
        greaterThan(balanced.width),
        reason: 'large must be bigger than balanced',
      );
    });

    test('unknown preset falls back to balanced', () {
      final balanced = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'balanced',
      );
      final unknown = computeMinimapViewport(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
        preset: 'xyzzy',
      );
      expect(unknown, equals(balanced));
    });
  });

  group('computeMinimapViewport — T3 nominal (1024×576 @ 213 dpi)', () {
    test('balanced preset produces a square', () {
      final r = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
      );
      expect(r.width, closeTo(r.height, 0.5));
    });

    test('result is clamped to display bounds', () {
      final r = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
      );
      expect(r.left, greaterThanOrEqualTo(0));
      expect(r.top, greaterThanOrEqualTo(0));
      expect(r.right, lessThanOrEqualTo(t3W));
      expect(r.bottom, lessThanOrEqualTo(t3H));
    });

    test('balanced preset matches the runtime-confirmed rect exactly '
        '(Rect.fromLTWH(150, 191, 210, 210))', () {
      // Verified live via ext.zee.readViewModel on the real 1024×576 @ 213dpi
      // HUD geometry (both the T2 emulator and the T3 car — CONTEXT.md's
      // Minimap glossary entry). Independently re-derivable: density =
      // 213/160 = 1.33125; Safe Area 616×175dp → 820×233px; centred with the
      // +5/+6dp offset → left ≈ 108.6; square side = 0.9 × 233 = 210;
      // x = 108.6 + 31 × 1.33125 ≈ 150.
      final r = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
      );
      expect(
        r.left,
        closeTo(150.0, 1.0),
        reason: 'left should be safeLeft + paddingDp*density ≈ 150px',
      );
      expect(
        r.top,
        closeTo(191.0, 1.0),
        reason: 'top should centre the 210px square on the Safe Area ≈ 191px',
      );
      expect(
        r.width,
        closeTo(210.0, 1.0),
        reason: 'side should be safeH × 0.9 ≈ 210px',
      );
      expect(
        r.height,
        closeTo(210.0, 1.0),
        reason: 'square: height should equal width ≈ 210px',
      );
    });
  });

  group('computeMinimapViewport — sizeFraction override (Task 2 Size slider)', () {
    // These verify the continuous Size slider (MinimapConfig.sizeFraction,
    // resolved via resolvedSizeFraction) genuinely changes the rendered rect
    // — the whole point of replacing the dead widthFrac/heightFrac sliders,
    // which computeMinimapViewport never consumed at all.
    test('explicit sizeFraction overrides the preset-derived fraction', () {
      final overridden = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
        sizeFraction: 0.5,
      );
      final presetOnly = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
      );
      expect(
        overridden.width,
        lessThan(presetOnly.width),
        reason:
            'sizeFraction=0.5 must produce a smaller square than the '
            "balanced preset's own fraction (0.9)",
      );
    });

    test('larger sizeFraction produces a monotonically larger square', () {
      final small = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
        sizeFraction: 0.3,
      );
      final mid = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
        sizeFraction: 0.6,
      );
      final large = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
        sizeFraction: 0.9,
      );
      expect(
        mid.width,
        greaterThan(small.width),
        reason: 'sizeFraction=0.6 must render bigger than sizeFraction=0.3',
      );
      expect(
        large.width,
        greaterThan(mid.width),
        reason: 'sizeFraction=0.9 must render bigger than sizeFraction=0.6',
      );
    });

    test(
      'sizeFraction=1.0 matches the large preset (both resolve to fraction 1.0)',
      () {
        final overridden = computeMinimapViewport(
          displayW: t3W,
          displayH: t3H,
          dpi: t3Dpi,
          preset: 'balanced',
          sizeFraction: 1.0,
        );
        final largePreset = computeMinimapViewport(
          displayW: t3W,
          displayH: t3H,
          dpi: t3Dpi,
          preset: 'large',
        );
        expect(
          overridden.width,
          closeTo(largePreset.width, 0.5),
          reason:
              'an explicit sizeFraction of 1.0 must render identically '
              'to the large preset, whose own fraction is also 1.0',
        );
      },
    );

    test('overridden rect remains a square', () {
      final r = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
        sizeFraction: 0.45,
      );
      expect(
        r.width,
        closeTo(r.height, 0.5),
        reason: 'a manual sizeFraction override must still yield a square',
      );
    });

    test(
      'null sizeFraction (the default) falls back to hudPresetSizeFraction(preset), unchanged from before this override existed',
      () {
        final withNull = computeMinimapViewport(
          displayW: t3W,
          displayH: t3H,
          dpi: t3Dpi,
          preset: 'compact',
        );
        final withExplicitEquivalent = computeMinimapViewport(
          displayW: t3W,
          displayH: t3H,
          dpi: t3Dpi,
          preset: 'compact',
          sizeFraction: hudPresetSizeFraction('compact'),
        );
        expect(
          withNull,
          equals(withExplicitEquivalent),
          reason:
              'omitting sizeFraction must be identical to passing the '
              "preset's own fraction explicitly — back-compat for every "
              'existing caller (hud_root.dart, other tests) that never '
              'passes sizeFraction',
        );
      },
    );
  });

  group('minimapRectInSafeArea', () {
    test(
      'produces a square (fractions scale to equal px given a square Safe Area proxy)',
      () {
        // Fractions alone aren't square unless width==height; the test that
        // matters is the reconstructed-pixel comparison below. Here we just
        // check the side is nonzero along both axes.
        final r = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
        expect(
          r.width,
          greaterThan(0),
          reason: 'width fraction must be positive',
        );
        expect(
          r.height,
          greaterThan(0),
          reason: 'height fraction must be positive',
        );
      },
    );

    test(
      'left fraction reflects paddingDp inset from the Safe Area left edge',
      () {
        final r = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
        final density = t3Dpi / 160.0;
        final expectedLeftFrac =
            (hudSquarePaddingDp * density) / (hudSafeAreaWidthDp * density);
        expect(
          r.left,
          closeTo(expectedLeftFrac, 0.001),
          reason:
              'left fraction should be paddingPx / safeWidthPx (SQUARE_LEFT placement)',
        );
      },
    );

    test('vertically centred: top + height/2 ≈ 0.5', () {
      final r = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
      expect(
        r.top + r.height / 2,
        closeTo(0.5, 0.005),
        reason: 'square must be vertically centred on the Safe Area',
      );
    });

    test('compact preset produces smaller side fraction than balanced', () {
      final balanced = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
      final compact = minimapRectInSafeArea(dpi: t3Dpi, preset: 'compact');
      expect(
        compact.height,
        lessThan(balanced.height),
        reason: 'compact preset must be smaller than balanced',
      );
    });

    test('large preset produces bigger side fraction than balanced', () {
      final balanced = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
      final large = minimapRectInSafeArea(dpi: t3Dpi, preset: 'large');
      expect(
        large.height,
        greaterThan(balanced.height),
        reason: 'large preset must be bigger than balanced',
      );
    });

    test('unknown preset falls back to balanced', () {
      final balanced = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
      final unknown = minimapRectInSafeArea(dpi: t3Dpi, preset: 'xyzzy');
      expect(unknown, equals(balanced));
    });

    test('reconstructed onto the T3 Safe Area matches computeMinimapViewport '
        '(the two functions must never drift apart)', () {
      // computeMinimapViewport works in absolute display-pixel coordinates;
      // minimapRectInSafeArea works in Safe-Area-local fractions. Reconstruct
      // an absolute rect from the fractional one (by scaling onto the Safe
      // Area's own pixel rect, computed independently via
      // computeHudSafeAreaFracs) and confirm it lands on the same square
      // computeMinimapViewport reports directly.
      final abs = computeMinimapViewport(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
        preset: 'balanced',
      );
      final saFracs = computeHudSafeAreaFracs(
        displayW: t3W,
        displayH: t3H,
        dpi: t3Dpi,
      );
      final saLeftPx = saFracs.left * t3W;
      final saTopPx = saFracs.top * t3H;
      final saWidthPx = (saFracs.right - saFracs.left) * t3W;
      final saHeightPx = (saFracs.bottom - saFracs.top) * t3H;

      final rel = minimapRectInSafeArea(dpi: t3Dpi, preset: 'balanced');
      final reconstructedLeft = saLeftPx + rel.left * saWidthPx;
      final reconstructedTop = saTopPx + rel.top * saHeightPx;
      final reconstructedWidth = rel.width * saWidthPx;
      final reconstructedHeight = rel.height * saHeightPx;

      expect(
        reconstructedLeft,
        closeTo(abs.left, 1.0),
        reason:
            'reconstructed left must match computeMinimapViewport (T3 verified rect)',
      );
      expect(
        reconstructedTop,
        closeTo(abs.top, 1.0),
        reason:
            'reconstructed top must match computeMinimapViewport (T3 verified rect)',
      );
      expect(
        reconstructedWidth,
        closeTo(abs.width, 1.0),
        reason:
            'reconstructed width must match computeMinimapViewport (T3 verified rect)',
      );
      expect(
        reconstructedHeight,
        closeTo(abs.height, 1.0),
        reason:
            'reconstructed height must match computeMinimapViewport (T3 verified rect)',
      );
    });
  });

  group('hudPresetSizeFraction', () {
    test(
      'balanced → 0.9',
      () => expect(hudPresetSizeFraction('balanced'), 0.9),
    );
    test(
      'compact  → 0.75',
      () => expect(hudPresetSizeFraction('compact'), 0.75),
    );
    test('large    → 1.0', () => expect(hudPresetSizeFraction('large'), 1.0));
    test(
      'unknown  → 0.9 (balanced fallback)',
      () => expect(hudPresetSizeFraction('other'), 0.9),
    );
  });

  group('computeHudSafeAreaFracs — T2 (1280×720 @ 213 dpi)', () {
    test('fracs are within 0..1', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
      );
      expect(f.left, inInclusiveRange(0.0, 1.0));
      expect(f.top, inInclusiveRange(0.0, 1.0));
      expect(f.right, inInclusiveRange(0.0, 1.0));
      expect(f.bottom, inInclusiveRange(0.0, 1.0));
    });

    test('right > left, bottom > top', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
      );
      expect(f.right, greaterThan(f.left));
      expect(f.bottom, greaterThan(f.top));
    });

    test('Safe Area ≈ 820 × 233 px → fracs match', () {
      final f = computeHudSafeAreaFracs(
        displayW: t2W,
        displayH: t2H,
        dpi: t2Dpi,
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
