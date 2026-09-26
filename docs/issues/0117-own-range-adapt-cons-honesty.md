---
status: tip
tip: 7c9397b
labels: [hud, battery, range, honesty, window]
created: 2026-09-26
satisfies: Own Est. range window reshape — 3 bands (1× / 8× / mute last 1 km); no Adapt Cons seed
tier: T2
owner: zee-dev
blocked-by: []
modules: [RangeEstimator, RangeEstimateService, BatteryWidget]
priority: now
filed-by: zee-pdm
related: [0105, 0107, 0108, 0114]
parent: [0114]
gate: armed-2026-09-26
---

# 0117 — Own Est. window reshape (3 bands)

## Block scope

Maxim 2026-09-26 **HARD** product reshape of the own-range honesty window. Drop the prior Adapt±10% envelope force; reshape the ~50 km weighted window into **three bands** and keep own Est. as an own-window estimate (no Adapt Cons seed/projection).

| Field | Value |
|-------|-------|
| Live | **1.1.0+24** — hold until Maxim GO |
| Prior tip on main | `de2fc95` — Adapt Cons ±10% display projection (**park/revert before reshape tip**) |
| Prior window (0108) | 0..3 → 8×; 3..10 → 4×; 10..50 → 1× |
| New bands (HARD) | see Weights below |

### Pre-reshape note for zee-dev

Tip **`de2fc95`** (`fix(0117): Adapt Cons honesty for own Est (±10% envelope)`) is on `main`. It projects HUD Est from Adapt trip Cons when ≥15 kWh/100. That product direction is **superseded**. Before landing the reshape tip: **revert or park** `de2fc95` (restore own-window display path; keep `maybeSeedFromAdaptEfficiency` a no-op). Then implement the 3-band weights below on top of 0114 anti-cliff.

## Weights (HARD — Maxim 2026-09-26)

Distance from now inside the ~50 km window:

| Band | Weight |
|------|--------|
| **50 → 5 km** | **1×** |
| **5 → 1 km** | **8×** |
| **last 1 km** | **0** (mute) |

- Mute last 1 km: samples in 0..1 km from now contribute **zero** weight (short-hop noise / SoC quantum must not dominate).
- Composite still ~50 km; drop the old 3 km / 10 km / 4× middle band.

## Product rules

1. **Own window only** — Est = SoC% ÷ `weightedWhPerKm` from the 3-band window. **No Adapt Cons seed**, no display projection/clamp toward Adapt trip Cons.
2. Keep **0114 anti-cliff** (`kMaxAbsWhPerKm` / keep-open on over-cap); short-hop must not wipe Est.
3. Toggle ON always shows a value; no silent same-as-OFF (0107).
4. **Live hold +24** until Maxim GO (no version bump in this Block).

## DoD (product)

- [x] Window bands match HARD table: 50→5 **1×**, 5→1 **8×**, last 1 km **0** (mute).
- [x] **No Adapt Cons seed** / no Adapt±10% envelope force on display Est.
- [x] **0114 anti-cliff** preserved (`maxAbsWhPerKm` + keep-open).
- [x] **T2:** units prove new bands; short-hop last-1 mute; no cliff wipe.
- [x] Live stays **1.1.0+24** until Maxim GO.

## Soft / residuals

- Soft: car **T3** — may or may not close the ~2× gap vs Adapt envelope; if still low, pair **Adapt Cons vs `weightedWhPerKm`** for RCA (do not chase T3 in this Block).
- Invalid / missing Adapt Cons: irrelevant for display (own window only).
- Did **not** implement other open Blocks here.

## Reconciliation

**2026-09-26 tip:** Reverted/parked Adapt Cons display projection from `de2fc95` (`_displayAdaptConsKwhPer100`, Cons×10 in `_displayRange`, Adapt immediate refresh, Adapt±10% tests). Restored own-window display path; `maybeSeedFromAdaptEfficiency` remains intentional no-op. Reshaped weights to HARD 3 bands (50→5 **1×**, 5→1 **8×**, last 1 km **0** mute). Kept 0114 `kMaxAbsWhPerKm=500` + keep-open. Units green for new bands, last-1 mute, Adapt-no-project, and 0114 short-hop. Live still **1.1.0+24**. Soft: car T3 ~2× vs Adapt envelope not chased.

### Prior tip (superseded — reverted in this tip)

`de2fc95` had projected Est from Adapt Cons ≥15 kWh/100 (±10% envelope). That path is removed; own window only.

## Soft stand for ACCEPT

Leave ACCEPT to QA/PDM after T2 dens320 + units proof. Soft car T3 Maxim taste (envelope gap is soft RCA, not a hard fail).
