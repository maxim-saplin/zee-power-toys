---
status: tipped
labels: [speedcam, flutter, preview, dx, osm, ynavi]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [Flutter map preview, SpeedcamPackStore, enrich merge]
tier: T1
owner: zee-dev
priority: now
filed-by: zee-pdm
---

# 0093 — Flutter preview: tap any DB cam → show metadata

## Block scope
Maxim 2026-09-23: in the **current Flutter preview**, click/tap **any** speedcam we have in the DB and show its **metadata**. Especially care about:
- OSM points **enriched with YNavi** (and any other YNavi-related fields stamped onto OSM)
- YNavi points that carry / merge **OSM** metadata (and vice versa)

## Product
- Tap a marker (or list row) → detail sheet / dialog / panel with full stored fields (id, source, camType, speed, facing/heading, tags, merge provenance, timestamps, lat/lon, etc.).
- Make OSM↔YNavi enrich visible at a glance (e.g. `source=osm+ynavi`, which fields came from which feed).

## Definition of Done
- [ ] Tap any cam in preview opens metadata UI with the stored record
- [ ] Enriched / merged cams clearly show OSM vs YNavi (and other) contributions
- [ ] Works for pure OSM, pure YNavi, and merged points
- [ ] T1/T2 screenshot evidence; QA FINDINGS; PDM ACCEPT

## Why now
Required to debug 0092 lane/speed mis-typing and future enrich bugs without adb dumps.

## Tip
Flutter preview: tap map marker or DB sample → bottom sheet with full `SpeedcamPoint` fields + OSM↔YNavi merge provenance. Live snapshot cams preferred on map (so `osm+ynavi` shows). Marker colors: coral OSM / purple YNavi / amber merged. ValueKeys: `speedcam-cam-tap-<id>`, `speedcam-db-sample-<id>`, `speedcam-cam-detail*`.
