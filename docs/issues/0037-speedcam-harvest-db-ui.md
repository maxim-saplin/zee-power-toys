---
status: backlog
labels: [hud, speedcam, osm]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0036]
modules: [SpeedcamPackStore, DHU UI]
tier: T1
---

# 0037 — Harvest policies + DHU local DB state

## Block scope
- Harvest / refresh **policy** (not only manual Update): e.g. on-demand, interval, stale-after-N-days; show last fetch time / source / cam count.
- DHU UI for **local pack/DB state** (browsable or at least clear freshness + region + counts; optional list/sample of cams).
- Keep OSM-only; expand beyond single BY pack if thin (region label + refresh).

## Definition of Done
- [ ] Policy controls persist + apply (at least manual + “refresh if older than…”)
- [ ] DHU shows pack freshness / count / source honestly
- [ ] T1+T2 runtime-confirmed

## Notes
Maxim 2026-09-19: harvesting + cached-area refresh + DHU DB state.
