---
status: in-progress
labels: [hud, speedcam]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0037]
modules: [SpeedcamService]
tier: T1
owner: zee-dev
---

# 0038 — Host heading + camera-facing mute

## Block scope
Host motion heading + OSM camera `direction`: mute cams facing the **same** way we travel (other line); alert when cam faces into our traffic (~opposite heading). **Fail-open** if heading or facing unknown.

## Definition of Done
- [x] FL pose supports `headingDeg`; opposite-line cam muted inside 500 m
- [x] Same-direction (cam faces us) still alerts
- [x] Unit tests + drive/inject coverage
- [ ] T1+T2 PASS (QA)
