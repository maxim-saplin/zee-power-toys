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
          socPct: soc,
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

    test('0117 bands: 1..5 km @ 8× overweight vs 5..50 @ 1×', () {
      final e = RangeEstimator();
      // 45 km older @ 400 Wh/km + 4 km peak (1..5) @ 100 + 1 km mute @ 100.
      // From now: 0..1 mute, 1..5 peak 8×, 5..50 older 1×.
      e.debugAddSegment(distanceKm: 45, energyWh: 45 * 400);
      e.debugAddSegment(distanceKm: 4, energyWh: 4 * 100);
      e.debugAddSegment(distanceKm: 1, energyWh: 1 * 100);
      expect(e.historyKm, closeTo(50.0, 1e-6));
      final weighted = e.weightedWhPerKm!;
      // Unweighted = (45*400 + 5*100) / 50 = 370.
      const unweighted = 370.0;
      // Weighted: mute 0 + peak 4×8×100 + older 45×1×400 over (0+32+45)=77
      // → (3200 + 18000) / 77 ≈ 275.3.
      expect(weighted, lessThan(300));
      expect(weighted, lessThan(unweighted - 50));
      expect(weighted, closeTo(275.3, 5.0));
    });

    test('0117 peak 1..5 band is stronger than flat older-only', () {
      final e = RangeEstimator();
      // Flat older 45 @ 300, peak 4 @ 100, mute 1 @ 100.
      e.debugAddSegment(distanceKm: 45, energyWh: 45 * 300);
      e.debugAddSegment(distanceKm: 4, energyWh: 4 * 100);
      e.debugAddSegment(distanceKm: 1, energyWh: 1 * 100);
      final withPeak = e.weightedWhPerKm!;

      final eFlat = RangeEstimator();
      eFlat.debugAddSegment(distanceKm: 45, energyWh: 45 * 300);
      eFlat.debugAddSegment(distanceKm: 4, energyWh: 4 * 300);
      eFlat.debugAddSegment(distanceKm: 1, energyWh: 1 * 300);
      final allFlat = eFlat.weightedWhPerKm!;

      expect(withPeak, lessThan(allFlat - 20));
    });

    test('0117 last 1 km mute: samples in 0..1 contribute zero weight', () {
      final e = RangeEstimator();
      // 49 km @ 200 + last 1 km @ 2000 (would dominate without mute).
      e.debugAddSegment(distanceKm: 49, energyWh: 49 * 200);
      e.debugAddSegment(distanceKm: 1, energyWh: 1 * 2000);
      final weighted = e.weightedWhPerKm!;
      // Mute drops the 2000 Wh/km km → weighted stays ~200.
      expect(weighted, closeTo(200.0, 2.0));
    });

    test('0117 mute-only window → weighted null until peak/older exists', () {
      final e = RangeEstimator();
      // Only last-1 km samples → all weight 0 → no rate, not ready.
      e.debugAddSegment(distanceKm: 0.8, energyWh: 0.8 * 250);
      expect(e.historyKm, closeTo(0.8, 1e-6));
      expect(e.weightedWhPerKm, isNull);
      expect(e.ready, isFalse);
      expect(
        e.ingest(
          now: DateTime.utc(2026, 9, 26, 15),
          socPct: 80,
          speedKmh: 0,
        ),
        isNull,
      );
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
        e.ingest(now: t, socPct: soc, speedKmh: 50, charging: false);
      }
      final before = e.weightedWhPerKm;
      expect(before, isNotNull);
      for (var i = 0; i < 16; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc += 0.6;
        e.ingest(now: t, socPct: soc, speedKmh: 40, charging: false);
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
          socPct: (40 + i).toDouble(),
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
      // peak-weight it into a ~45 km wipe.
      var soc = 78.0;
      int? last = 218;
      for (var i = 0; i < 11; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i == 1) soc = 77.0;
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

    test('0117 Adapt Cons does not project or clamp display Est', () {
      // Reshape: own window only — trustworthy Adapt Cons must not move Est
      // toward (SoC% ÷ Cons)×100. Persisted ~353 Wh/km → ~218 @ 77%.
      final e = RangeEstimator();
      e.debugForceState(movingKm: 47.3, whPerKm: 353.21, lastShownKm: 218);
      final t0 = DateTime.utc(2026, 9, 26, 18);
      const adaptCons = 24.2;
      final km = e.ingest(
        now: t0,
        socPct: 77,
        speedKmh: 0,
        efficiencyKwhPer100km: adaptCons,
      );
      expect(km, closeTo(218, 2));
      expect(e.weightedWhPerKm!, closeTo(353.21, 1));
      // Must NOT jump to Adapt envelope (~318).
      expect(km!, lessThan(250));
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


    test('0118 float SoC: 0.1% ticks feed own Est without int truncation', () {
      final e = RangeEstimator();
      // Plant ready window @ 200 Wh/km → 100% = 500 km.
      e.debugForceState(movingKm: 10, whPerKm: 200, lastShownKm: null);
      final t0 = DateTime.utc(2026, 9, 26, 20);
      // 85.7% float → 428.5 → 429 km (int trunc would have been 85% → 425).
      final km = e.ingest(now: t0, socPct: 85.7, speedKmh: 0);
      expect(km, 429);
      expect(e.ingest(now: t0.add(const Duration(seconds: 1)), socPct: 85.8, speedKmh: 0), 429);
    });

    test('0118 Cons Est math: (soc/100)×pack / (cons×10)', () {
      expect(
        RangeEstimator.consEstKm(socPct: 80, consKwhPer100: 20),
        400,
      );
      expect(
        RangeEstimator.consEstKm(socPct: 85.7, consKwhPer100: 24.2),
        closeTo(354, 1),
      );
      expect(RangeEstimator.consEstKm(socPct: 80, consKwhPer100: 0), isNull);
      expect(RangeEstimator.consEstKm(socPct: 80, consKwhPer100: 250), isNull);
    });

    test('0118 Cons Est via ingest: valid Cons1 publishes; sentinel hides', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 26, 21);
      e.ingest(
        now: t0,
        socPct: 80,
        speedKmh: 0,
        efficiencyKwhPer100km: 20,
      );
      expect(e.lastShownConsKm, 400);

      // Sentinel → Cons Est unavailable; own path unaffected.
      e.ingest(
        now: t0.add(const Duration(seconds: 2)),
        socPct: 80,
        speedKmh: 0,
        efficiencyKwhPer100km: 0,
      );
      expect(e.lastShownConsKm, isNull);
    });

    test('0118 Cons soft lag: tiny Cons ticks do not thrash display', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 26, 22);
      e.ingest(now: t0, socPct: 80, speedKmh: 0, efficiencyKwhPer100km: 20.0);
      expect(e.lastShownConsKm, 400);
      // Tiny Cons drift 20.0 → 20.1 while idle — hold 400.
      e.ingest(
        now: t0.add(const Duration(seconds: 5)),
        socPct: 80,
        speedKmh: 0,
        efficiencyKwhPer100km: 20.1,
      );
      expect(e.lastShownConsKm, 400);
      // Jump ≥0.5 kWh/100 → refresh.
      e.ingest(
        now: t0.add(const Duration(seconds: 10)),
        socPct: 80,
        speedKmh: 0,
        efficiencyKwhPer100km: 20.6,
      );
      expect(e.lastShownConsKm, isNot(400));
    });

    test('0118 own path still ignores Adapt Cons seed/project', () {
      final e = RangeEstimator();
      e.debugForceState(movingKm: 47.3, whPerKm: 353.21, lastShownKm: 218);
      final t0 = DateTime.utc(2026, 9, 26, 23);
      final km = e.ingest(
        now: t0,
        socPct: 77,
        speedKmh: 0,
        efficiencyKwhPer100km: 24.2,
      );
      expect(km, closeTo(218, 2));
      // Cons Est is separate and available.
      expect(e.lastShownConsKm, isNotNull);
      expect(e.lastShownConsKm, closeTo(318, 5));
    });

  group('BatteryConfig.showOwnRangeEstimate', () {
    test('defaults false and persists', () {
      const c = BatteryConfig();
      expect(c.showOwnRangeEstimate, isFalse);
      expect(c.rangePrimaryMode, RangePrimaryMode.adaptCons);
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

    test('0118 rangePrimaryMode persists', () {
      const c = BatteryConfig(rangePrimaryMode: RangePrimaryMode.adaptCons);
      expect(c.rangePrimaryMode, RangePrimaryMode.adaptCons);
      expect(
        BatteryConfig.fromJson(c.toJson()).rangePrimaryMode,
        RangePrimaryMode.adaptCons,
      );
      expect(
        BatteryConfig.fromJson(const {}).rangePrimaryMode,
        RangePrimaryMode.adaptCons,
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

  group('0119 Cons Est HUD seed + Cons-only primary', () {
    test('carSignalHudSeedEvents includes EfficiencyEvent when Cons1 set', () {
      const snap = CarSnapshot(
        batteryPct: 71.0,
        batteryTempC: 17.0,
        efficiencyKwhPer100km: 7.8,
        speedKmh: 40,
      );
      final events = carSignalHudSeedEvents(snap);
      expect(events.whereType<EfficiencyEvent>(), hasLength(1));
      expect(
        events.whereType<EfficiencyEvent>().single.kwhPer100km,
        closeTo(7.8, 1e-9),
      );
      expect(events.whereType<BatteryEvent>(), hasLength(1));
      expect(events.whereType<SpeedEvent>(), hasLength(1));
    });

    test('carSignalHudSeedEvents omits EfficiencyEvent when Cons1 null', () {
      const snap = CarSnapshot(batteryPct: 71.0, batteryTempC: 17.0);
      final events = carSignalHudSeedEvents(snap);
      expect(events.whereType<EfficiencyEvent>(), isEmpty);
    });

    test('Cons Est shows with valid Cons1 (car evidence shape)', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 27, 17);
      // Cons1=7.8 live, SoC≈71 → Cons Est ≈ (0.71)*100000/(7.8*10) ≈ 910 km
      final own = e.ingest(
        now: t0,
        socPct: 71.0,
        speedKmh: 0,
        efficiencyKwhPer100km: 7.8,
      );
      expect(own, isNull); // no own-trip window yet
      expect(e.lastShownConsKm, isNotNull);
      expect(
        e.lastShownConsKm,
        RangeEstimator.consEstKm(socPct: 71.0, consKwhPer100: 7.8),
      );
    });

    // 0119b: FW returns ~650 on classic 0x00103100 (aux-like). Dart must keep
    // rejecting it as kWh/100; native binds alt 0x00103300 (~7.8) instead.
    test('0119b rejects classic-ID junk 650 as Cons1; 7.8 still valid', () {
      expect(RangeEstimator.isValidEfficiencyKwhPer100km(650.7), isFalse);
      expect(RangeEstimator.isValidEfficiencyKwhPer100km(651.2), isFalse);
      expect(RangeEstimator.isValidEfficiencyKwhPer100km(7.8), isTrue);
      expect(RangeEstimator.isValidEfficiencyKwhPer100km(16.6), isTrue);
      expect(
        RangeEstimator.consEstKm(socPct: 70.0, consKwhPer100: 650.7),
        isNull,
      );
      expect(
        RangeEstimator.consEstKm(socPct: 70.0, consKwhPer100: 7.8),
        isNotNull,
      );
      final e = RangeEstimator();
      e.ingest(
        now: DateTime.utc(2026, 9, 27, 18),
        socPct: 70.0,
        speedKmh: 0,
        efficiencyKwhPer100km: 650.7,
      );
      expect(e.lastShownConsKm, isNull);
      e.ingest(
        now: DateTime.utc(2026, 9, 27, 18, 0, 1),
        socPct: 70.0,
        speedKmh: 0,
        efficiencyKwhPer100km: 7.8,
      );
      expect(e.lastShownConsKm, isNotNull);
    });
  });
}
