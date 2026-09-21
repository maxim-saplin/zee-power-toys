---
status: tipped
labels: [speedcam, map, ui]
created: 2026-09-21
satisfies: Speedcam map — expand/collapse + go to my location
tier: T2
owner: zee-dev
blocked-by: []
modules: [Speedcam map preview UI]
priority: now
filed-by: zee-pdm
---

# 0075 — Speedcam map: expand/collapse + my location

## Why
Map chrome needs quick full-size and recenter — Maxim ask.

## Scope
- **Expand / collapse** control on Speedcam map (collapsed = current compact; expanded = usable large map).
- **Go to my location** button — centers on host pose (fail loud if no fix; no silent Minsk).
- Works with OSM + YNavi markers; don’t break existing preview.
- EN+RU affordances / a11y labels.

## DoD
- [ ] Expand ↔ collapse pixels T2
- [ ] My-location recenters when pose known; clear empty state when not
- [ ] QA + PDM sign-off

## Tip
See room SHA — expand/collapse + my-loc on Speedcam pack map; no silent Minsk.
