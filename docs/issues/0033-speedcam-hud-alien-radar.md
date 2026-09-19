---
status: in-progress
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0032]
modules: [SpeedcamService, HudHost]
tier: T1
owner: zee-dev
---

# 0033 — HUD right Alien/CRT radar + Preview

Parent epic: [0029](0029-speedcam-osm-epic.md). **No YNavi.**

## Block scope
HUD **right-side** Alien/CRT green radar driven by pack proximity (bearing + distance). Show when `insideApproach` (≤500 m). Same widget in DHU **Config Preview** with forced demo danger so pixels are visible without FL inject.

## Definition of Done
- [x] `SpeedcamRadarWidget` — CRT sweep + blip at bearing/range + distance readout
- [x] Wired into `HudRoot` right slot (below battery, no windshield chrome when idle)
- [x] Config Preview forces demo approach blip
- [x] Widget/unit tests for visible radar when danger inside approach
- [ ] Runtime T1/T2 pixels (QA)

## Notes
DHU large radar + config = 0034. Sound = 0035.

## Fix tip (post-dc8e220)
Live HUD CRT needs DHU→HUD `speedcam` relay (same as CarSignals). HUD isolate is a relay sink (`FakeSpeedcamService.applyRelaySnapshot`); pack+pose stay on DHU.

