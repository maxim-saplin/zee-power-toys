---
status: ready-for-qa
labels: [hud, battery, range, honesty, adapt]
created: 2026-09-25
satisfies: Own estimated range that reconciles with observed SoC / distance / consumption
tier: T2
owner: zee-dev
blocked-by: []  # prefer after 0106 then 0107 (one Tablet); may supersede 0105 EWMA math
modules: [RangeEstimator, RangeEstimateService, BatteryWidget / settings help]
priority: now
filed-by: zee-pdm
related: [0105, 0107]
parent: [0105]
---

# 0108 — Own-range honesty: 50 km window + heavier last 10/3 km

## Block scope

Maxim 2026-09-25 ~21:59 Minsk wants the HUD own-range estimate to reconcile with
what the car actually did, rather than behave like the current opaque EWMA.
For example, HUD readings of 81%/16 km/21.1 kWh/100 → 303 km and
78%/29.3 km/20.3 kWh/100 → 218 km are an honesty failure; Adapt math would
remain around 384 km on a 100 kWh pack.

The replacement is a composite estimate, not the OEM Adapt range and not a
single opaque EWMA:

1. Keep approximately the last 50 km of moving-driving history.
2. Weight the most recent kilometres much more than older history: the last
   10 km must dominate the older part, with the last 3 km dominant within that
   recent band.
3. Reconcile energy and distance from SoC deltas and one explicit usable-pack
   constant, then project remaining range from current SoC.
4. Recompute and update the displayed value on approximately each 1 km of
   moving distance, not on every telemetry tick.
5. Explain the window and recency weighting in the EN and RU settings help in
   plain words. State that this is not the car's Adapt range.

## Definition of Done

- [x] Estimator redesign is implemented and unit-tested for:
  - empty and less-than-ready history;
  - a full 50 km window with oldest history discarded as new distance arrives;
  - recent 3 km and 10 km being overweight relative to older kilometres;
  - one-kilometre refresh cadence (no displayed-value thrash between boundaries);
  - SoC drop plus distance producing consumption in the ballpark of Adapt trip
    figures on representative fixtures.
- [x] Settings help is updated in EN and RU: approximately 50 km of driving is
  used, the most recent kilometres count more (mention 10 and 3 where space
  allows), and this is not the car's Adapt range.
- [x] 0107 polish still applies if already landed: always-show marker when ON,
  no `~`, smaller `km`, smaller `%`, and enough width for one line. Do not
  regress it.
- [ ] QA FINDINGS T2 dens320 + PDM ACCEPT.
- [ ] Soft: car T3 live honesty check.
- [ ] No Live bump until Maxim GO after ACCEPT.

## Reconciliation

**2026-09-25 tip:** Replace opaque EWMA with weighted ~50 km composite (heavier last 10 / last 3).

### Changes
1. **Estimator:** `RangeEstimator` keeps moving-driving segments trimmed to ~50 km. Weighted Wh/km bands: 0..3 → 8×/km, 3..10 → 4×/km, 10..50 → 1×/km. `rangeKm = (SoC/100)×100000 / weightedWhPerKm`.
2. **Refresh:** Display value publishes on first ready sample, then only after ~1 km further moving (no per-tick thrash). History still updates continuously.
3. **Exclusions:** Parked/charging, gaps >25 s, tiny SoCΔ, absurd Wh/km rejected. Regen-while-moving kept. Adapt efficiency **does not** seed the composite; HUD primary remains ours.
4. **Persist:** `zee.range_estimate` stores segment history (v2); migrates 0105 EWMA prefs into one synthetic segment.
5. **Help EN/RU:** ~50 km window, more weight last 10 especially last 3; not Adapt range.
6. **0107 polish preserved:** pending `… km`, no `~`, typography, wider slot. No Live bump (`1.1.0+21`).

### Verification
`flutter test` — `test/services/range_estimator_test.dart` (empty/short, 50 km trim, 3/10 overweight, 1 km refresh, Adapt-ballpark fixtures, regen/charge/gap, persist+migrate), `test/widgets/battery_widget_test.dart`, `test/hud/battery_geometry_test.dart`.

**Divergence:** None from scope; change-only. Soft: car T3 live honesty check.

## Notes for agents

- Hand off the outcome, not line edits: tune and document the weighted composite
  against observed SoC drop × distance × visible Adapt kWh/100 on the same
  stretch.
- Keep HUD primary = ours; Adapt range IDs are never primary.
- Prefer cooking after 0106 then 0107 if one Tablet is contested.
- This issue may supersede the 0105 EWMA math while preserving its toggle,
  persistence, and 0107 presentation contract.
