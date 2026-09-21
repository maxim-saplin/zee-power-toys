---
status: implemented
labels: [hud, speedcam, osm, dhu]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0037]
modules: [SpeedcamPackStore, DHU UI]
tier: T1
owner: zee-dev
---

# 0046 — Speedcam DHU map preview of pack cams

## Block scope
On Speedcam settings (DHU), show a **map / map-like preview** of cameras in the loaded
local cam cache (lat/lon markers) so Maxim can see where cams are — not only the
sample list + radar.

Folded with [0047](0047-speedcam-harvest-300km.md): preview shows the merged
on-device cache (last harvest ≈ 300 km of host pose, plus retained older cams).

## Definition of Done
- [x] Map or map-like preview on Speedcam settings with pack cam positions
- [x] Works with full caches (~hundreds); don't freeze UI (downsample)
- [x] Honest empty state when no pack / empty cache
- [x] Does **not** replace radar; lives with Local DB / harvest section
- [x] Prefer lightweight CustomPaint (no new map dep); OSM harvest already in store
- [x] T1 screenshotable at DHU scale

## Out of scope
- Multi-region country packs (see 0047)
- Replacing HUD radar / Alien CRT
