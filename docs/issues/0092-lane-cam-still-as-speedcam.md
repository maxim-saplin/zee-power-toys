---
status: tipped
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
tip: 0c0fd69
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
- [x] Root cause vs 0088 tip documented (regression vs new path)
- [x] Fix on tip; known pin does **not** register/alert as 60 km/h speedcam with defaults
- [ ] QA FINDINGS + artifacts at 53.907996,27.424118 (and any extra coords Maxim supplies)
- [ ] Beta four-point; PDM ACCEPT after own double-check

## Notes
- Do not rubber-stamp 0088 ACCEPT notes — field evidence wins.
- Prefer `ext.zee` / `feedback_loop.py` / drive-zee-app over OCR taps (see 0094).

## FINDINGS (2026-09-23)

### Root cause vs 0088 tip
0088 `a1fd8d9` filtered **pure YNavi** `isLaneCam` from `camsForAlert` only. `bd54d10` then **narrowed** that filter further and **refused to stamp** YNavi `LANE` onto `osm+ynavi` merges.

Field still saw 60 km/h because:

1. **HUD/sound bypass** — default `hudMode=any` recomputes presence from full `snap.cams` (radar blips + `resolvePresenceDanger`), and sound binder also started from `snap.cams`. Lane cams with MapKit `speedLimit`→60 still painted/armed as speedcams even when service `danger` was filtered.
2. **Merge typing** — when a YNavi `LANE_CONTROL` (often `SPEED_CONTROL,LANE_CONTROL,POLICE`, lim 60) geo-matches an OSM speedcam, merge kept `camType=null` so `camsForAlert` treated it as a normal speedcam.
3. **OSM at the known pin** — Overpass has **no** `highway=speed_camera` within ~500 m of 53.907996,27.424118; the pin is pure YNavi. So (1) alone explains the pin; (2) explains “plenty” of lane cams on OSM-covered roads.

### Fix
- `applyLaneCamAlertFilter` — shared drop of `isLaneCam` when `alertLaneCams` is off.
- `camsForAlert` filters **all** lane cams (not pure-YNavi only).
- Merge stamps YNavi `camType` onto `osm+ynavi` **only when** the YNavi match is a lane cam.
- Radar + alert binder use the same filter for presence/blips/sound.
- Harness: `ext.zee.setConfig` accepts `ynaviEnrich` / `ynaviAlert` / `alertLaneCams` / `hudMode` / `soundMode`.

### Tip
`0c0fd69` — unit: `test/services/speedcam_0088_lane_cam_test.dart` (0092 group).
