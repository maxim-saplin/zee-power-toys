import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:zee_power_toys/hud/battery_widget.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_hud_host.dart';
import 'package:zee_power_toys/services/fakes/fake_installer.dart';
import 'package:zee_power_toys/services/fakes/fake_minimap_host.dart';
import 'package:zee_power_toys/services/fakes/fake_system_config.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Wraps [child] in a minimal ProviderScope with in-memory services.
  Widget wrapWithProviders(
    Widget child, {
    AppConfig? config,
    FakeCarSignals? signals,
  }) {
    final store = SharedPrefsConfigStore();
    if (config != null) {
      store.setConfig(config);
    }
    return ProviderScope(
      overrides: [
        configStoreProvider.overrideWithValue(store),
        carSignalsProvider.overrideWithValue(signals ?? FakeCarSignals()),
        minimapHostProvider.overrideWithValue(FakeMinimapHost()),
        hudHostProvider.overrideWithValue(FakeHudHost()),
        installerProvider.overrideWithValue(FakeInstaller()),
        systemConfigProvider.overrideWithValue(FakeSystemConfig()),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  // ---------------------------------------------------------------------------
  // BatteryConfig model
  // ---------------------------------------------------------------------------

  group('BatteryConfig model', () {
    test('defaults are all-on, sizeScale 1.0', () {
      const cfg = BatteryConfig();
      expect(cfg.showBattery, isTrue);
      expect(cfg.showTemp, isTrue);
      expect(cfg.showChargingStats, isTrue);
      expect(cfg.sizeScale, 1.0);
    });

    test('round-trips through JSON', () {
      const cfg = BatteryConfig(
        showBattery: false,
        showTemp: true,
        showChargingStats: false,
        sizeScale: 1.5,
      );
      final json = cfg.toJson();
      final cfg2 = BatteryConfig.fromJson(json);
      expect(cfg2, equals(cfg));
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
      final cfg = AppConfig.fromJson(<String, Object?>{'hudBoxOn': false});
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
    testWidgets('showBattery=false renders nothing', (tester) async {
      final config = AppConfig(
        battery: const BatteryConfig(showBattery: false),
      );
      await tester.binding.setSurfaceSize(const Size(200, 200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapWithProviders(
        const SizedBox(width: 200, height: 200, child: BatteryWidget()),
        config: config,
      ));
      await tester.pump();

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
}
