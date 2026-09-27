import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../services/range_estimate_service.dart';

/// Kept so prefs / tests that override the service still compile.
/// 0119c: range feature removed from HUD/settings — providers always null.
final rangeEstimateServiceProvider = Provider<RangeEstimateService>((ref) {
  final svc = RangeEstimateService();
  svc.ensureLoaded();
  return svc;
});

/// 0119c — range feature removed. Always null (do not drive HUD).
final ownEstimatedRangeKmProvider = Provider<int?>((ref) => null);

/// 0119c — range feature removed. Always null.
final consEstimatedRangeKmProvider = Provider<int?>((ref) => null);

/// 0119c — range feature removed. Always null (no `N km` / `… km` on HUD).
final estimatedRangeKmProvider = Provider<int?>((ref) => null);
