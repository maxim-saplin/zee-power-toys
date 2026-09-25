import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/range_estimate_service.dart';
import 'car_signals.dart';
import 'config.dart';
import 'services.dart';

final rangeEstimateServiceProvider = Provider<RangeEstimateService>((ref) {
  final svc = RangeEstimateService();
  // Prefs load is async; first ticks may run before restore — OK (fresh EWMA).
  svc.ensureLoaded();
  return svc;
});

/// Own estimated range km for HUD (null = hidden).
///
/// Default toggle OFF; even when ON, null until ≥~5 km moving history.
final estimatedRangeKmProvider = Provider<int?>((ref) {
  final cfg = ref.watch(batteryConfigProvider);
  if (!cfg.showOwnRangeEstimate) return null;
  _touch(ref);
  final signals = ref.watch(carSignalsProvider);
  final svc = ref.watch(rangeEstimateServiceProvider);
  return svc.tick(signals.snapshot);
});

void _touch(Ref ref) {
  ref.watch(carSignalEventsProvider);
}
