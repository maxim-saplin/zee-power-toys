---
status: accepted
labels: [speedcam, ynavi, false-alarm, other-traffic-cams]
created: 2026-09-25
satisfies: foundation
blocked-by: []
modules: [SpeedcamService, SpeedcamYnaviReceiver, speedcam_alert_binder, speedcam_radar_widget, SpeedcamSettings]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
parent: [0088, 0092, 0099]
gate: armed-2026-09-25
tip: 62720d0
accepted: 2026-09-25
evidence: tmp/qa/0102-cut-62720d0/
evidence-rca: tmp/qa/0102-other-traffic-cams-rca/
---

# 0102 — Other traffic cams false speedcam alerts (3rd pass)

## Block scope
Maxim 2026-09-25 (car, morning): false speedcam alerts at four pins that are **traffic cams (mostly crossing control), not speedcams**:

| Pin | Lat, Lon |
|-----|----------|
| P1 | 53.913508, 27.426670 |
| P2 | 53.908212, 27.423801 (~32 m from 0088 pin 53.907996,27.424118) |
| P3 | 53.942187, 27.608319 |
| P4 | 53.949915, 27.616118 |

**HARD:** This is the **3rd attempt** (after 0088 / 0092). Complete RCA + repro must exist before code. Product name for the filter/toggle: **"Other traffic cams"** — **not** exclusively “lane cams”.

**ARMED 2026-09-25:** Maxim GO — implement now. RCA remains the contract: `tmp/qa/0102-other-traffic-cams-rca/`.

## RCA summary (2026-09-25 — verified, no code)

Full writeup: [`tmp/qa/0102-other-traffic-cams-rca/`](../../tmp/qa/0102-other-traffic-cams-rca/) — `RCA.md`, `REPRO.md`, `PINS.md`, `PRIOR-ATTEMPTS.md`.

**Verdict:** False alerts are **YNavi enrich** events co-tagged like `SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE` (crossing / other traffic control, often lim 60). Toys only mute `camType` containing **`LANE`** (`isLaneCam` / `alertLaneCams`). These stay in `camsForAlert` and sting. **OSM pack is not the feed** — harvest is only `highway=speed_camera` + `enforcement=maxspeed`; Overpass finds **no** such nodes near the pins.

**Named gap:** *YNavi non-LANE traffic-control co-tags treated as speedcams.*

**Why prior fixes failed:**
- **0088 / 0092:** muted only substring `LANE`; field pattern is `CROSS_ROAD_CONTROL` / `NO_STOPPING_CONTROL` / etc. ACCEPT fixtures used synthetic `LANE`, not live crossing tags.
- **0099:** facing mute-over-drop — wrong axis.
- **0090:** direction enrich NO-GO — unrelated.

## Product direction (when armed)

1. Classify **Other traffic cams** from YNavi `camType` when any of: `CROSS_ROAD_CONTROL`, `ROAD_MARKING_CONTROL`, `NO_STOPPING_CONTROL`, `TRAFFIC_CONTROL` (decide on `MOBILE_CONTROL` separately).
2. Default-mute on same surfaces as 0092 (`camsForAlert` / HUD / sound). Settings name **"Other traffic cams"** (fold or replace lane-only wording).
3. Co-presence of `SPEED_CONTROL` is **not** proof of a speedcam when a more-specific non-speed `*_CONTROL` tag is present.
4. Pure `SPEED_CONTROL` / `SPEED_CONTROL,POLICE` without other control tokens → remain speedcams.
5. Map/store may still show them (0099 lesson — don’t hide); gate **alert** path only.
6. T2 fixture those tags at P2 (and P1/P3/P4); assert no danger @ defaults; alert when toggle ON. Include negative control: synthetic `LANE` still muted.

## Definition of Done
- [x] Complete RCA + repro on disk (`tmp/qa/0102-other-traffic-cams-rca/`) — **done 2026-09-25**
- [x] Maxim OK / arm after RCA review (2026-09-25 — GO fix + Update/Reinstall scope)
- [x] Fix on tip with **"Other traffic cams"** naming (not lane-only) — classifier + mute + settings (`62720d0`)
- [x] Unit/fixture: `SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE` at P2 does **not** alert @ defaults; alerts when toggle ON; LANE control still muted (`test/services/speedcam_0102_other_traffic_cams_test.dart`)
- [x] T2 evidence P2 CROSS_ROAD mute/on + LANE neg + settings chrome — `tmp/qa/0102-cut-62720d0/` (optional roadside logcat SKIP)
- [x] Beta four-point; PDM ACCEPT after own double-check — ACCEPT `62720d0` (2026-09-25)

## Reconciliation
**2026-09-25 tip `62720d0`:** Extended `isOtherTrafficCam` beyond LANE-only (`CROSS_ROAD_CONTROL`, `ROAD_MARKING_CONTROL`, `NO_STOPPING_CONTROL`, `TRAFFIC_CONTROL` + LANE). Same alert surfaces as 0092 (`camsForAlert` / HUD / sound). Settings label **"Other traffic cams"** (prefs key `alertLaneCams` retained, default OFF). `MOBILE_CONTROL` left out (no strong in-repo field evidence). Map/store still shows muted cams. Pure `SPEED_CONTROL` / `SPEED_CONTROL,POLICE` remain speedcams. Live version **not** bumped.

## ACCEPT (PDM 2026-09-25)
Tip `62720d0` (1.1.0+19). QA T2 PASS (`tmp/qa/0102-cut-62720d0/`); beta four-point PASS (`FOURPOINT.md`); PDM own check PASS. Settings **"Other traffic cams"** default OFF. P2 `53.908212,27.423801` fixture `SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE`: mute → danger null + store keep; toggle ON → ~150 m / 60 sting. LANE still muted. Soft: **MOBILE_CONTROL** left out of taxonomy (still alerts @ defaults); **P1/P3/P4** not geo-cut on T2 (P2 class stands in); optional roadside `SPEEDCAM_DATA` logcat SKIP — do not block.

## Notes
- Live `1.1.0+19` / tip ≥ `3442724` exhibited the gap before `62720d0`.
- Residual: live tag dump at the four Minsk pins not captured morning of RCA — RCA used Overpass + prior QA logcat patterns + code path.
