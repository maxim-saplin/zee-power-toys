---
status: open
labels: [hud, blinker, speedcam, z-order]
created: 2026-11-20
satisfies: Right blinker stays visible while the speedcam radar is shown
blocked-by: []
modules: [HudRoot, BlinkerWidget, SpeedcamRadarWidget]
tier: T1
owner: zee-dev
priority: soon
filed-by: zee-dev
related: [0064]
---

# 0133 — Right blinker hidden behind speedcam radar; HUD radar ignores clearPose

## Observations (T1 2026-11-20, during the arrows redesign)

1. **Overlap:** at default placement (`vertFrac` 0.5, `sidePadFrac` 0.04) the
   right blinker mark rect (~x 671–700, y 283–301 on the 800×568 T1 HUD)
   sits fully inside the radar plate (~x 585–712, y 243–338). The radar
   paints above the blinker, so the right turn indicator is invisible
   whenever a speedcam is in range. Verified twice with
   `inject kind=blinker value=hazard` + `shot --surface hud`:
   left arrow renders, right arrow does not.
2. **Stale radar:** `ext.zee.speedcam action=clearPose` on the DHU did not
   clear the HUD radar — it kept rendering the last relayed snapshot
   (0.20 km cam) across `zee_run` restarts.

## Direction (not decided)

- Overlap: either z-order the blinker above the radar (a turn signal is
  higher-priority information) or nudge the default radar/blinker geometry
  apart. Product call needed.
- Stale radar: HUD-side speedcam relay sink should clear its snapshot when
  the pose clears.

## Definition of Done

- [ ] Hazard + radar-in-range: both blinker marks visible (T1 shot).
- [ ] `clearPose` clears the HUD radar (T1 shot pair).
