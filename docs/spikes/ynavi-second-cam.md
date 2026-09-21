# Spike — YNavi as second cam feed into toys store

**Branch:** `spike/ynavi-second-cam` (toys) · revive patch on ynavi `spike/ynavi-second-cam`  
**Date:** 2026-09-21  
**Refs:** zee_hud_2 `_speedcam/{YNAVI_RESEARCH,EXPLORATION,STATUS,INTENT}.md` · ynavi `origin/speedcam` / `d13d97e41` (`SpeedCamBroadcaster`) · toys epic 0029 (OSM-only cut)  
**Scope:** answer PDM 5 DoD Qs → go/no-go. **No main ship.**

## TL;DR / go/no-go

| Verdict | Meaning |
|---|---|
| **CONDITIONAL GO** | Route-only YNavi Windshield feed as **enrichment beside OSM** (city-gap fill while a route is engaged). |
| **NO-GO** | Free-drive YNavi harvest, offline-DB framing, or replacing OSM. Free-drive is **verified blocked** (MapKit native path; Windshield does not fire without routing). |

Product bar candidate: **route-enrich OSM is OK**; free-drive is **not** a readiness bar (prior + confirmed).

---

## DoD answers

### 1. Current tip: route-sim → `SPEEDCAM_DATA` still has lat/lon (+ limit/id/distance)?

**Payload contract (yes) — from `SpeedCamBroadcaster` on ynavi `origin/speedcam`:**

| extra | type | notes |
|---|---|---|
| `lat`, `lon` | double | event location |
| `speedLimit` | int km/h | |
| `effectiveSpeedLimit` | double | optional |
| `speedLimitStatus` | string | optional |
| `distance` | double m | along-route; may be `-1` |
| `type` / `tags` | string | EventTag names |
| `eventId` | string | YNavi id (receiver falls back to `lat_lon_type`) |
| `index` / `count` | int | batch markers; `count=0` = heartbeat, no cam |
| `t_ms` | long | broadcaster wall clock |

Action: `com.zeekr.phase0.SPEEDCAM_DATA`. Phase0 receiver infers `source=ynavi_native` when batch extras present (broadcaster itself does **not** always put `source`).

**Tip gap:** maxim-saplin/ynavi-zee **`main` tip has no `custom_java/` / `SpeedCamBroadcaster`** (`d13d97e41` is **not** an ancestor of current `main`). Bridge must be **revived onto a spike branch** from `origin/speedcam` (retarget package / action extras as needed for `com.zeepowertoys.zee_power_toys`). Live route-sim re-proof is owed on that spike APK — not claimed for current Published tip.

### 2. Toys ingest as `source=ynavi` into pack/store beside OSM?

**No — not on tip.** Epic 0029 explicitly dropped YNavi / `SpeedCamDataReceiver`. Toys pack pipeline is Overpass → `FileSpeedcamPackStore` with pack meta `source` default `'overpass'`. `SpeedcamPoint` is `{id,lat,lon,maxspeed?,direction?}` — **no per-point source**. No runtime broadcast receiver in toys.

**Spike design (if GO):** runtime-register receiver (Android 12+; same lesson as Phase0 FGS), map extras → points with `source=ynavi` (or `ynavi_native`), merge into store **beside** OSM rows — not a second pack file that replaces Overpass.

### 3. Dedupe OSM vs YNavi (eventId + geo) — no duplicate points?

**Not built.** Toys today: `SpeedcamHarvestArea.mergeById` (OSM id upsert only). Phase0: upsert by `eventId`, bump `seenCount`.

**Spike rule (proposed):**

1. Prefer match on normalized `eventId` when both sides have one.
2. Else geo-bucket (~15–25 m) + compatible limit → treat as same physical cam; keep OSM id as canonical, attach `sources=[osm,ynavi]` / lastYnaviSeen.
3. Never double-draw HUD blips for the same physical cam.

### 4. Stale / refresh policy (no negative signal from YNavi)?

**Structural:** YNavi stream is **push-only additive**. Empty batch = heartbeat only — **never** “camera removed.” Cannot age-out from YNavi alone.

**Spike policy (proposed):**

- OSM remains source of truth for the base pack (existing freshness / harvest).
- YNavi rows: `lastSeen` bump on each fire; **time-prune** YNavi-only overlays (e.g. 7–14 d session cache, or 90 d Phase0-style) — **never** delete OSM rows because YNavi went quiet.
- Heartbeat (`count=0`) updates bridge-liveness only.

### 5. Product bar: route-enrich OSM OK, or free-drive required?

**Route-enrich OSM = OK bar.** Free-drive **required = NO**.

Evidence (zee_hud_2 `_speedcam`, 2026-05-09 controlled): free-drive `onRoadEventsChanged` **never** fires; second bridge / MapView walks **inert**; cameras in free-drive stay inside `libmaps-mobile.so`. Frida native is the only remaining speculative path — out of spike bar.

---

## Readiness assessment

| Piece | Tip today | Spike work |
|---|---|---|
| YNavi broadcaster APK | Missing on `main` | Revive from `origin/speedcam` → `spike/ynavi-second-cam` |
| Toys receiver + store merge | Absent (0029) | New Kotlin receiver + Dart/store merge w/ source + dedupe |
| OSM gap fill while routed | N/A | Feasible; needs route engagement |
| Free-drive parity with YNavi voice | Blocked | Do not gate feature |
| Replace OSM | Contradicts 0029 + no negative signal | Reject |

## Next (only if PDM accepts CONDITIONAL GO)

1. ynavi spike: revive `SpeedCamBroadcaster` + DistancesProvider hook; retarget extras/`setPackage` for toys app id; tip spike APK.  
2. toys spike: runtime receiver → pack/store merge + dedupe + prune policy + Dig “bridge last fire”.  
3. T2 route-sim proof (Tablet 12L / car): routed corridor with known cam → toys shows `source=ynavi` without duplicating OSM blip.  
4. **No** free-drive acceptance criterion.

## Explicit non-goals

- Baking Mac/AVD paths into docs (use gitignored `ENV.md`).  
- FINDINGS debt on `main`.  
- Shipping on `main` from this spike.
