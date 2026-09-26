---
status: open
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

- [ ] When Adapt trip Cons is valid and **≥ 15 kWh/100**, HUD Est. is within **±10% of the envelope** `(batteryPct / Adapt_kWh_per_100) * 100` (testable band; e.g. 77% / 24.2 → envelope ~318 → Est in **~286–350 km**).
- [ ] Implementation prefers Adapt trip Cons projection or blend/clamp of weighted SoC Wh/km toward Adapt over opaque own-only window when Cons valid.
- [ ] 0114 anti-cliff preserved (units + short-hop fixtures still pass).
- [ ] Toggle ON always shows a value; no silent same-as-OFF.
- [ ] Units + T2 dens320 Tablet proof; soft car T3 Maxim taste on same stretch — HUD ≈ envelope.
- [ ] Live bump only after Maxim GO.

## Soft / residuals

- Exact band may tighten after T3 taste (±15 km alternate only if ±10% proves noisy at low Cons — prefer ±10% when Cons ≥15).
- Invalid / missing Adapt Cons: fall back to own window (do not invent Cons).
- Did **not** implement other open Blocks here.
