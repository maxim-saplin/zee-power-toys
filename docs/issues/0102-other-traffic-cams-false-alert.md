---
status: ready-for-agent
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
gate: maxim-ok-on-rca-before-code
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

**FIX GATE:** Do **not** start implementation until Maxim arms after reviewing `tmp/qa/0102-other-traffic-cams-rca/`.

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
- [ ] Maxim OK / arm after RCA review
- [ ] Fix on tip with **"Other traffic cams"** naming (not lane-only)
- [ ] T2 evidence: fixture `SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE` at P2 does **not** alert @ defaults; alerts when toggle ON; LANE control still muted
- [ ] Optional roadside confirm: logcat `SPEEDCAM_DATA` tags at P1–P4
- [ ] Beta four-point; PDM ACCEPT after own double-check (not rubber-stamp)

## Reconciliation
RCA only so far. Docs filed 2026-09-25. Code deferred behind Maxim gate.

## Notes
- Live `1.1.0+19` / tip ≥ `3442724` still exhibits the gap.
- Residual: live tag dump at the four Minsk pins not captured this morning — RCA used Overpass + prior QA logcat patterns (`SPEED_CONTROL,CROSS_ROAD_CONTROL,POLICE` ×80 in 0097 ghost logs) + code path. Roadside logcat before tip still valuable.
