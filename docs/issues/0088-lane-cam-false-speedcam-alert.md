---
status: accept
labels: [speedcam, osm, ynavi, false-alarm]
created: 2026-09-22
satisfies: foundation
blocked-by: []
modules: [SpeedcamService, SpeedcamPackStore, SpeedcamSettings]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
tip: a1fd8d9+bd54d10
accepted: 2026-09-23
evidence: tmp/qa/0088-cut-bd54d10/
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
- [x] Root cause documented (OSM tag / YNavi type / both)
- [x] Optional filter in settings (default OFF) when YNavi enrich is on; OSM-only path clarified
- [x] T2 evidence: known lane-cam coords do not alert with filter default; alert when toggle ON
- [x] PDM ACCEPT after double-check

## FINDINGS (2026-09-23)

### Root cause (verified)
- YNavi `SpeedCamBroadcaster` puts cam tags into intent extra `type` (often contains `LANE`).
- Kotlin `SpeedcamYnaviReceiver` forwards `type`/`tags` into the Dart bridge map.
- Dart `ingestYnaviEvent` previously **dropped** `type` — `SpeedcamPoint` had no `camType` — so lane cams alerted as speedcams.
- OSM pack queries only `highway=speed_camera` / `enforcement=maxspeed` (no lane query). Primary false alarms are **YNavi-typed LANE**, not OSM.

### Fix
- `SpeedcamPoint.camType` preserved from `raw['type'] ?? raw['tags']`.
- `isLaneCam` = camType uppercased contains `LANE`.
- `SpeedcamConfig.alertLaneCams` default **false**; settings toggle under YNavi (enrich on only).
- `camsForAlert` excludes `isLaneCam` when YNavi alert path active and `!alertLaneCams` (map/enrich snapshot still keeps them). Danger binder already uses `camsForAlert`.

### Tip
`a1fd8d9` — unit tests: `test/services/speedcam_0088_lane_cam_test.dart`.

## ACCEPT notes
PDM ACCEPT 2026-09-23 — OFF/ON at pin + OSM/merge no-regress.
Evidence: `tmp/qa/0088-cut-bd54d10/`
