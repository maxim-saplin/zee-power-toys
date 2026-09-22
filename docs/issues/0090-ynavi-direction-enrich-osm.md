---
status: blocked
labels: [speedcam, osm, ynavi, enrich, false-alarm, spike]
created: 2026-09-23
satisfies: foundation
blocked-by: []
modules: [SpeedcamPackStore, SpeedcamService, YNavi enrich, ynavi-zee SpeedCamBroadcaster]
tier: T2
owner: zee-dev
priority: after-0087
filed-by: zee-pdm
spike-verdict: NO-GO
tip: FINDINGS-only
---

# 0090 — YNavi direction enrich for OSM cams (no heading → false alerts)

## Problem (Maxim 2026-09-23)
Some OSM speedcams have **no direction**. Without heading, facing rules cannot apply and Maxim gets **false dangerous alerts**. YNavi cam feed often has direction — investigate whether we can **reliably** take direction from a matching YNavi cam and attach it to the OSM cam (enrich the OSM record / alert path), not invent headings.

## Investigate
- Match OSM ↔ YNavi by lat/lon proximity (existing merge radius?)
- When OSM lacks direction and YNavi match has a clear heading/facing, copy that into the merged / OSM-facing path used by `camsForAlert`
- Do **not** overwrite a good OSM direction with a bad YNavi one
- Do **not** invent direction when YNavi also lacks it
- Interaction with 0088: lane filter must stay pure-YNavi; OSM typing must not get silenced

## Product bar
Optional or automatic enrich is fine once reliability is proven — prefer **automatic when match is confident** (document confidence rule). Default must reduce false alerts, not create new ones.

## Definition of Done
- [x] Spike FINDINGS: can we get reliable direction from YNavi for undirected OSM cams? Match criteria + failure modes
- [ ] If yes: tip that enriches OSM (or osm+ynavi alert path) with YNavi direction only when OSM direction missing and YNavi heading known — **NO-GO (blocked)**
- [ ] T2 evidence: undirected OSM cam that previously false-alerted stops alerting when heading says opposite; still alerts when facing
- [ ] Unit tests for enrich / no-overwrite / no-invent
- [ ] PDM ACCEPT after own double-check of evidence (stringent — no tip-only LGTM)

## Spike verdict: **NO-GO** (2026-09-23)

**Do not ship a half-fix.** YNavi cannot supply camera facing/direction for geo-merged OSM cams today. Tip is FINDINGS-only.

### Where false alerts come from (toys)
1. OSM pack may omit `direction` (`SpeedcamPackStore._parseDirection` → null).
2. Dangerous mode (`SpeedcamPresenceMode.dangerous`) uses front cone **and** facing mute via `isCamRelevantForHost`.
3. Facing mute is **fail-open** when `cam.direction` is null/unparseable (`speedcam.dart`): undirected OSM cams still alert if inside the ±45° cone ahead — including opposite-carriageway cams → false dangerous alerts.
4. Host heading alone is not enough; facing needs **cam** direction.

### Can YNavi supply direction? **No (current stack)**
| Layer | What exists | Direction? |
|-------|-------------|------------|
| MapKit `com.yandex.mapkit.directions.driving.Event` | `polylinePosition`, `eventId`, `descriptionText`, `tags`, `location`, `speedLimit`, `annotationSchemeId` | **No** facing/azimuth/heading field |
| `EventTag` | SPEED_CONTROL, LANE_CONTROL, POLICE, … | Type only — **no** direction enum |
| `ynavi-zee` `SpeedCamBroadcaster` | SPEEDCAM_DATA extras: lat/lon/speedLimit/distance/type/tags/eventId/index/count/t_ms/source/feed | **Never** puts `direction` |
| toys `SpeedcamYnaviReceiver` | Forwards those extras to Dart | No direction key |
| toys `ingestYnaviEvent` | Builds `SpeedcamPoint` without `direction:` | Always null on pure YNavi |
| `mergeOsmWithYnavi` (~20 m) | Keeps `o.direction` only; stamps `source: osm+ynavi` | **Never** copies YNavi direction (nothing to copy) |

PDM assumption “YNavi cam feed often has direction” does **not** match the bridge/Event API. YNavi *route/ghost presence* is not a numeric facing.

### Smallest paths considered (rejected for tip)
1. **Ingest + merge copy YNavi → OSM direction** (toys-only) — blocked: YNavi points never have parseable `direction`.
2. **Alert-filter-only use of “YNavi heading”** — host heading already used; no cam facing from YNavi.
3. **Invent facing from route bearing at `polylinePosition`** (ynavi-zee) — violates issue rule *do not invent when YNavi lacks it*; rear/both-way cams wrong; needs APK rebuild + T2 proof.
4. **Presence proxy**: mute undirected OSM unless `osm+ynavi` when enrich+alert on — not “direction enrich”; risks **false negatives** where YNavi hasn’t emitted yet (TTL/coverage). Needs separate product decision + T2 coverage study — not this spike.

### Interaction with 0088
Lane filter stays pure-YNavi (`camsForAlert`). Direction enrich (if ever) must not stamp YNavi `LANE` onto OSM / `osm+ynavi` (merge already keeps `o.camType`).

### Blocked reason
No reliable YNavi **camera facing** source in Event API or SPEEDCAM_DATA. Copying null → no behavior change; inventing facing → disallowed / unreliable. Half-fix not tipped.

### Next dig (PDM pick)
A. **OSM-only:** improve pack direction coverage (relations / `traffic_sign` / Overpass) — toys pack path.  
B. **Product:** undirected-OSM gate when YNavi enrich on (presence proxy) — spike coverage false-negatives first.  
C. **Upstream research:** other MapKit / navikit surfaces with cam orientation (not `driving.Event`); only then extend broadcaster + toys ingest/merge with no-overwrite / no-invent tests.

### QA recipe (when a path is chosen)
1. Pack cam with **no** `direction` at known opposite-carriageway coords → today: Dangerous alerts in cone (baseline false).  
2. Same cam with OSM `direction` same as travel → muted (0038).  
3. After any enrich tip: undirected OSM + geo-merged YNavi must only mute/alert when facing is **known and tested**, never invented.  
4. Unit: enrich / no-overwrite OSM direction / no-invent when YNavi direction absent.  
5. 0088: lane cam still filtered; OSM speedcam not silenced by LANE stamp.
