---
status: cooking
labels: [speedcam, osm, ynavi, false-alarm]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [SpeedcamService, SpeedcamPackStore, SpeedcamSettings]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
---

# 0088 — Lane cam false speedcam alerts

## Block scope
Car (Maxim 2026-09-22): cam at **53.907996, 27.424118** alerted as speedcam at 60 km/h — it is a **lane cam**. Another down the road also false-alarmed.

## Investigate
- Why OSM and/or YNavi typed these as speedcams
- Distinguish lane / enforcement / speedcam in source tags

## Product option
When YNavi feed is enabled, add an optional **alert on lane cams** toggle — **default OFF** (filter lane cams out of alerts by default).

## Definition of Done
- [ ] Root cause documented (OSM tag / YNavi type / both)
- [ ] Optional filter in settings (default OFF) when YNavi enrich is on; OSM-only path clarified
- [ ] T2 evidence: known lane-cam coords do not alert with filter default; alert when toggle ON
- [ ] PDM ACCEPT after double-check
