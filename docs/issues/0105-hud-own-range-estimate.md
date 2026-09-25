---
status: tipped
labels: [hud, battery, range, adapt]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [AdaptApiCarSignals, CarSignals, BatteryWidget / HUD battery line, settings]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
gate: armed-2026-09-25
parent: []
---

# 0105 — Own estimated range beside battery % (toggle + plain “how”)

## Block scope
Maxim 2026-09-25: **do not** trust the car’s Adapt range as the HUD primary (too optimistic). Show a **togglable own estimated range** in the **same line as battery percentage**. Agents must **design and verify a useful estimator** (not a placeholder). The settings toggle needs a **simple ruler / hint** that explains **how the estimate is calculated** in plain words.

## Product rules (HARD)
1. **Primary HUD figure = our estimate**, never Adapt `0x00100800` / `0x00101900` as the main number (those may appear in Diagnostics only if useful).
2. **Toggle** default **OFF**; even when ON, km is **hidden until ready** (≥~5 km moving history).
3. When ON and estimate ready: battery line like `72% · ~180 km` (soft tilde; no false precision).
4. **Settings copy:** short **ruler / help under the toggle** explaining the formula in everyday language (EN + RU). Must say OEM/car range is **not** primary.
5. Degrade cleanly: Simulated / no history / parked cold-open → no fake km; HUD must not jump wildly.

## Estimator — locked (PDM + zee-dev-beta 2026-09-25)
1. Usable Wh from **one pack constant** (`kUsablePackWh = 100000` = 100 kWh) — **not** OEM range.
2. Drop samples with SoCΔ≈0 / large time gap (`kMaxGapSeconds`).
3. Treat regen SoC↑ while moving as **valid drive** (not charge); plugged-in `charging=true` ignored.
4. Hide until ≥~5 km moving history, then `~N km` beside %.
5. Persist EWMA (+ moving km) across trips / process death (`zee.range_estimate` prefs).
6. Optional Adapt efficiency `0x00103100` may **seed** EWMA only; HUD primary remains ours.

## Definition of Done
- [x] Written estimator design in Reconciliation (inputs, window, units, when hidden)
- [x] Toggle in settings (EN/RU) with **plain-language how-it-is-calculated** help under the control
- [x] HUD battery line shows estimate when toggle ON and estimate ready; hidden/soft when not
- [x] Units / Simulated fixtures for: no-history → no km; after seeded trip → ~km appears; toggle OFF hides
- [ ] T2 Tablet dens 320 evidence — `tmp/qa/0105-cut-<sha>/` (settings chrome + HUD battery line)
- [ ] Soft note if car T3 live tune still owed
- [ ] Beta four-point; PDM ACCEPT after own check

## Reconciliation
**2026-09-25 tip:** Own-range EWMA beside battery %.
**Tip SHA:** 2744597

### Formula
```
usablePackWh = 100000 Wh          # single pack constant (not OEM range)
while speed ≥ 3 km/h and !charging:
  dist_km += speed × Δt           # Δt > 25 s → drop interval (gap)
  energy_Wh = −ΔSoC/100 × packWh  # SoC↓ consume; SoC↑ regen (valid)
  if segment ≥ 0.25 km and |ΔSoC| ≥ 0.4%:  # else keep segment open (no sample)
    sample = energy_Wh / segment_km
    ewma = 0.18·sample + 0.82·ewma   # clamp ewma ≥ 20 Wh/km
ready := movingKmAccum ≥ 5 km ∧ ewma set
range_km = (SoC/100)×packWh / ewma   # step-capped ~12 km/min
HUD: toggle OFF → hide; ON∧!ready → "72%"; ON∧ready → "72% · ~180 km"
```
Persist: `SharedPreferences` key `zee.range_estimate` (EWMA + movingKmAccum).
Adapt `0x00103100` seed hook via `CarSnapshot.efficiencyKwhPer100km` (native poll soft follow-up).
OEM range IDs **never** HUD primary.

### Defaults
- `BatteryConfig.showOwnRangeEstimate` = **false**
- Km hidden until ready even when toggled ON

## Notes
- Prefer shipping **0105 before or with 0104**; one Tablet — no parallel emu.
- Live bump only on Maxim GO after ACCEPT.
