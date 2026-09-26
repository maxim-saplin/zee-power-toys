---
status: tip
tip: 9ad6c56
labels: [hud, battery, range, honesty, adapt, rca]
created: 2026-09-26
satisfies: Own Est. range must not wipe ~45 km after a 2.7 km hop; RCA + fix
tier: T2
owner: zee-dev
blocked-by: []
modules: [RangeEstimator, RangeEstimateService, BatteryWidget]
priority: now
filed-by: zee-pdm
related: [0105, 0107, 0108]
parent: [0108]
gate: armed-2026-09-26
---

# 0114 — Own-range short-trip wipe RCA (218 → 173 after 2.7 km)

## Block scope

Maxim 2026-09-26 product honesty incident on Live **1.1.0+23** / 0108 estimator:

| Field | Value |
|-------|-------|
| Prior Est. | **218 km** (yesterday’s drive) |
| SoC | **77** |
| Trip | **2.7 km** |
| Consumption shown | **24.2** (kWh/100) |
| Est. after | **173 km** |

A ~**45 km** wipe on a **2.7 km** hop is nonsense vs observed distance / SoC / consumption. Own Est. must feel honest against Adapt trip figures (Maxim HARD 2026-09-25).

## Product rules

1. **RCA first** — explain why 0108’s 50 km weighted window + last-10/3 weighting produced this cliff (seed, window fill, SoC delta, pack constant, refresh gate, Adapt inject, units, etc.). Write FINDINGS before “fix” tip if cause unclear.
2. Fix must keep 0108 intent (50 km window, heavier recent km, refresh ~1 km, always-show when ON, no Adapt optimistic seed).
3. After fix: short trip at similar consumption must not erase tens of km of Est. without matching energy reality.
4. Settings hint stays honest about the window.

## DoD

- [x] RCA FINDINGS with root cause (code path + numbers)
- [x] Tip fix + unit coverage for short-trip cliff
- [x] T2 dens320: simulate ≈77% / short hop / ~24 kWh/100 → Est. moves plausibly vs prior 218 (no ~45 km wipe)
- [ ] Soft: car T3 reconfirm on next drive

## FINDINGS (RCA)

**Root cause:** Integer SoC (1% = **1000 Wh** on the 100 kWh pack constant) can close a drive segment as soon as `minSegmentKm` (0.25 km) and `|ΔSoC| ≥ 0.4`. With `maxAbsWhPerKm = 2000`, a 1% tick over **0.5 km** was accepted at **2000 Wh/km** (and ~1.0 km at **1000 Wh/km**). That sample lands in the **8× last-3 km** band of the 0108 weighted window, so a ~2.7 km hop after a persisted ~**353 Wh/km** window (Est **218 @ 77%**) shoves weighted Wh/km toward ~**445** → Est **173** (~45 km wipe) despite Adapt trip **24.2 kWh/100** (honest ballpark ~318 km at 77%). Secondary bug: when a sample exceeded the cap (e.g. 1% over 0.25 km = 4000 Wh/km), `_tryCloseSegment` **reset** the segment to the new SoC and **discarded** the energy instead of waiting for more distance to dilute the quantum.

**Not the cause:** Adapt optimistic seed (already no-op after 0108), display refresh gate alone (refresh only republishes; wipe requires Wh/km jump), settings hint copy, Live version math.

**Repro numbers (pre-fix):** prior window 47.3 km @ 353 Wh/km + 1% SoC after 0.5 km → weighted **426.6** → display **181**; + 2% over 2.7 km → weighted **~443** → **~173**.

## Reconciliation

**2026-09-26 tip:** Keep 0108 window/weights/cadence; stop short-hop SoC quanta from 8×-dominating.

### Changes
1. **`kMaxAbsWhPerKm`:** 2000 → **500** (~50 kWh/100) — above real winter/spirited driving; a 1% SoC step needs ≥2 km before acceptance.
2. **Keep-open on over-cap:** if `sample > maxAbs`, leave the segment open (do not reset SoC anchor) until distance dilutes Wh/km under the cap; reset only after ≥15 km pathological glitch.
3. **Units:** three cliff/keep-open/Adapt-like hop tests in `range_estimator_test.dart`.
4. **Settings hint:** unchanged (still honest ~50 km / last 10/3 / not Adapt).
5. **No Live bump** — stays **1.1.0+23**. Soft car T3. Did **not** implement 0112/0113/0115/0116.

### Verification
`flutter test` — `test/services/range_estimator_test.dart` (19), `test/widgets/battery_widget_test.dart`, `test/hud/battery_geometry_test.dart`. Analyzer clean on touched files.

## Soft / residuals

- Exact prior window contents unknown (yesterday 218 only); harness matches incident math.
- Soft: car T3 reconfirm on next drive.
