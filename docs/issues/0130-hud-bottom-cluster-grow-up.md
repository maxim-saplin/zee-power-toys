---
status: in-progress
labels: [hud, battery, geometry, regression]
created: 2026-11-20
satisfies: HUD battery rows keep their configured bottom anchor
blocked-by: []
modules: [HudRoot, BatteryWidget, battery_cluster_geometry]
tier: T1
owner: zee-dev
priority: now
filed-by: zee-dev
related: [0067, 0120, 0123]
---

# 0130 — Keep bottom HUD battery cluster anchored while rows grow

## Block scope

Keep the battery cluster inside the HUD Safe Area at `rightBottom` when
charging and media rows are added. New rows belong above the battery and
temperature content. The painted cluster must grow upward from its configured
bottom edge. Left and top placements must retain their current alignment.

## Investigation

Issue 0120 defined the product contract, but the implementation split that
contract across two layout stages. `HudRoot` grew and bottom-anchored the outer
slot, while `BatteryWidget` still laid a top-first `Column`. When the combined
rows exceeded their constraint, Flutter sized the column at the slot limit and
let its later battery rows continue downward. `batteryClusterSlotFracs` also
selected the larger of the charging and media heights instead of reserving
both row increments.

The result was not a bad bottom coordinate in the pure rect math. It was an
overflow path in widget layout: the outer slot stayed anchored, but the base
content could still paint or clip toward the bottom.

The vertical fix now gives `rightBottom` one stable available-height slot.
The slot keeps the configured bottom edge and fills upward. `BatteryWidget`
lays its content in normal top-to-bottom order; base battery/temperature
content remains at the bottom, while media and charging rows remain above it.

## Definition of Done

- [x] Charging and media height requirements are combined, then capped by the
      Safe Area.
- [x] At a bottom placement, the base battery/temperature rows stay at the
      configured bottom and optional rows extend upward.
- [x] Left/right top placements keep their current side and top behavior.
- [x] Focused geometry and widget tests fail without the fix.
- [x] Focused Flutter tests pass on T1 — 43/43 green 2026-11-20:
      `battery_bottom_anchor_overflow_test.dart`,
      `battery_geometry_test.dart`, `battery_media_stable_position_test.dart`,
      `battery_temp_row_test.dart`.
- [x] T1 visual comparison at 2.5×: idle and charging+media keep the base row
      on the bottom edge; the optional stack grows upward.
- [x] Focused battery and blinker tests pass on T1 — 69/69 green 2026-11-22,
      including the stable bottom-slot and 80%-horizontal-arrow checks.
- [ ] T3 screenshot confirms the live HUD boundary. Until supplied, runtime
      acceptance remains pending.

## Reconciliation

Code complete (T1 proof); T3 visual check pending next car session. This
issue narrows the existing 0120/0123 bottom-anchor contract; it does not
replace those issues.

## Notes

No T3 screenshot is available in this code-only loop. T3 is required for user
runtime acceptance.
