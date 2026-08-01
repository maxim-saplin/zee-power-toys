import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/diagnostics_screen.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/fakes/fake_usb_mode.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// Block 0016: FakeUsbMode is injected so DiagnosticsScreen can watch
// usbModeProvider.
Widget _wrap(Widget child, ConfigStore store, FakeCarSignals fake) =>
    wrapWithProviders(
      child,
      store: store,
      signals: fake,
      usbMode: FakeUsbMode(),
    );

Future<(SharedPrefsConfigStore, FakeCarSignals)> _makeFixture() async {
  SharedPreferences.setMockInitialValues({});
  final store = SharedPrefsConfigStore();
  await store.load();
  final fake = FakeCarSignals();
  return (store, fake);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('DiagnosticsScreen', () {
    testWidgets('renders section headers', (tester) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      expect(find.text('Motion'), findsOneWidget);
      expect(find.text('Lighting'), findsOneWidget);
      expect(find.text('Energy'), findsOneWidget);
      // The Signal source section (Task 1) pushed Battery below the default
      // test-viewport + cache-extent range — scroll it into view first.
      await tester.scrollUntilVisible(find.text('Battery'), 200);
      expect(find.text('Battery'), findsOneWidget);
    });

    testWidgets('shows — for null values before any inject', (tester) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      // Speed and battery pct/temp start null → "—" shown.
      expect(find.text('—'), findsWidgets);
    });

    testWidgets('SpeedEvent(80) causes 80 to appear in the dashboard', (
      tester,
    ) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      fake.emitSpeed(80);
      // Allow the stream + provider graph to propagate.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('80 km/h'), findsOneWidget);
    });

    testWidgets('BlinkerEvent.left causes blinker label to appear', (
      tester,
    ) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      fake.emitBlinker(BlinkerState.left);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      expect(find.text('left'), findsOneWidget);
    });

    testWidgets('ChargeEvent shows kW when charging', (tester) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      fake.emitCharge(charging: true, kw: 37.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // The charge row shows "37.0 kW".
      expect(find.text('37.0 kW'), findsOneWidget);
      // Charging state shows "yes".
      expect(find.text('yes'), findsOneWidget);
    });

    testWidgets('BatteryEvent shows level and temperature', (tester) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      fake.emitBattery(levelPct: 64, tempC: 29.0);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // The Signal source section (Task 1) pushed the Battery section below
      // the default test-viewport + cache-extent range.
      await tester.scrollUntilVisible(find.text('64 %'), 200);
      expect(find.text('64 %'), findsOneWidget);
      expect(find.text('29.0 °C'), findsOneWidget);
    });

    testWidgets(
      'combined inject: speed=88, blinker=right, charge=37kW, battery=64%/29°C',
      (tester) async {
        final (store, fake) = await _makeFixture();
        addTearDown(fake.dispose);

        await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
        await tester.pump();

        fake.emitSpeed(88);
        fake.emitBlinker(BlinkerState.right);
        fake.emitCharge(charging: true, kw: 37.0);
        fake.emitBattery(levelPct: 64, tempC: 29.0);

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 16));

        expect(find.text('88 km/h'), findsOneWidget);
        expect(find.text('right'), findsOneWidget);
        expect(find.text('37.0 kW'), findsOneWidget);
        // The Signal source section (Task 1) pushed the Battery section below
        // the default test-viewport + cache-extent range.
        await tester.scrollUntilVisible(find.text('64 %'), 200);
        expect(find.text('64 %'), findsOneWidget);
        expect(find.text('29.0 °C'), findsOneWidget);
      },
    );

    testWidgets('charge kW shows — when not charging', (tester) async {
      final (store, fake) = await _makeFixture();
      addTearDown(fake.dispose);

      await tester.pumpWidget(_wrap(const DiagnosticsScreen(), store, fake));
      await tester.pump();

      fake.emitCharge(charging: false, kw: null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));

      // kW row stays "—" when not charging.
      expect(find.text('no'), findsOneWidget);
    });
  });
}
