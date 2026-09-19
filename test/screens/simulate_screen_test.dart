import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/screens/simulate_screen.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

import '../support/harness.dart';

/// F1 regression: SimulateScreen must not advertise battery defaults that the
/// LIVE preview does not paint. On enter with an empty CarSignals snapshot the
/// screen seeds the displayed defaults once so controls and pixels match.
void main() {
  setUp(useMockPrefs);

  testWidgets(
    'F1: on enter with empty snapshot, seeds battery so LIVE preview shows '
    'slider % not --%',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore();
      await store.load();
      final signals = FakeCarSignals();
      addTearDown(signals.dispose);

      expect(signals.snapshot.batteryPct, isNull);

      await tester.pumpWidget(
        wrapWithProviders(
          const SimulateScreen(),
          store: store,
          signals: signals,
        ),
      );
      await tester.pump(); // build
      await tester.pump(); // post-frame seed

      // Seeded into the live chain.
      expect(signals.snapshot.batteryPct, 72);
      expect(signals.snapshot.batteryTempC, 24.0);

      // LIVE preview must paint the seeded % — never `--%` while slider says 72%.
      expect(find.text('72%'), findsWidgets);
      expect(find.text('--%'), findsNothing);
    },
  );

  testWidgets(
    'F1: does not overwrite an already-injected battery snapshot',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final store = SharedPrefsConfigStore();
      await store.load();
      final signals = FakeCarSignals();
      addTearDown(signals.dispose);
      signals.emitBattery(levelPct: 55, tempC: 31.0);

      await tester.pumpWidget(
        wrapWithProviders(
          const SimulateScreen(),
          store: store,
          signals: signals,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(signals.snapshot.batteryPct, 55);
      expect(signals.snapshot.batteryTempC, 31.0);
      expect(find.text('55%'), findsWidgets);
    },
  );
}
