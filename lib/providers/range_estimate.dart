import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/config_store.dart';
import '../services/range_estimate_service.dart';
import 'car_signals.dart';
import 'config.dart';
import 'services.dart';

final rangeEstimateServiceProvider = Provider<RangeEstimateService>((ref) {
  final svc = RangeEstimateService();
  // Prefs load is async; first ticks may run before restore — OK (fresh window).
  svc.ensureLoaded();
  return svc;
});

void _touch(Ref ref) {
  ref.watch(carSignalEventsProvider);
}

DualRangeEstimate _tickDual(Ref ref) {
  final signals = ref.watch(carSignalsProvider);
  final svc = ref.watch(rangeEstimateServiceProvider);
  svc.tick(signals.snapshot);
  return svc.dual;
}

/// Own estimated range km (null = not ready yet). Independent of primary mode.
final ownEstimatedRangeKmProvider = Provider<int?>((ref) {
  final cfg = ref.watch(batteryConfigProvider);
  if (!cfg.showOwnRangeEstimate) return null;
  _touch(ref);
  return _tickDual(ref).ownKm;
});

/// Cons Est. km from Adapt Cons1 (null = Cons1 invalid/missing or toggle off).
final consEstimatedRangeKmProvider = Provider<int?>((ref) {
  final cfg = ref.watch(batteryConfigProvider);
  if (!cfg.showOwnRangeEstimate) return null;
  _touch(ref);
  return _tickDual(ref).consKm;
});

/// Primary HUD range km — driven by [BatteryConfig.rangePrimaryMode] (0118).
///
/// Default toggle OFF. When ON, null until the selected Est. is ready — HUD
/// still shows a pending `… km` marker (0107); this provider only supplies digits.
final estimatedRangeKmProvider = Provider<int?>((ref) {
  final cfg = ref.watch(batteryConfigProvider);
  if (!cfg.showOwnRangeEstimate) return null;
  _touch(ref);
  final dual = _tickDual(ref);
  return switch (cfg.rangePrimaryMode) {
    RangePrimaryMode.own => dual.ownKm,
    RangePrimaryMode.adaptCons => dual.consKm,
  };
});
