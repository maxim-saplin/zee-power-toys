---
status: open
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

- [ ] RCA FINDINGS with root cause (code path + numbers)
- [ ] Tip fix + unit coverage for short-trip cliff
- [ ] T2 dens320: simulate ≈77% / short hop / ~24 kWh/100 → Est. moves plausibly vs prior 218 (no ~45 km wipe)
- [ ] Soft: car T3 reconfirm on next drive

## Soft / residuals

- Exact prior window contents unknown (yesterday 218 only); use inject harness + logs.
