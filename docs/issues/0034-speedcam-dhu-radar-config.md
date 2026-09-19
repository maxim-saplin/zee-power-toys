---
status: in-progress
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0033]
modules: [SpeedcamService, ConfigStore]
tier: T1
owner: zee-dev
---

# 0034 — DHU large radar + config

Parent epic: [0029](0029-speedcam-osm-epic.md). **No YNavi.**

## Block scope
DHU **large** Alien/CRT radar (zoom-out vs HUD slot) on Speedcam settings, plus config: HUD radar on/off, display range (zoom). Live pack cams as blips when host pose is set.

## Definition of Done
- [x] Large CRT on Speedcam settings (`dhu-speedcam-radar`)
- [x] Zoom-out range config (display metres > 500 approach)
- [x] HUD radar enable toggle (wired to HudRoot)
- [x] Multiple cam blips within range; nearest/danger highlighted
- [x] Widget test
- [ ] Runtime T1/T2 pixels (QA)
