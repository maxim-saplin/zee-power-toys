---
status: done  # 81aedc5
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0031]
modules: [SpeedcamService]
tier: T1
owner: zee-dev
---

# 0032 — Proximity 500m + bearing/distance

Parent epic: [0029](0029-speedcam-osm-epic.md). **No YNavi** — OSM offline packs only.

## Block scope
Wire **pack cams** into `SpeedcamService` (not Fake-only samples). Host pose + pack → nearest cam with **distance + bearing**; `insideApproach` when distance ≤ **500 m**. Reload cams on pack update/install.

## Definition of Done
- [x] `DefaultSpeedcamService` loads cams from `SpeedcamPackStore` (fallback sample only if pack empty)
- [x] `SpeedcamDanger` includes `bearingDeg` + `distanceM` + `insideApproach`
- [x] Pack update/install refreshes Service cam list
- [x] FL approach toward a **pack** cam flips danger inside 500 m
- [x] Unit tests: bearing helper + pack-wired proximity
- [ ] Runtime T1: approach real pack cam (QA)

## Notes
Radar UI is 0033 — this block is geometry + Service wiring only.
