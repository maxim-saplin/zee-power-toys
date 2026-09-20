---
status: done
labels: [hud, speedcam]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0040, 0042]
modules: [SpeedcamRadarWidget]
tier: T1
owner: zee-dev
---

# 0058 — Approaching cam blip/dot missing on HUD

## Symptom
Alien (and Default label path): sound + proximity label update when radar
comes up, but **approaching cam visual blip/dot missing** on HUD for on-route
cams. Demo often OK.

## Root cause
Alien painter treats `bearingDeg` as **relative to host forward** (screen-up),
but blips were built from **absolute** host→cam bearings (clockwise from
north). When heading ≠ north, on-route cams fall outside the ±50° wedge gate
(`if (rel.abs() > wedgeHalf) continue`) → CRT shows with km readout but **no
dots**. Sound/label use danger distance independently → still work.

## Fix
- Convert absolute → heading-relative when building blips (`relativeBearingDegrees`).
- Demo bearings stay relative (no host heading fold).
- Clamp **highlight** blips to the fan edge so on-route contact never vanishes.
- Default arrow uses the same relative bearing.

## Definition of Done
- [x] Relative bearing fold + highlight clamp
- [x] Unit test: eastbound host + cam ahead paints inside wedge
- [x] Issue + BACKLOG
- [ ] Runtime Demo + live QA
