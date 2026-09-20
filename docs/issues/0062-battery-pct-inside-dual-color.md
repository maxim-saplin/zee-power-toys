---
status: done
labels: [hud, battery]
created: 2026-09-20
satisfies: HUD · utility info — battery looks
blocked-by: [0056]
modules: [hud, BatteryConfig]
tier: T1
owner: zee-dev
---

# 0062 — Battery + % inside pack (dual-color clip)

## Block scope
Polish the **Battery + text** look so the percentage sits **inside** the pack
icon with a dual-color / masked effect:

- **Black** text on the filled portion
- **White** (near-white) text on the empty portion
- Text clipped at the continuous-fill boundary

## Touches
- **Satisfies:** REQUIREMENTS — battery looks (PDM "Battery + text")
- **Modules:** `battery_widget.dart`, `battery_geometry.dart`, `BatteryConfig`
  (`batteryText` → `pctInside`)
- **ADRs:** 0001 (emissive HUD)
- **Prior:** [0056](0056-battery-looks-pdm.md)

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [x] `BatteryLook.batteryText` maps to `BatteryStyle.pctInside` (default look)
- [x] Dual-color %: black on fill / white on empty, pack-sized dual `ClipRect` at fill edge
- [x] Fill-edge math shared with painter (`batteryPackFillEdgeX`)
- [x] Widget + geometry tests green
- [x] Issue + BACKLOG
- [ ] On-car: Battery + text shows inside % with color split (`adb install -r`)

## Reconciliation
0056 left "Battery + text" as pack + % **below** (`outline` + `both`). PDM
wanted % **inside**; 0062 flips the look mapping and adds the clip effect.
Other looks (Battery / bars / Just text) unchanged. Tip stays on
`0044-publish-prep`; car install = `adb install -r` only (0054).


## FAIL write-up (Maxim / PDM, 2026-09-20)

On-car: **black on fill (left) OK**; **white on empty (right) invisible**.

**Do not** invert fill to white / swap so fill becomes white. Keep green fill
L→R; black on fill; white on empty; clip at fill edge.

**Root cause:** `_DualColorPctLabel` clipped black with pack-space `fillEdge`
while `ClipRect` sized to the Text (centered). `fillEdge` often ≥ text width →
black covered the whole glyph; empty-side white never showed. Empty side also
had no clip of its own.

**Fix:** `StackFit.expand` so clip X matches pack body; clip white with
`_RightOfEdgeClipper(fillEdge)` and black with `_LeftEdgeClipper(fillEdge)`.

## Notes
Amber/red low-battery fill still uses black-on-fill (readable on amber/red).
