import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zee_power_toys/services/car_signals.dart';
import 'package:zee_power_toys/services/config_store.dart';
import 'package:zee_power_toys/services/range_estimate_service.dart';
import 'package:zee_power_toys/services/range_estimator.dart';

void main() {
  group('RangeEstimator', () {
    test('no history → not ready / null km', () {
      final e = RangeEstimator();
      final t0 = DateTime.utc(2026, 9, 25, 12);
      expect(
        e.ingest(now: t0, socPct: 80, speedKmh: 0, charging: false),
        isNull,
      );
      expect(e.ready, isFalse);
    });

    test('seeded trip ≥5 km moving with SoC drop → ~km', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      // 60 km/h × 15s = 0.25 km/tick. Drop 0.5% SoC every 8 ticks (~2 km)
      // → ~250 Wh/km (realistic; avoids absurd-sample reject at tiny segments).
      var soc = 80.0;
      int? last;
      for (var i = 0; i < 48; i++) {
        // 12 km moving
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc -= 0.5;
        last = e.ingest(
          now: t,
          socPct: soc.round(),
          speedKmh: 60,
          charging: false,
        );
      }
      expect(e.movingKmAccum, greaterThanOrEqualTo(5.0));
      expect(e.ready, isTrue);
      expect(last, isNotNull);
      expect(last!, greaterThan(50));
      expect(last, lessThan(600));
    });

    test('regen SoC↑ while moving is valid (not treated as charge)', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      // Build EWMA with consume first (~250 Wh/km over ≥5 km).
      var soc = 70.0;
      for (var i = 0; i < 48; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc -= 0.5;
        e.ingest(now: t, socPct: soc.round(), speedKmh: 50, charging: false);
      }
      final before = e.ewmaWhPerKm;
      expect(before, isNotNull);
      // Regen burst: SoC climbs while still moving, charging=false.
      // 40 km/h × 15s ≈ 0.167 km/tick; +0.6% every 8 ticks over ~1.3 km.
      for (var i = 0; i < 16; i++) {
        t = t.add(const Duration(seconds: 15));
        if (i > 0 && i % 8 == 0) soc += 0.6;
        e.ingest(now: t, socPct: soc.round(), speedKmh: 40, charging: false);
      }
      // EWMA should still be defined and typically improve (lower Wh/km).
      expect(e.ewmaWhPerKm, isNotNull);
      expect(e.ewmaWhPerKm!, lessThanOrEqualTo(before! + 1));
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
      expect(e.ready, isFalse);
    });

    test('SoCΔ≈0 samples dropped; gap resets segment', () {
      final e = RangeEstimator();
      var t = DateTime.utc(2026, 9, 25, 12);
      e.ingest(now: t, socPct: 60, speedKmh: 60, charging: false);
      // Flat SoC over distance — no EWMA yet.
      for (var i = 0; i < 20; i++) {
        t = t.add(const Duration(seconds: 15));
        e.ingest(now: t, socPct: 60, speedKmh: 60, charging: false);
      }
      expect(e.ewmaWhPerKm, isNull);
      // Large gap
      t = t.add(const Duration(seconds: 60));
      e.ingest(now: t, socPct: 59, speedKmh: 60, charging: false);
      expect(e.ready, isFalse);
    });

    test('Adapt efficiency seeds EWMA but still needs 5 km', () {
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
      expect(e.ewmaWhPerKm, 180.0); // 18 kWh/100km → 180 Wh/km
      expect(e.ready, isFalse);
    });

    test('persist round-trip keeps EWMA across trips', () {
      final e = RangeEstimator();
      e.debugForceState(movingKm: 12, ewmaWhPerKm: 190, lastShownKm: 200);
      final raw = e.encodePersist();
      final e2 = RangeEstimator();
      e2.decodePersist(raw);
      expect(e2.movingKmAccum, 12);
      expect(e2.ewmaWhPerKm, 190);
      expect(e2.ready, isTrue);
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
      svc.debugSeedReady(movingKm: 8, ewmaWhPerKm: 200, shownKm: 180);
      final km = svc.tick(
        const CarSnapshot(batteryPct: 72, speedKmh: 0, charging: false),
      );
      expect(km, isNotNull);
    });
  });
}
