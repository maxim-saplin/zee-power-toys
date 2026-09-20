---
status: done
labels: [hud, battery]
created: 2026-09-20
satisfies: HUD · utility info — battery looks
blocked-by: [0062]
modules: [hud, battery_geometry]
tier: T1
owner: zee-dev
---

# 0063 — Battery polish: thinner outline + full-height %

## Block scope
PDM tip polish after [0062](0062-battery-pct-inside-dual-color.md):

1. **Thinner outline** — tone down the 0056 squarish bold stroke (`bodyH*0.14` → `*0.08`); keep tight corners.
2. **Battery + %** — percentage glyph height = **full inner fill height** (`batteryPackInnerH`), not `bodyH*0.48`.

Keep 0062 dual-color pack-sized clip (black on fill / white on empty).

## Touches
- **Modules:** `battery_geometry.dart` (`batteryPackStrokeW`, `batteryPackInnerH`), `battery_widget.dart` (`_DualColorPctLabel`)
- **Prior:** [0056](0056-battery-looks-pdm.md), [0062](0062-battery-pct-inside-dual-color.md)

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [x] Outline stroke thinner than 0056 bold; squarish radius unchanged
- [x] `pctInside` / `batteryText` fontSize = `batteryPackInnerH(bodyH)`
- [x] 0062 dual clip unchanged (pack-sized left/right at fill edge)
- [x] Geometry tests green; issue + BACKLOG
- [ ] On-car: `adb install -r` (parent) — thinner chrome + tall % inside pack

## Reconciliation
Visual-only polish on tip `0044-publish-prep`. Does not reopen 0056 look enum or 0062 clip math beyond shared stroke/pad constants.

## Notes
Fill/empty dual-color and amber/red low-battery black-on-fill unchanged.
