---
status: ready-for-agent
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

- [ ] Estimator redesign is implemented and unit-tested for:
  - empty and less-than-ready history;
  - a full 50 km window with oldest history discarded as new distance arrives;
  - recent 3 km and 10 km being overweight relative to older kilometres;
  - one-kilometre refresh cadence (no displayed-value thrash between boundaries);
  - SoC drop plus distance producing consumption in the ballpark of Adapt trip
    figures on representative fixtures.
- [ ] Settings help is updated in EN and RU: approximately 50 km of driving is
  used, the most recent kilometres count more (mention 10 and 3 where space
  allows), and this is not the car's Adapt range.
- [ ] 0107 polish still applies if already landed: always-show marker when ON,
  no `~`, smaller `km`, smaller `%`, and enough width for one line. Do not
  regress it.
- [ ] QA FINDINGS T2 dens320 + PDM ACCEPT.
- [ ] Soft: car T3 live honesty check.
- [ ] No Live bump until Maxim GO after ACCEPT.

## Reconciliation

### Proposed composite

Use moving-driving segments as the history record. Each accepted record carries
`distanceKm` and the net battery energy represented by its SoC change. Energy is
computed with the single explicit constant from 0105:

```text
usablePackWh = 100000 Wh
segmentWh = -deltaSoC / 100 * usablePackWh
segmentWhPerKm = segmentWh / distanceKm
```

Ignore parked/charging intervals, telemetry gaps, and records too small to be
meaningful. Regen while moving remains part of the observed drive history;
plugged-in charging is excluded. Keep enough records to cover the most recent
50 km and trim by distance, so a short final segment does not accidentally
replace a whole older trip.

Calculate one weighted energy-vs-distance ratio rather than averaging displayed
ranges. The initial design uses three distance bands:

```text
older:     km 10..50       weight 1x per km
recent:    km 3..10        weight 4x per km
latest:    km 0..3         weight 8x per km
weightedWhPerKm = sum(weight * segmentWh) / sum(weight * segmentKm)
```

The exact constants may be tuned against the fixtures, but the invariants are
fixed: all usable history is bounded to about 50 km; the last 10 km outweighs
the older 40 km; and the last 3 km is the strongest signal. A robust estimator
must avoid letting one malformed SoC jump or a near-zero-distance sample
 dominate the ratio; tests should cover the chosen rejection/clamp behavior.

Project from the current SoC with the same pack constant and keep our estimate
as the HUD primary:

```text
remainingWh = currentSoC / 100 * usablePackWh
rangeKm = remainingWh / weightedWhPerKm
```

Do not use Adapt range IDs as the primary value. An Adapt efficiency reading may
be shown for diagnostics or comparison, but it must not silently seed a result
that contradicts the observed SoC/distance history.

### Readiness and refresh

Hide the numeric estimate until the estimator has a meaningful ready window (the
existing approximately 5 km readiness rule may remain unless fixtures require a
clearer minimum). Accumulate moving distance continuously, but publish a new
rounded/display value only after another approximately 1 km boundary. Telemetry
samples within that boundary may update the stored history, but must not make the
HUD jump every tick. Persist the history/state needed across process death in
the existing range-estimate preferences path.

### Settings hint

Keep the copy short and non-technical. EN should say that the estimate uses
about the last 50 km of driving and gives more weight to the most recent 10 km,
especially the last 3 km; it is our estimate, not the car's Adapt range. RU
should convey the same meaning in natural plain language rather than exposing
EWMA, alpha, or pack math.

## Notes for agents

- Hand off the outcome, not line edits: tune and document the weighted composite
  against observed SoC drop × distance × visible Adapt kWh/100 on the same
  stretch.
- Keep HUD primary = ours; Adapt range IDs are never primary.
- Prefer cooking after 0106 then 0107 if one Tablet is contested.
- This issue may supersede the 0105 EWMA math while preserving its toggle,
  persistence, and 0107 presentation contract.
