---
status: ready-for-agent
labels: [speedcam, ynavi, ui]
created: 2026-09-21
satisfies: Separate on-screen count for YNavi-sourced speedcam points
tier: T2
owner: zee-dev-beta
blocked-by: [0071]
modules: [SpeedcamPackStore, Speedcam map / settings UI]
priority: now
filed-by: zee-pdm
---

# 0072 — YNavi source points: separate counter

## Why
Need to see how many cams came from YNavi vs OSM — product visibility + debug.

## Scope
- Distinct counter for points with `source=ynavi` (not mixed into OSM-only total).
- Show on Speedcam setup and/or map chrome (EN+RU). Keep OSM count separate or total+breakdown — prefer **OSM count · YNavi count** side by side.
- Updates live as ingest/aging changes the set.

## DoD
- [ ] UI shows YNavi count ≠ OSM count when both present
- [ ] Zero YNavi when toggle off / empty store
- [ ] QA pixels + PDM sign-off
