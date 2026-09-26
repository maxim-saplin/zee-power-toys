---
status: ready-for-agent
labels: [hud, battery, range, honesty, adapt, float-soc, cons1]
created: 2026-09-26
satisfies: Dual range Est. — float SoC own-trip + Adapt Cons1; DHU picks primary
tier: T2
owner: zee-dev
blocked-by: []
modules: [AdaptApiCarSignals, CarSignalSnapshot, CarSnapshot, RangeEstimator, RangeEstimateService, BatteryWidget / DHU settings]
priority: now
filed-by: zee-pdm
related: [0105, 0107, 0108, 0114, 0117]
parent: [0117]
gate: armed-2026-09-26
---

# 0118 — Float SoC + Cons1 dual Est. (own vs Adapt-Cons)

## Block scope

Maxim 2026-09-26 evening product: ingest two **already-proven** Adapt signals from `zee_hud_2` oncar logs, stop truncating SoC, and give the driver **two** range estimates they can compare and choose as HUD primary.

| Signal | ID | Role |
|--------|-----|------|
| Float SoC | `0x00404000` `TYPE_EV_BATTERY_PERCENTAGE` | 0.1% ticks — **stop** `toInt()` truncation |
| Cons1 | `0x00103100` `DYN_EGY_CONS1` | Adapt trip / dyn energy cons **kWh/100 km** |

Keep **0117** three-band own-trip window and **0114** anti-cliff. Own Est. becomes float SoCΔ÷distance; Cons Est. is a separate Adapt-Cons-derived figure. DHU settings: mode picker (which Est. drives the primary HUD number) + **both** values visible near the existing own-range toggle.

**Docs-only tip** — do not implement code in this commit.

## Evidence (cite — already proven)

| Claim | Ref |
|-------|-----|
| Fractional SoC **85.7** | `zee_hud_2/logs/phase0/oncar/2026-02-19_run-01/t1_tracka_energy_snapshot.json` (`battery_pct=85.7`) |
| Fractional SoC **85.8** | same run `t1_trackb_energy_sweep_charging.json` (`0x00404000` last_value=85.8) |
| Cons1 live | `2026-02-20_*` / `2026-02-23_run-01` dumps; `CarApiCatalog` Energy Cons 1 `0x00103100` kWh/100km; EnergyProbe `energy_cons_1` → `DYN_EGY_CONS1` |
| Truncation today | `AdaptApiCarSignals.kt` `value.toInt()` / `soc.toInt()` → `publishBatteryPct(Int)`; Dart `CarSnapshot.batteryPct` / `range_estimator` `socPct` are **int** |

## Product rules (HARD)

1. **Native publishes float SoC** from `0x00404000` (0.1% resolution). HUD may still **display** int % if desired; estimator must use float.
2. **Cons1 ingested into Dart** (`0x00103100` → snapshot field; reject sentinels). Cons2 (`0x00103200`) unused this Block.
3. **Own Est.** = float SoC remaining ÷ weighted Wh/km from SoCΔ÷distance over the **0117** 3-band window:
   - **50 → 5 km** @ **1×**
   - **5 → 1 km** @ **8×**
   - **last 1 km** mute **0**
   - Keep **0114** anti-cliff (`kMaxAbsWhPerKm` / keep-open on over-cap).
4. **Cons Est.** ≈ `(soc/100) × packWh / (cons_kWh_per_100 × 10)` (Wh remaining ÷ Wh/km from Cons1). Use float SoC remaining.
5. **DHU settings:** user picks which Est. drives the **primary** HUD range number (**own-trip** vs **Adapt-Cons-derived**).
6. **DHU settings:** display **BOTH** estimates near the existing own-range toggle so the driver can compare.
7. **No Live bump** until Maxim GO after ACCEPT.

## DoD (product)

- [ ] Native publishes **float SoC** (and HUD can still show int % if desired).
- [ ] **Cons1** ingested into Dart (valid kWh/100; sentinels rejected).
- [ ] **Own Est.** uses float SoC + **0117** bands + **0114** anti-cliff.
- [ ] **Cons Est.** from Cons1 + SoC remaining (formula above; pack constant unchanged).
- [ ] **DHU settings:** mode picker (primary = own vs Cons) + **both** values visible near the own-range toggle.
- [ ] Units / T2 dens320 proof for float ingest, Cons Est math, mode switch, dual display; soft car T3 taste.
- [ ] Live bump only after Maxim GO.

## Soft / residuals

- Soft: car **T3** taste (Maxim) — which primary feels honest on a real stretch.
- Soft: **Cons lag** (trip average updates slowly; do not thrash HUD on every Cons tick).
- Soft: **Cons2** unused this Block.
- Invalid / missing Cons1 → Cons Est. hidden / unavailable; Own Est. still works.
- Did **not** implement other open Blocks here.

## Out of scope

- Reverting 0117 bands or 0114 anti-cliff.
- Seeding / clamping Own Est. toward Adapt Cons (0117 own-window-only stays for the own path).
- Cons2, OEM Adapt range IDs as HUD primary.
- Live version bump in this Block.

## Reconciliation

_Filled when building._
