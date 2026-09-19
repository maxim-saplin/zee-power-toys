---
status: in-progress
labels: [hud, speedcam, osm]
created: 2026-09-19
satisfies: HUD · Speedcam
blocked-by: [0036]
modules: [SpeedcamPackStore, DHU UI]
tier: T1
owner: zee-dev
---

# 0037 — Harvest policies + DHU local DB state

## Block scope
- Harvest / refresh **policy**: manual-only vs refresh-if-stale (N days); persist; apply on DHU open / Update.
- DHU UI: region, source, last fetch, age, cam count, sample cam list (local DB honesty).
- OSM BY pack remains default region label.

## Definition of Done
- [x] Policy controls persist + apply (manual + “refresh if older than…”)
- [x] DHU shows pack freshness / count / source / sample cams
- [x] Unit tests for stale check
- [ ] Runtime T1+T2 (QA)
