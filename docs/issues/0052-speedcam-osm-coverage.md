---
status: done
labels: [hud, speedcam, osm, harvest]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0047, 0046]
modules: [SpeedcamPackStore, SpeedcamPackMapPreview]
tier: T1
owner: zee-dev
---

# 0052 — Speedcam OSM coverage + denser map

## Block scope
Widen Overpass harvest beyond bare `highway=speed_camera` nodes to also pull
**device** members of `enforcement=maxspeed` relations (common BY/EU OSM
pattern), dedupe by `osm-{id}`, and keep merge/no-purge. Raise map preview
marker cap so typical packs (≤~2000) paint all markers with an honest caption
and a tighter CameraFit (not forced to the empty 300 km circle).

## Touches
- **Satisfies:** HUD · Speedcam
- **Modules:** `SpeedcamHarvestArea.overpassQl`, `FileSpeedcamPackStore.parseOverpassElements`, `SpeedcamPackMapPreview`
- **Prior:** [0047](0047-speedcam-harvest-300km.md) around-merge, [0046](0046-speedcam-dhu-map-preview.md) map preview, [0031](0031-speedcam-osm-packs.md) note on enforcement follow-up

## Definition of Done
- [x] Overpass QL keeps `node["highway"="speed_camera"](around:…)` **and**
      `relation["enforcement"="maxspeed"]` → `node(r…:"device")`
- [x] Parse: device nodes → cams; maxspeed/direction from device tags then
      relation tags; dedupe by `osm-{id}`; merge/no-purge unchanged
- [x] Unit tests: QL string, parse (+ relation fallback), dedupe
- [x] `kMaxMarkers` ≥ ~2000 so packs ≤~2000 paint all; caption omits
      "showing N" unless actually downsampled
- [x] CameraFit prefers cam (+ center) bounds over expanding to 300 km circle
- [x] Issue file `docs/issues/0052-speedcam-osm-coverage.md`
- [ ] Runtime T1 re-harvest + map screenshot (QA)

## Reconciliation
Mac `machineId` unavailable in this agent; built on box checkout of
`0044-publish-prep` at tip `d120c78`+.

## Notes
Do **not** start 0045. Harvest still merges by id — no purge outside the new
circle.
