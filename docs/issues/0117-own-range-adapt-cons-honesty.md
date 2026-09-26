---
status: tip
tip: d3e6c44
labels: [hud, battery, range, honesty, adapt]
created: 2026-09-26
satisfies: Own Est. range must track SoC% ÷ Adapt trip kWh/100 (honesty vs envelope)
tier: T2
owner: zee-dev
blocked-by: []
modules: [RangeEstimator, RangeEstimateService, BatteryWidget]
priority: now
filed-by: zee-pdm
related: [0105, 0107, 0108]
parent: [0114]
gate: armed-2026-09-26
---

# 0117 — Own Est. range must track SoC% ÷ Adapt trip Cons (honesty)

## Block scope

Maxim 2026-09-26 evening product honesty gap on Live **1.1.0+24** (0114 shipped):

| Field | Value |
|-------|-------|
| Live | **1.1.0+24** (0114 Wh/km abs cap 500) |
| SoC | **≈77%** |
| Adapt trip Cons | **≈24.2 kWh/100** |
| Envelope (SoC ÷ Cons × 100) | **≈318 km** |
| HUD own Est. | still ~**2× lower** (persisted ~353 Wh/km → ~218 km class) |

0114 fixed the short-trip SoC-quantum cliff (218→173 after 2.7 km). It does **not** force Adapt trip Cons honesty: HUD Est. can remain unreasonably low vs the back-of-envelope `(batteryPct / Adapt_kWh_per_100) * 100`.

## RCA (code @ tip `8d23842`)

- `lib/services/range_estimator.dart`: `Est = (socPct/100)*100000 Wh / weightedWhPerKm`; ~50 km window; last 3 km **8×**, last 10 km **4×**.
- `maybeSeedFromAdaptEfficiency` is an intentional **no-op** since 0108 (Adapt must not optimistic-seed the composite).
- Envelope match needs Wh/km ≈ Adapt trip Cons (e.g. 24.2 kWh/100 = **242 Wh/km** → 77% → ~**318 km**). Persisted ~**353 Wh/km** explains **218 vs 318** — own window alone, no Adapt Cons projection/clamp.

## Product rules

1. When Adapt trip Cons (`efficiencyKwhPer100km` / signal) is **valid**, HUD own Est. must read close to the envelope `(batteryPct / Adapt_kWh_per_100) * 100`.
2. Prefer projecting from Adapt trip Cons (or blend/clamp weighted SoC Wh/km **toward** Adapt) over an opaque own-only window when Cons is trustworthy.
3. Keep **0114 anti-cliff** (short SoC quantum must not wipe Est.).
4. Toggle ON always shows a value; no silent same-as-OFF (0107).
5. Keep 0108 window/weights/cadence intent unless a documented Divergence replaces them for honesty.
6. **No Live bump** until Maxim GO.

## DoD (product)

- [x] When Adapt trip Cons is valid and **≥ 15 kWh/100**, HUD Est. is within **±10% of the envelope** `(batteryPct / Adapt_kWh_per_100) * 100` (testable band; e.g. 77% / 24.2 → envelope ~318 → Est in **~286–350 km**).
- [x] Implementation prefers Adapt trip Cons projection or blend/clamp of weighted SoC Wh/km toward Adapt over opaque own-only window when Cons valid.
- [x] 0114 anti-cliff preserved (units + short-hop fixtures still pass).
- [x] Toggle ON always shows a value; no silent same-as-OFF.
- [ ] Units + T2 dens320 Tablet proof; soft car T3 Maxim taste on same stretch — HUD ≈ envelope.
- [x] Live bump only after Maxim GO.

## Soft / residuals

- Exact band may tighten after T3 taste (±15 km alternate only if ±10% proves noisy at low Cons — prefer ±10% when Cons ≥15).
- Invalid / missing Adapt Cons: fall back to own window (do not invent Cons).
- Soft: car T3 Maxim taste later — do not chase T3.
- Did **not** implement other open Blocks here.

## Reconciliation

**2026-09-26 tip:** Project HUD Est from Adapt trip Cons when trustworthy; keep 0108 window + 0114 anti-cliff.

### Changes

1. **Display projection (0117):** when Adapt Cons is valid and **≥ 15 kWh/100**, `_displayRange` uses `Wh/km = Cons × 10` so Est = `(SoC%/Cons)×100` (rounding). Tracks SoC/Cons directly (no 1 km hold on this path).
2. **Composite untouched (0108):** `maybeSeedFromAdaptEfficiency` stays a no-op — Adapt never writes into the ~50 km weighted window.
3. **Fallback:** missing / invalid / Cons **< 15** → own weighted Wh/km + 0108 ~1 km refresh cadence.
4. **0114 kept:** `kMaxAbsWhPerKm = 500` + keep-open on over-cap; short-hop fixtures still pass.
5. **Units:** ±10% envelope, fallback, and Adapt+short-hop honesty tests in `range_estimator_test.dart`.
6. **No Live bump** — stays **1.1.0+24**.

### Verification

`flutter test` — `test/services/range_estimator_test.dart` (22), `test/widgets/battery_widget_test.dart`, `test/hud/battery_geometry_test.dart`. Analyzer clean on touched Dart.

**Divergence from 0108:** Adapt Cons now drives **display** Est when ≥15 kWh/100. Still does **not** seed or replace the composite window. Own-window weights/cadence unchanged when Cons untrusted.

## Soft stand for ACCEPT

Leave ACCEPT to QA/PDM after T2 dens320 proof. Soft car T3 Maxim taste.
