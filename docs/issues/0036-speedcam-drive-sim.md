---
status: done  # 1fc47ad
labels: [hud, speedcam, t1, t2]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0035]
modules: [SpeedcamService, Feedback Loop]
tier: T1
owner: zee-dev
---

# 0036 — Simulated drive through pack cams

## Block scope
Continuous host motion sim (not teleport inject): FL drives pose along a **polyline** through ≥2 OSM/fixture pack cams. Along the path: distance/bearing update, CRT paints, sting arms on enter 500 m and re-arms on exit. T1 then T2.

## Definition of Done
- [x] `ext.zee.speedcam` drive / path command (or scripted FL sequence) moves host over time
- [x] ≥2 cams: enter → CRT+sting once; between cams silent when outside 500 m; second cam re-arms
- [ ] QA evidence: timeline + HUD shots along path (T1+T2)
- [x] No car required

## Notes
Maxim 2026-09-19: inject edges alone are not drive-proven.
