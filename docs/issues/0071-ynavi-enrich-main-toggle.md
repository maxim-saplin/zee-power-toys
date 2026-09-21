---
status: tipped
labels: [speedcam, ynavi, product]
created: 2026-09-21
satisfies: YNavi cam enrich on main behind Speedcam setup toggle (default off)
tier: T2
owner: zee-dev
blocked-by: []
modules: [SpeedcamYnaviReceiver, SpeedcamService, Speedcam settings]
priority: now
filed-by: zee-pdm
---

# 0071 — YNavi enrich → main behind default-off toggle

## Why
Spike proved motion-backed YNavi cams (ghost idle-drive + route on Go). Maxim: ship productization now; default-off until reliable. PDM signs off.

## Scope
- Land spike wire (`source=ynavi`, ghost+route mutex, eventId dedupe, TTL kill) on **main** path for toys + matching ynavi tip.
- **Speedcam setup** master toggle: **YNavi enrich** — default **OFF**.
- When OFF: no collect, no alert from YNavi (OSM path unchanged).
- When ON: motion-backed collect per DoD (parked continuous fire not required).
- Docs: label ghost ≠ free-roam; Windshield stays closed.

## Out of scope
- Claiming reliability green before cancel→ghost (0076) + QA
- Artemis spike
- Nokia N1

## DoD
- [ ] Toggle OFF → zero YNavi ingest/alert; OSM still works
- [ ] Toggle ON + moving → YNavi cams into store with `source=ynavi`
- [ ] Default OFF on fresh install
- [ ] QA T2 cut + PDM sign-off

## Tip
- toys: see tip SHA in room (Speedcam setup → **YNavi enrich**, default OFF)
- ynavi spike tip remains `4d93cf2eb` (0076 revive) — Windshield closed; ghost ≠ free-roam
