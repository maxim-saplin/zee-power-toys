// Temp shares a row with the % text when charge is text ("Just text" look);
// with a pack icon the temp keeps its own row.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/hud_root.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  Future<({Rect? pct, Rect temp, Rect? icon})> pump(
    WidgetTester tester,
    BatteryLook look,
    BatteryPlacement placement,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1024, 576));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final signals = FakeCarSignals();
    await tester.pumpWidget(
      wrapWithProviders(
        const HudRoot(),
        signals: signals,
        config: AppConfig(
          battery: BatteryConfig()
              .withPlacement(placement)
              .copyWith(look: look),
        ),
      ),
    );
    signals.emitBattery(levelPct: 72, tempC: 31.0);
    await tester.pump();
    Rect? rectOf(String key) {
      final f = find.byKey(ValueKey(key));
      return f.evaluate().isEmpty ? null : tester.getRect(f);
    }

    return (
      pct: rectOf('battery-pct-text'),
      temp: rectOf('battery-temp-text')!,
      icon: rectOf('battery-icon'),
    );
  }

  for (final placement in BatteryPlacement.values) {
    testWidgets('Just text: % and temp share one row (${placement.name})', (
      tester,
    ) async {
      final r = await pump(tester, BatteryLook.justText, placement);
      final pct = r.pct!;
      expect(r.icon, isNull);
      expect(
        (pct.center.dy - r.temp.center.dy).abs(),
        lessThan(3),
        reason: 'temp should sit on the % row',
      );
      expect(r.temp.left, greaterThanOrEqualTo(pct.right));
    });
  }

  for (final look in <BatteryLook>[
    BatteryLook.battery,
    BatteryLook.batteryText,
    BatteryLook.batteryBars,
  ]) {
    testWidgets('${look.name}: temp keeps its own row below the icon', (
      tester,
    ) async {
      final r = await pump(tester, look, BatteryPlacement.rightBottom);
      expect(r.icon, isNotNull);
      expect(r.temp.top, greaterThanOrEqualTo(r.icon!.bottom));
    });
  }
}
