---
status: backlog
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0036]
modules: [SpeedcamService]
tier: T1
---

# 0038 — Host heading + camera-facing mute

## Block scope
Use host motion heading + OSM camera `direction` (when present): **do not alert** cams facing the opposite line of travel. Fail-open when facing unknown (phase0-style). Wire into danger selection + CRT/sting.

## Definition of Done
- [ ] FL can set host heading; opposite-facing cam muted inside 500 m
- [ ] Same-direction cam still alerts
- [ ] Drive-sim / inject tests cover both
- [ ] T1+T2 PASS

## Notes
Maxim 2026-09-19: account for camera and car motion direction.
