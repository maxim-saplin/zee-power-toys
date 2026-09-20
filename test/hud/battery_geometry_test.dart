// Tests for lib/hud/battery_geometry.dart — BATTERY cluster placement (0051).
//
// Relationship assertions on pure rect math: default rightTop matches today's
// hard-coded top-right; left mirrors; fine adjust (vert / sidePad / bias)
// moves the slot. Temp + charging ride inside BatteryWidget, so they move
// with the cluster without separate placement.

import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/battery_geometry.dart';
import 'package:zee_power_toys/services/config_store.dart';

void main() {
  const saW = 1000.0;
  const saH = 500.0;

  group('batteryClusterRect — default rightTop = prior hard-coded look', () {
    test('rightTop defaults place slot at right 4% inset, top 1%', () {
      final defaults = batteryPlacementDefaults(BatteryPlacement.rightTop);
      final rect = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.rightTop,
        vertFrac: defaults.vertFrac,
        sidePadFrac: defaults.sidePadFrac,
      );
      // Prior hard-code: right = 0.04*w, top = 0.01*h, w = 0.12*w, h = 0.6*h
      expect(rect.right, closeTo(saW - saW * 0.04, 0.01));
      expect(rect.top, closeTo(saH * 0.010, 0.01));
      expect(rect.width, closeTo(saW * 0.12, 0.01));
      expect(rect.height, closeTo(saH * 0.6, 0.01));
      expect(batteryPlacementIsLeft(BatteryPlacement.rightTop), isFalse);
    });

    test('BatteryConfig defaults match rightTop geometry', () {
      const cfg = BatteryConfig();
      expect(cfg.placement, BatteryPlacement.rightTop);
      expect(cfg.vertFrac, 0.010);
      expect(cfg.sidePadFrac, 0.04);
      expect(cfg.horizBiasFrac, 0.0);
      final rect = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: cfg.placement,
        vertFrac: cfg.vertFrac,
        sidePadFrac: cfg.sidePadFrac,
        horizBiasFrac: cfg.horizBiasFrac,
      );
      expect(rect.left, closeTo(saW - saW * 0.04 - saW * 0.12, 0.01));
    });
  });

  group('batteryClusterRect — left / right presets', () {
    test('left anchors on the left edge with matching inset', () {
      final defaults = batteryPlacementDefaults(BatteryPlacement.left);
      final rect = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.left,
        vertFrac: defaults.vertFrac,
        sidePadFrac: defaults.sidePadFrac,
      );
      expect(batteryPlacementIsLeft(BatteryPlacement.left), isTrue);
      expect(rect.left, closeTo(saW * 0.04, 0.01));
      expect(rect.top, closeTo(saH * 0.010, 0.01));
    });

    test('right is mid-upper on the right (below rightTop)', () {
      final top = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.rightTop,
        vertFrac: batteryPlacementDefaults(BatteryPlacement.rightTop).vertFrac,
        sidePadFrac: 0.04,
      );
      final mid = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.right,
        vertFrac: batteryPlacementDefaults(BatteryPlacement.right).vertFrac,
        sidePadFrac: 0.04,
      );
      expect(mid.top, greaterThan(top.top));
      expect(mid.right, closeTo(top.right, 0.01));
    });

    test('withPlacement resets fine adjust to preset defaults', () {
      final cfg = const BatteryConfig()
          .copyWith(vertFrac: 0.5, sidePadFrac: 0.2, horizBiasFrac: 0.1)
          .withPlacement(BatteryPlacement.left);
      expect(cfg.placement, BatteryPlacement.left);
      expect(cfg.vertFrac, 0.010);
      expect(cfg.sidePadFrac, 0.04);
      expect(cfg.horizBiasFrac, 0.0);
    });
  });

  group('batteryClusterRect — fine adjust', () {
    test('vertFrac moves the slot down', () {
      final a = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.rightTop,
        vertFrac: 0.0,
        sidePadFrac: 0.04,
      );
      final b = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.rightTop,
        vertFrac: 0.2,
        sidePadFrac: 0.04,
      );
      expect(b.top, closeTo(saH * 0.2, 0.01));
      expect(b.top, greaterThan(a.top));
    });

    test('positive horizBiasFrac shifts toward the right', () {
      final base = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.left,
        vertFrac: 0.01,
        sidePadFrac: 0.04,
        horizBiasFrac: 0.0,
      );
      final biased = batteryClusterRect(
        saW: saW,
        saH: saH,
        placement: BatteryPlacement.left,
        vertFrac: 0.01,
        sidePadFrac: 0.04,
        horizBiasFrac: 0.05,
      );
      expect(biased.left, greaterThan(base.left));
    });

    test('JSON round-trip keeps placement fields', () {
      const cfg = BatteryConfig(
        placement: BatteryPlacement.left,
        vertFrac: 0.2,
        sidePadFrac: 0.08,
        horizBiasFrac: -0.05,
      );
      expect(BatteryConfig.fromJson(cfg.toJson()), equals(cfg));
    });
  });
}
