import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/providers/car_signals.dart';
import 'package:zee_power_toys/providers/range_estimate.dart';
import 'package:zee_power_toys/providers/services.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/fakes/fake_car_signals.dart';
import 'package:zee_power_toys/services/range_estimate_service.dart';
import 'package:zee_power_toys/services/shared_prefs_config_store.dart';

void main() {
  test('0119c estimatedRangeKmProvider stays null (range feature removed)',
      () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeCarSignals();
    final svc = RangeEstimateService();
    await svc.ensureLoaded();
    svc.debugSeedReady(movingKm: 8, whPerKm: 200, shownKm: 150, shownConsKm: 360);

    final store = SharedPrefsConfigStore();
    await store.setConfig(
      const AppConfig(
        battery: BatteryConfig(showOwnRangeEstimate: true),
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

    fake.emitBattery(levelPct: 71, tempC: 17);
    fake.emitEfficiency(24.5);
    await Future<void>.delayed(Duration.zero);
    // Product surface no longer drives HUD range from these providers.
    // Keep estimator internals for prefs migration; HUD must not show km.
    expect(container.read(estimatedRangeKmProvider), isNull);
  });
}
