---
status: in-progress
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0034]
modules: [SpeedcamService]
tier: T1
owner: zee-dev
---

# 0035 — Approach alert sound (game-like sting)

Parent epic: [0029](0029-speedcam-osm-epic.md). **No YNavi.**

## Block scope
Play a short Alien/CRT-style sting when `insideApproach` flips **false → true**. Disarm (no repeat) while still inside; re-arm after leaving (>500 m / 800 m test). Config toggle. HUD surface owns playback (relayed danger).

## Definition of Done
- [x] Edge-triggered sting on approach enter
- [x] No spam while staying inside; re-arms after exit
- [x] Config: sound on/off (Speedcam settings)
- [x] Unit/widget test for arm/disarm edge
- [ ] Runtime T1/T2 (QA: 200 arm / 800 disarm)
