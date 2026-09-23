---
status: open
labels: [speedcam, osm, ynavi, false-alarm, regression]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [SpeedcamService, SpeedcamPackStore, SpeedcamYnaviReceiver, Flutter preview]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: 0088
---

# 0092 — Lane cams still register / alert as 60 km/h speedcams (0088 regression)

## Block scope
Maxim 2026-09-23 (car / today): **plenty of lane cams** still register as speed cams and are treated as **60 km/h** speedcams. 0088 tip `a1fd8d9`+`bd54d10` ACCEPTed yesterday is insufficient in the field.

## Known pin (retest first)
- **53.907996, 27.424118** (Maxim 2026-09-22 / 0088) — lane cam that alerted as 60 km/h.
- Ask Maxim for more coords if this pin alone does not reproduce after tip.

## Investigate
1. Reproduce on T2 with Demo / live enrich at the known pin: does the pack store a SPEED (or 60) type instead of LANE?
2. Registration path: ingest → store → alert. Is `camType`/LANE dropped again on merge, OSM stamp, or UI?
3. Alert path: `alertLaneCams` default OFF — is it ignored, or are these **not** tagged LANE at ingest so the filter never sees them?
4. 60 km/h specifically: where does the speed limit get assigned for lane/enforcement cams?

## Definition of Done
- [ ] Root cause vs 0088 tip documented (regression vs new path)
- [ ] Fix on tip; known pin does **not** register/alert as 60 km/h speedcam with defaults
- [ ] QA FINDINGS + artifacts at 53.907996,27.424118 (and any extra coords Maxim supplies)
- [ ] Beta four-point; PDM ACCEPT after own double-check

## Notes
- Do not rubber-stamp 0088 ACCEPT notes — field evidence wins.
- Prefer `ext.zee` / `feedback_loop.py` / drive-zee-app over OCR taps (see 0094).
