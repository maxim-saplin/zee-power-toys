import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/range_estimate_service.dart';
import 'package:zee_power_toys/services/range_estimator.dart';

void main() {
  group('RangeEstimator', () {
    test('empty history → not ready / null km', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 25, 12);
      expect(
        e.ingest(now: t0, socPct: 80, speedKmh: 0, charging: false),
        isNull,
      );
      expect(e.ready, isFalse);
      expect(e.historyKm, 0);
      expect(e.weightedWhPerKm, isNull);
    });

    test('short history <5 km → not ready', () {
      final e = RangeEstimator();
      // 4 km at 200 Wh/km via debug segments.
      e.debugAddSegment(distanceKm: 4.0, energyWh: 800);
      expect(e.historyKm, 4.0);
      expect(e.weightedWhPerKm, isNotNull);
      expect(e.ready, isFalse);
      expect(
        e.ingest(
          now: DateTime.utc(2026, 9, 25, 12),
          socPct: 80,
          speedKmh: 0,
        ),
        isNull,
      );
    });

    test('seeded trip ≥5 km moving with SoC drop → km', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      // 60 km/h × 15s = 0.25 km/tick. Drop 0.5% SoC every 8 ticks (~2 km)
      // → ~250 Wh/km.
      var soc = 80.0;
      int? last;
      for (var i = 0; i < 48; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc -= 0.5;
        last = e.ingest(
          now: t,
          socPct: soc.round(),
          speedKmh: 60,
          charging: false,
        );
      }
      expect(e.historyKm, greaterThanOrEqualTo(5.0));
      expect(e.ready, isTrue);
      expect(last, isNotNull);
      expect(last!, greaterThan(50));
      expect(last, lessThan(600));
    });

    test('50 km window trims oldest as new distance arrives', () {
      final e = RangeEstimator();
      // 40 km old @ 400 Wh/km, then 20 km new @ 200 Wh/km → window = 50.
      e.debugAddSegment(distanceKm: 40, energyWh: 40 * 400);
      e.debugAddSegment(distanceKm: 20, energyWh: 20 * 200);
      expect(e.historyKm, closeTo(50.0, 1e-6));
      // Oldest must have been partially trimmed (10 km of the 40 kept).
      final total = e.history.fold<double>(0, (a, s) => a + s.distanceKm);
      expect(total, closeTo(50.0, 1e-6));
      // Add another 5 km → still ≤50.
      e.debugAddSegment(distanceKm: 5, energyWh: 5 * 200);
      expect(e.historyKm, closeTo(50.0, 1e-6));
    });

    test('recent 3 km and 10 km overweight vs older kilometres', () {
      final e = RangeEstimator();
      // 40 km older @ 400 Wh/km + 7 km mid @ 100 + 3 km latest @ 100.
      e.debugAddSegment(distanceKm: 40, energyWh: 40 * 400);
      e.debugAddSegment(distanceKm: 7, energyWh: 7 * 100);
      e.debugAddSegment(distanceKm: 3, energyWh: 3 * 100);
      expect(e.historyKm, closeTo(50.0, 1e-6));
      final weighted = e.weightedWhPerKm!;
      // Unweighted mean = (40*400 + 10*100) / 50 = 340 Wh/km.
      const unweighted = 340.0;
      // Weighted: 40×1×400 + 7×4×100 + 3×8×100 over 40+28+24 = 230.43.
      expect(weighted, lessThan(280));
      expect(weighted, lessThan(unweighted - 50));
      expect(weighted, closeTo(230.4, 5.0));
    });

    test('latest 3 km band is strongest within the recent 10', () {
      final e = RangeEstimator();
      // Flat older 40 @ 300, then 7 km mid @ 300, then 3 km latest @ 100.
      e.debugAddSegment(distanceKm: 40, energyWh: 40 * 300);
      e.debugAddSegment(distanceKm: 7, energyWh: 7 * 300);
      e.debugAddSegment(distanceKm: 3, energyWh: 3 * 100);
      final withLatest = e.weightedWhPerKm!;

      final eFlat = RangeEstimator();
      eFlat.debugAddSegment(distanceKm: 40, energyWh: 40 * 300);
      eFlat.debugAddSegment(distanceKm: 7, energyWh: 7 * 300);
      eFlat.debugAddSegment(distanceKm: 3, energyWh: 3 * 300);
      final allFlat = eFlat.weightedWhPerKm!;

      expect(withLatest, lessThan(allFlat - 20));
    });

    test('1 km refresh cadence — no display thrash between boundaries', () {
      final e = RangeEstimator();
      // Ready window at 200 Wh/km (~500 km at 100%).
      e.debugForceState(movingKm: 10, whPerKm: 200, lastShownKm: null);
      final t0 = DateTime.utc(2026, 9, 25, 12);
      // First publish at 80% → 400 km.
      final first = e.ingest(now: t0, socPct: 80, speedKmh: 0);
      expect(first, 400);

      // SoC drops (would be 350 km raw) but no moving distance → hold 400.
      final held = e.ingest(
        now: t0.add(const Duration(seconds: 5)),
        socPct: 70,
        speedKmh: 0,
      );
      expect(held, 400);

      // Crawl under min speed still does not publish.
      final still = e.ingest(
        now: t0.add(const Duration(seconds: 10)),
        socPct: 70,
        speedKmh: 1,
      );
      expect(still, 400);

      // Drive ~1.1 km at 60 km/h (66 s) with SoC 70 → should republish ~350.
      var t = t0.add(const Duration(seconds: 10));
      int? last = still;
      for (var i = 0; i < 5; i++) {
        t = t.add(const Duration(seconds: 15)); // 0.25 km each @ 60
        last = e.ingest(now: t, socPct: 70, speedKmh: 60);
      }
      // 1.25 km moved — display must have refreshed away from 400.
      expect(last, isNotNull);
      expect(last, isNot(400));
      expect(last!, closeTo(350, 30));
    });

    test('SoC drop + distance ballpark Adapt trip figures', () {
      // 16 km @ 21.1 kWh/100km (= 211 Wh/km) then SoC 81% → ~384 km.
      final e = RangeEstimator();
      e.debugAddSegment(distanceKm: 16, energyWh: 16 * 211);
      expect(e.ready, isTrue);
      expect(e.weightedWhPerKm!, closeTo(211, 1));
      final t0 = DateTime.utc(2026, 9, 25, 12);
      final km = e.ingest(now: t0, socPct: 81, speedKmh: 0);
      expect(km, closeTo(384, 5));

      // 29.3 km @ 20.3 kWh/100km then SoC 78% → ~384 km.
      final e2 = RangeEstimator();
      e2.debugAddSegment(distanceKm: 29.3, energyWh: 29.3 * 203);
      final km2 = e2.ingest(now: t0, socPct: 78, speedKmh: 0);
      expect(km2, closeTo(384, 5));
    });

    test('regen SoC↑ while moving is valid (not treated as charge)', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      var soc = 70.0;
      for (var i = 0; i < 48; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc -= 0.5;
        e.ingest(now: t, socPct: soc.round(), speedKmh: 50, charging: false);
      }
      final before = e.weightedWhPerKm;
      expect(before, isNotNull);
      for (var i = 0; i < 16; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc += 0.6;
        e.ingest(now: t, socPct: soc.round(), speedKmh: 40, charging: false);
      }
      expect(e.weightedWhPerKm, isNotNull);
      expect(e.weightedWhPerKm!, lessThanOrEqualTo(before! + 1));
    });

    test('charging intervals ignored', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      e.ingest(now: t, socPct: 40, speedKmh: 0, charging: true);
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(seconds: 10));
        e.ingest(
          now: t,
          socPct: 40 + i,
          speedKmh: 0,
          charging: true,
        );
      }
      expect(e.movingKmAccum, 0);
      expect(e.historyKm, 0);
      expect(e.ready, isFalse);
    });

    test('SoCΔ≈0 samples dropped; gap resets segment', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      e.ingest(now: t, socPct: 60, speedKmh: 60, charging: false);
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(seconds: 15));
        e.ingest(now: t, socPct: 60, speedKmh: 60, charging: false);
      }
      expect(e.weightedWhPerKm, isNull);
      expect(e.historyKm, 0);
      t = t.add(const Duration(seconds: 60));
      e.ingest(now: t, socPct: 59, speedKmh: 60, charging: false);
      expect(e.ready, isFalse);
    });

    test('0114 short-trip cliff: 2.7 km + 1% SoC must not wipe ~45 km Est', () {
      // Prior honesty window ≈353 Wh/km → 218 km at 77% (incident prior).
      final e = RangeEstimator();
      e.debugForceState(movingKm: 47.3, whPerKm: 353.21, lastShownKm: 218);
      var t = DateTime.utc(2026, 9, 26, 10);
      e.ingest(now: t, socPct: 78, speedKmh: 0);

      // 2.7 km @ 60 km/h in 15 s ticks (0.25 km). SoC 78→77 after ~0.5 km
      // (integer quantum) — the path that used to accept 2000 Wh/km and
      // 8×-weight it into a ~45 km wipe.
      var soc = 78;
      int? last = 218;
      for (var i = 0; i < 11; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i == 1) soc = 77;
        last = e.ingest(now: t, socPct: soc, speedKmh: 60);
      }

      expect(e.movingKmAccum - 47.3, closeTo(2.75, 0.05));
      expect(last, isNotNull);
      final shown = last!;
      // Must stay near prior — no ~45 km nonsense wipe (incident was 173).
      expect(shown, greaterThanOrEqualTo(200));
      expect(218 - shown, lessThan(25));
      // Weighted must not jump to the ~445 Wh/km that produced 173.
      expect(e.weightedWhPerKm!, lessThan(400));
    });

    test('0114 keep-open: 1% SoC on short km dilutes instead of discarding', () {
      final e = RangeEstimator();
      e.debugForceState(movingKm: 20, whPerKm: 250, lastShownKm: 300);
      var t = DateTime.utc(2026, 9, 26, 11);
      e.ingest(now: t, socPct: 80, speedKmh: 0);

      // First 0.25 km tick drops SoC 1% — sample would be 4000 Wh/km.
      // Old code reset and lost the energy; new code keeps segment open.
      t = t.add(const Duration(seconds: 15));
      e.ingest(now: t, socPct: 79, speedKmh: 60);
      expect(e.history.length, 1); // only the seeded segment so far

      // Keep driving until 1000 Wh / 500 Wh/km = 2.0 km dilutes under cap.
      for (var i = 0; i < 8; i++) {
        t = t.add(const Duration(seconds: 15));
        e.ingest(now: t, socPct: 79, speedKmh: 60);
      }
      // Seeded 20 km + new diluted segment (≥2 km) in history.
      expect(e.history.length, 2);
      final newest = e.history.last;
      expect(newest.distanceKm, closeTo(2.0, 0.3));
      expect(newest.energyWh / newest.distanceKm, lessThanOrEqualTo(500.0 + 1e-6));
    });

    test('0114 Adapt-like 24 kWh/100 short hop does not cliff prior Est', () {
      // Simulate ≈77% / 2.7 km / ~24 kWh/100 against a prior 218 window.
      final e = RangeEstimator();
      e.debugForceState(movingKm: 47.3, whPerKm: 353.21, lastShownKm: 218);
      // Inject the hop as one honest segment at Adapt ballpark (242 Wh/km).
      e.debugAddSegment(distanceKm: 2.7, energyWh: 2.7 * 242);
      final t0 = DateTime.utc(2026, 9, 26, 12);
      final km = e.ingest(now: t0, socPct: 77, speedKmh: 0);
      expect(km, isNotNull);
      // Heavier recent band at *lower* Wh/km should not erase tens of km;
      // if anything Est rises slightly. Never a ~45 km wipe.
      expect(km!, greaterThanOrEqualTo(200));
      expect((km - 218).abs(), lessThan(40));
    });

    test('Adapt efficiency does not seed the composite', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 25, 12);
      expect(
        e.ingest(
          now: t0,
          socPct: 90,
          speedKmh: 0,
          efficiencyKwhPer100km: 18.0,
        ),
        isNull,
      );
      expect(e.weightedWhPerKm, isNull);
      expect(e.ready, isFalse);
    });

    test('persist round-trip keeps window across trips', () {
      final e = RangeEstimator();
      e.debugForceState(movingKm: 12, whPerKm: 190, lastShownKm: 200);
      final raw = e.encodePersist();
      final e2 = RangeEstimator();
      e2.decodePersist(raw);
      expect(e2.movingKmAccum, 12);
      expect(e2.historyKm, greaterThanOrEqualTo(5));
      expect(e2.weightedWhPerKm, closeTo(190, 1));
      expect(e2.ready, isTrue);
    });

    test('migrates 0105 EWMA prefs into a synthetic segment', () {
      final e = RangeEstimator();
      e.restoreFromPersistJson(<String, Object?>{
        'movingKmAccum': 12.0,
        'ewmaWhPerKm': 190.0,
        'lastShownKm': 200,
        'seededFromAdapt': false,
      });
      expect(e.ready, isTrue);
      expect(e.weightedWhPerKm, closeTo(190, 1));
      expect(e.historyKm, closeTo(12.0, 1e-6));
    });
  });

  group('BatteryConfig.showOwnRangeEstimate', () {
    test('defaults false and persists', () {
      const c = BatteryConfig();
      expect(c.showOwnRangeEstimate, isFalse);
      final on = c.copyWith(showOwnRangeEstimate: true);
      expect(on.showOwnRangeEstimate, isTrue);
      expect(
        BatteryConfig.fromJson(on.toJson()).showOwnRangeEstimate,
        isTrue,
      );
      expect(
        BatteryConfig.fromJson(const {}).showOwnRangeEstimate,
        isFalse,
      );
    });
  });

  group('RangeEstimateService', () {
    test('toggle-off path: service ticks but HUD gate is config', () async {
      SharedPreferences.setMockInitialValues({});
      final svc = RangeEstimateService();
      await svc.ensureLoaded();
      svc.debugSeedReady(movingKm: 8, whPerKm: 200, shownKm: 180);
      final km = svc.tick(
        const CarSnapshot(batteryPct: 72, speedKmh: 0, charging: false),
      );
      expect(km, isNotNull);
    });
  });
}
