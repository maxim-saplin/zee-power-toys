import 'package:shared_preferences/shared_preferences.dart';

import 'car_signals.dart';
import 'range_estimator.dart';

const String kRangeEstimatePrefKey = 'zee.range_estimate';

/// Owns [RangeEstimator], persists the ~50 km honesty window across trips /
/// process death (0105 prefs path; 0108 composite).
class RangeEstimateService {
  RangeEstimateService({RangeEstimator? estimator})
      : _estimator = estimator ?? RangeEstimator();

  final RangeEstimator _estimator;
  bool _loaded = false;
  int? _currentKm;

  RangeEstimator get estimator => _estimator;
  int? get currentKm => _currentKm;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    _estimator.decodePersist(prefs.getString(kRangeEstimatePrefKey));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kRangeEstimatePrefKey, _estimator.encodePersist());
  }

  /// Feed latest car snapshot; returns km to show (null if not ready).
  int? tick(CarSnapshot snap, {DateTime? now}) {
    final km = _estimator.ingest(
      now: now ?? DateTime.now(),
      socPct: snap.batteryPct,
      speedKmh: snap.speedKmh,
      charging: snap.charging,
      efficiencyKwhPer100km: snap.efficiencyKwhPer100km,
    );
    if (km != _currentKm) {
      _currentKm = km;
      // Fire-and-forget persist (window / display).
      _save();
    }
    return km;
  }

  /// Test/harness: plant a ready estimate without a real trip.
  void debugSeedReady({
    double movingKm = 6,
    double whPerKm = 200,
    int? shownKm,
  }) {
    _estimator.debugForceState(
      movingKm: movingKm,
      whPerKm: whPerKm,
      lastShownKm: shownKm,
    );
    _currentKm = shownKm ??
        ((100 / 100.0) * RangeEstimator.kUsablePackWh / whPerKm).round();
  }
}
