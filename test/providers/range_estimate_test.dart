import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/providers/car_signals.dart';
import 'package:zee_power_toys/providers/range_estimate.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/range_estimate_service.dart';
import 'package:zee_power_toys/services/range_estimator.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  test('0119 HUD primary is Cons-only (ignores Own + rangePrimaryMode.own)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeCarSignals();
    final svc = RangeEstimateService();
    await svc.ensureLoaded();
    // Plant Own Est only — Cons not ready.
    svc.debugSeedReady(movingKm: 8, whPerKm: 200, shownKm: 150);

    final store = SharedPrefsConfigStore();
    await store.setConfig(
      const AppConfig(
        battery: BatteryConfig(
          showOwnRangeEstimate: true,
          rangePrimaryMode: RangePrimaryMode.own,
        ),
      ),
    );

    final container = ProviderContainer(
      overrides: [
        carSignalsProvider.overrideWithValue(fake),
        rangeEstimateServiceProvider.overrideWithValue(svc),
        configStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(fake.dispose);
    container.listen(carSignalEventsProvider, (_, __) {});

    // No Cons1 yet → HUD primary null even though Own is ready and mode=own.
    fake.emitBattery(levelPct: 71, tempC: 17);
    await Future<void>.delayed(Duration.zero);
    expect(container.read(ownEstimatedRangeKmProvider), isNotNull);
    expect(container.read(consEstimatedRangeKmProvider), isNull);
    expect(container.read(estimatedRangeKmProvider), isNull);

    // Live Cons1 → HUD primary = Cons Est (not Own 150).
    fake.emitEfficiency(7.8);
    await Future<void>.delayed(Duration.zero);
    final expectedCons =
        RangeEstimator.consEstKm(socPct: 71.0, consKwhPer100: 7.8);
    expect(container.read(consEstimatedRangeKmProvider), expectedCons);
    expect(container.read(estimatedRangeKmProvider), expectedCons);
    expect(container.read(estimatedRangeKmProvider), isNot(150));
  });
}
