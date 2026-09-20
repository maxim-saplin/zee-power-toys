import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';

import '../support/harness.dart';

void main() {
  setUp(useMockPrefs);

  // ---------------------------------------------------------------------------
  // BatteryConfig model
  // ---------------------------------------------------------------------------

  group('BatteryConfig model', () {
    test('defaults are all-on, sizeScale 1.0, batteryText look, rightTop', () {
      const cfg = BatteryConfig();
      expect(cfg.showBattery, isTrue);
      expect(cfg.showTemp, isTrue);
      expect(cfg.showChargingStats, isTrue);
      expect(cfg.sizeScale, 1.0);
      expect(cfg.look, BatteryLook.batteryText);
      expect(cfg.contentMode, BatteryContentMode.both);
      expect(cfg.style, BatteryStyle.outline);
      expect(cfg.placement, BatteryPlacement.rightTop);
      expect(cfg.vertFrac, 0.010);
      expect(cfg.sidePadFrac, 0.04);
      expect(cfg.horizBiasFrac, 0.0);
    });

    test('round-trips through JSON', () {
      const cfg = BatteryConfig(
        showBattery: false,
        showTemp: true,
        showChargingStats: false,
        sizeScale: 1.5,
        look: BatteryLook.batteryBars,
        contentMode: BatteryContentMode.iconOnly,
        style: BatteryStyle.filled,
      );
      final json = cfg.toJson();
      final cfg2 = BatteryConfig.fromJson(json);
      expect(cfg2, equals(cfg));
    });

    test('withLook syncs contentMode + style to PDM parts', () {
      const base = BatteryConfig();
      expect(base.withLook(BatteryLook.battery).contentMode,
          BatteryContentMode.iconOnly);
      expect(base.withLook(BatteryLook.battery).style, BatteryStyle.outline);
      expect(base.withLook(BatteryLook.batteryBars).style, BatteryStyle.filled);
      expect(base.withLook(BatteryLook.justText).contentMode,
          BatteryContentMode.textOnly);
    });

    test('legacy contentMode+style without look migrates to BatteryLook', () {
      final cfg = BatteryConfig.fromJson(<String, Object?>{
        'contentMode': 'iconOnly',
        'style': 'filled',
      });
      expect(cfg.look, BatteryLook.batteryBars);
      expect(cfg.contentMode, BatteryContentMode.iconOnly);
      expect(cfg.style, BatteryStyle.filled);
    });

    test('fromJson falls back to defaults for missing keys', () {
      final cfg = BatteryConfig.fromJson(<String, Object?>{});
      expect(cfg, equals(const BatteryConfig()));
    });

    test('copyWith only updates named fields', () {
      const cfg = BatteryConfig(sizeScale: 1.2);
      final cfg2 = cfg.copyWith(showBattery: false);
      expect(cfg2.showBattery, isFalse);
      expect(cfg2.showTemp, isTrue);
      expect(cfg2.showChargingStats, isTrue);
      expect(cfg2.sizeScale, 1.2);
    });

    test('equality and hashCode', () {
      const a = BatteryConfig(showBattery: true, sizeScale: 1.5);
      const b = BatteryConfig(showBattery: true, sizeScale: 1.5);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('JSON round-trip via jsonEncode/jsonDecode', () {
      const cfg = BatteryConfig(showTemp: false, sizeScale: 2.0);
      final encoded = jsonEncode(cfg.toJson());
      final decoded = BatteryConfig.fromJson(
        jsonDecode(encoded) as Map<String, Object?>,
      );
      expect(decoded, equals(cfg));
    });
  });

  // ---------------------------------------------------------------------------
  // AppConfig includes BatteryConfig
  // ---------------------------------------------------------------------------

  group('AppConfig includes BatteryConfig', () {
    test('toJson / fromJson round-trips battery config', () {
      const cfg = AppConfig(
        battery: BatteryConfig(showBattery: true, showTemp: false, sizeScale: 1.8),
      );
      final json = cfg.toJson();
      final cfg2 = AppConfig.fromJson(json);
      expect(cfg2.battery.showBattery, isTrue);
      expect(cfg2.battery.showTemp, isFalse);
      expect(cfg2.battery.sizeScale, 1.8);
    });

    test('fromJson with missing battery key uses defaults', () {
      final cfg = AppConfig.fromJson(<String, Object?>{});
      expect(cfg.battery, equals(const BatteryConfig()));
    });

    test('equality includes battery field', () {
      const a = AppConfig(battery: BatteryConfig(showTemp: false));
      const b = AppConfig(battery: BatteryConfig(showTemp: false));
      const c = AppConfig(battery: BatteryConfig(showTemp: true));
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });

  // ---------------------------------------------------------------------------
  // BatteryWidget — visibility and content
  // ---------------------------------------------------------------------------

  group('BatteryWidget', () {
    testWidgets('F2: idle (null pct/temp, not charging) renders nothing', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsNothing);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsNothing);
      expect(find.text('--%'), findsNothing);
      expect(find.text('--°C'), findsNothing);
    });

    testWidgets('F2: charging with null pct still shows chrome (bolt/kW)', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitCharge(charging: true, kw: 7.4);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('charging-stats')), findsOneWidget);
    });

    testWidgets('showBattery=false renders nothing', (tester) async {
      final config = AppConfig(
        battery: const BatteryConfig(showBattery: false),
      );
      await pumpHud(
        tester,
        wrapWithProviders(
          const SizedBox(width: 200, height: 200, child: BatteryWidget()),
          config: config,
          scaffold: true,
          localizations: false,
        ),
        size: const Size(200, 200),
      );

      // No icon, no pct text, no temp text.
      expect(find.byKey(const ValueKey('battery-icon')), findsNothing);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsNothing);
    });

    testWidgets('battery icon and pct text visible with default config',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 50, tempC: 25.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });

    // battery fill ∝ pct: test 0%, 50%, 100% all render the icon without crash.
    testWidgets('battery renders at pct=0', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 0, tempC: 20.0);
      await tester.pump();

      expect(find.text('0%'), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
    });

    testWidgets('battery renders at pct=50', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 50, tempC: 22.0);
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('battery renders at pct=100', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 100, tempC: 25.0);
      await tester.pump();

      expect(find.text('100%'), findsOneWidget);
    });

    // Temperature tests.
    testWidgets('temp shown when showTemp=true', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(showTemp: true),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 72, tempC: 24.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-temp-text')), findsOneWidget);
      expect(find.text('24°C'), findsOneWidget);
    });

    testWidgets('temp hidden when showTemp=false', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(showTemp: false),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 72, tempC: 24.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-temp-text')), findsNothing);
    });

    // Charging stats: visible IFF charging=true AND showChargingStats=true.
    testWidgets('charging stats visible when charging=true and showChargingStats=true',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(showChargingStats: true),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 300, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 50, tempC: 25.0);
      signals.emitCharge(charging: true, kw: 42.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('charging-stats')), findsOneWidget);
      expect(find.byKey(const ValueKey('charging-kw-text')), findsOneWidget);
      expect(find.text('42 kW'), findsOneWidget);
    });

    testWidgets('charging stats hidden when charging=false', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 300, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 50, tempC: 25.0);
      signals.emitCharge(charging: false);
      await tester.pump();

      expect(find.byKey(const ValueKey('charging-stats')), findsNothing);
      expect(find.byKey(const ValueKey('charging-kw-text')), findsNothing);
    });

    testWidgets(
        'charging stats hidden when charging=true but showChargingStats=false',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(showChargingStats: false),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 300, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 50, tempC: 25.0);
      signals.emitCharge(charging: true, kw: 50.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('charging-stats')), findsNothing);
    });

    testWidgets('charging stats disappear when charging transitions to false',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 300));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 300, child: BatteryWidget()),
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 72, tempC: 24.0);
      signals.emitCharge(charging: true, kw: 42.0);
      await tester.pump();
      await tester.pump();

      // Charging stats visible.
      expect(find.byKey(const ValueKey('charging-stats')), findsOneWidget);

      signals.emitCharge(charging: false);
      await tester.pump();
      await tester.pump();

      // Charging stats gone.
      expect(find.byKey(const ValueKey('charging-stats')), findsNothing);
    });
  });

    testWidgets('textOnly: no icon key, pct text present', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(contentMode: BatteryContentMode.textOnly),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 64, tempC: 22.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsNothing);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget);
      expect(find.text('64%'), findsOneWidget);
    });

    testWidgets('iconOnly + outline: icon present, no pct text', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(
          contentMode: BatteryContentMode.iconOnly,
          style: BatteryStyle.outline,
        ),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 55, tempC: 21.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsNothing);
      expect(find.byKey(const ValueKey('battery-inline-pct')), findsNothing);
      expect(find.text('55%'), findsNothing);
    });

    testWidgets('pctInside + both: inline ink, no duplicate pct below',
        (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(
          contentMode: BatteryContentMode.both,
          style: BatteryStyle.pctInside,
        ),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 88, tempC: 23.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-inline-pct')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsNothing);
      expect(find.text('88%'), findsOneWidget);
    });

    testWidgets('filled style still paints icon', (tester) async {
      final signals = FakeCarSignals();
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final config = AppConfig(
        battery: const BatteryConfig(style: BatteryStyle.filled),
      );
      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 40, tempC: 20.0);
      await tester.pump();

      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('battery-pct-text')), findsOneWidget);
    });

  // ---------------------------------------------------------------------------
  // Size-slider honesty (battery-widget-honest-range).
  //
  // The `battery-size` slider in hud_settings_screen.dart is labelled
  // 0.5×–2.5×. Before this Block, the whole panel (icon+pct in a Row, temp
  // and charging-stats below) was wide enough that its natural size already
  // exceeded the fixed BATTERY slot by sizeScale≈1.07 — so FittedBox's
  // scaleDown was silently absorbing roughly the top three-quarters of the
  // slider's labelled range: dragging the slider past its first quarter
  // produced almost no visible change. That FittedBox itself must stay (it's
  // the Block 0026 overflow fix — see the group below) — the real fix is
  // giving it less to compensate for, by laying the icon/pct/temp/kW content
  // out vertically (matching the slot's own tall-narrow aspect: ~12% of Safe
  // Area width, ~60% of its height — hud_root.dart:131,128) instead of
  // side-by-side.
  //
  // These tests measure the *rendered* (post-FittedBox) on-screen size via
  // tester.getTopLeft/getBottomRight — unlike tester.getSize, those apply the
  // full transform chain (including FittedBox's scale), so they reflect what
  // actually reaches the screen, not the unscaled layout size.
  group('BatteryWidget — size slider honesty', () {
    // The real BATTERY slot at the reference Safe Area geometry (1024×576 @
    // 213dpi, T2/T3 — CONTEXT.md's 616×175dp Safe Area converted to logical
    // px at that density): saWidth*0.12 × saHeight*0.6 (hud_root.dart:131,
    // 128). This is the actual physical constraint the slider's range is
    // honest (or not) against.
    const slotSize = Size(98.4, 139.8);

    Size renderedIconSize(WidgetTester tester) {
      final finder = find.byKey(const ValueKey('battery-icon'));
      final topLeft = tester.getTopLeft(finder);
      final bottomRight = tester.getBottomRight(finder);
      return Size(bottomRight.dx - topLeft.dx, bottomRight.dy - topLeft.dy);
    }

    Future<void> pumpAt(
      WidgetTester tester, {
      required double sizeScale,
      bool showTemp = true,
      bool showChargingStats = true,
      bool charging = false,
    }) async {
      final signals = FakeCarSignals();
      final config = AppConfig(
        battery: BatteryConfig(
          sizeScale: sizeScale,
          showTemp: showTemp,
          showChargingStats: showChargingStats,
        ),
      );
      await tester.pumpWidget(wrapWithProviders(
        SizedBox.fromSize(size: slotSize, child: const BatteryWidget()),
        config: config,
        signals: signals,
        scaffold: true,
        localizations: false,
      ));
      signals.emitBattery(levelPct: 72, tempC: 24.0);
      if (charging) signals.emitCharge(charging: true, kw: 42.0);
      await tester.pump();
    }

    testWidgets(
        'no charging stats: icon keeps growing with sizeScale across '
        'almost the entire 0.5-2.5 range (single "NN%" line is the only '
        'competing width, so it stays under the slot for far longer than '
        'the old icon+pct row did)', (tester) async {
      await tester.binding.setSurfaceSize(slotSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpAt(tester, sizeScale: 0.5, showTemp: false, showChargingStats: false);
      final at05 = renderedIconSize(tester).width;

      await pumpAt(tester, sizeScale: 1.5, showTemp: false, showChargingStats: false);
      final at15 = renderedIconSize(tester).width;

      await pumpAt(tester, sizeScale: 2.0, showTemp: false, showChargingStats: false);
      final at20 = renderedIconSize(tester).width;

      // Real, substantial growth at every step — not the near-flat line the
      // old row layout produced once past sizeScale≈1.07.
      expect(at15, greaterThan(at05 * 1.5),
          reason: 'growth from 0.5x to 1.5x must be substantial, not '
              'absorbed by FittedBox scaleDown');
      expect(at20, greaterThan(at15 * 1.05),
          reason: 'growth must still be visible out at 2.0x when charging '
              'stats are not competing for width');
    });

    testWidgets(
        'temp + charging stats shown (worst case): growth is still real up '
        'through the middle of the range, even though the widest line (the '
        '"NN kW" charging stat) caps it earlier than the no-stats case',
        (tester) async {
      await tester.binding.setSurfaceSize(slotSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpAt(tester, sizeScale: 0.5, charging: true);
      final at05 = renderedIconSize(tester).width;

      await pumpAt(tester, sizeScale: 1.0, charging: true);
      final at10 = renderedIconSize(tester).width;

      await pumpAt(tester, sizeScale: 1.25, charging: true);
      final at125 = renderedIconSize(tester).width;

      // Strictly increasing across this stretch — this is exactly the span
      // that used to be flat (or nearly so) before the vertical-stack
      // layout change.
      expect(at10, greaterThan(at05));
      expect(at125, greaterThan(at10));
    });

    testWidgets(
        'no overflow at the slider maximum (2.5x) with battery + temp + '
        'charging stats all rendering at once — pins the Block 0026 fix '
        '(FittedBox around the whole panel, not just the icon row)',
        (tester) async {
      await tester.binding.setSurfaceSize(slotSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpAt(tester, sizeScale: 2.5, charging: true);

      // A RenderFlex/layout overflow surfaces as a FlutterError captured by
      // the test binding, not a thrown Dart exception during pump() — so it
      // must be checked via takeException(), not a try/catch around pumpAt.
      expect(tester.takeException(), isNull,
          reason: 'the whole panel must still fit (via FittedBox scaleDown), '
              'never overflow the fixed BATTERY slot, at the maximum '
              'sizeScale with every optional row showing at once');

      // The widget must still actually render something (not blank) —
      // scaling down to fit is correct; disappearing is not.
      expect(find.byKey(const ValueKey('battery-icon')), findsOneWidget);
      expect(find.byKey(const ValueKey('charging-stats')), findsOneWidget);
    });
  });
}
