---
status: tip-ready
tip:
labels: [hud, battery, range, adapt-cons, seed]
created: 2026-09-27
satisfies: Adapt-Cons HUD only — seed Cons1 + drop Own Est from HUD
tier: T3
owner: zee-dev
blocked-by: []
modules: [seedHudFromCarSignals, carSignalHudSeedEvents, estimatedRangeKmProvider, BatteryWidget / DHU settings]
priority: now
filed-by: zee-dev
related: [0105, 0107, 0117, 0118]
parent: [0118]
---

# 0119 — Adapt-Cons HUD only (seed Cons1 + drop Own Est)

## Block scope

Car evidence 2026-09-27 (`tmp/qa/car-2026-09-27-range-power/SUMMARY.md`): Cons1 `0x00103100` = **7.8 LIVE** while HUD Adapt-Cons dashed / Own showed garbage (~150 km).

1. **Seed Efficiency on hudReady/recreate** — `seedHudFromCarSignals` pushed Charge/Battery/Speed/Blinker/PowerFlow/DriveMode but never `EfficiencyEvent`. Kotlin `publishEfficiency` skips duplicate Cons1 → HUD missed first tick → Cons Est stays null → dashes.
2. **HUD range = Cons Est only** — remove Own Est from HUD primary path; invalid/missing Cons1 → pending `… km` (0107), never Own fallback.
3. **Settings:** drop Own-vs-Cons primary picker + dual Own display; keep Cons Est readout + range toggle. Default `RangePrimaryMode.adaptCons`. Own estimator code may remain for later.
4. **No Live version bump** — stay `1.1.0+26`. Soft: pack 100 kWh vs AAOS ~150; instant power — out of scope.

## Definition of Done

- [x] `carSignalHudSeedEvents` / `seedHudFromCarSignals` includes Efficiency when Cons1 present.
- [x] `estimatedRangeKmProvider` returns Cons Est only (ignores Own / primary mode).
- [x] Settings: no Own primary picker / Own dual digits on HUD product surface.
- [x] Units: Cons shows with valid Cons1; Own ready + Cons missing → pending; seed includes efficiency.
- [ ] Hot `adb install -r` platform-signed to car `8d95aaec` (parent/parallel install OK).
- [x] Tip to main; Live remains **1.1.0+26** (no tag/release bump).

## Reconciliation

**2026-09-27 tip:** Seed Cons1 + Cons-only HUD.

### Changes
1. `carSignalHudSeedEvents(CarSnapshot)` + `seedHudFromCarSignals` loops it (adds `EfficiencyEvent`).
2. HUD primary provider always `dual.consKm`.
3. Default / fromJson fallback `RangePrimaryMode.adaptCons`; settings Cons-only readout.
4. Hint copy Cons-only; Own picker UI removed.

### Soft / out of scope
Pack Wh hardcode; instant power magnitude.
