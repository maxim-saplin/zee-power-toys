---
status: implemented
labels: [hud, speedcam, ynavi, gps]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0047]
modules: [SpeedcamService, YNaviCarAppHost, SpeedcamPackStore, AndroidGpsLocationSource]
tier: T3
owner: zee-dev
---

# 0050 — Speedcam pose from car GPS / YNavi

## Block scope
Speedcam host pose is only Demo / inject / drive-sim today. Car GPS never feeds
it. Harvest falls back to Minsk; on-road alerts do not track the car. YNavi
already receives live location via its Car App pipe (`IAppHost.sendLocation`) —
we only log it.

Wire **YNavi location** (and keep inject/demo working) into Speedcam host pose
+ harvest center. **No silent Minsk fallback** when a live pose or last-known
center exists; if neither exists, fail honestly.

## Hints (verified)
- `android/.../carapp/YNaviCarAppHost.kt` already calls `startLocationUpdates`
- `IAppHostStub.sendLocation` previously only `Log.v`'d
- Dart: `SpeedcamService.setHostPose` / `SpeedcamHostPose` (lat/lon/headingDeg/speedKmh)
- Harvest center in `speedcam_pack_store.dart` — prefer live pose; last-known;
  never invent Minsk when live GPS is available
- **T3 FAIL (2026-09-20):** Minimap on + `startLocationUpdates` SUCCESS +
  `updateTrip` ~1 Hz, but **0** `IAppHost.sendLocation` calls. After
  `clearHostPose`, `speedcam.host` stays null; harvest reuses prior Demo center
  (Minsk). Car GPS is Gomel ~52.46/30.81. YNavi often does not call
  `sendLocation` without an active nav route. AdaptAPI has **no** lat/lon
  sensors — Android `LocationManager` is the fallback.

## Definition of Done
- [x] `docs/issues/0050-speedcam-car-location.md` from this brief
- [x] Live YNavi location → Dart Speedcam pose (`zee/speedcam/location` EventChannel)
- [x] **Android LocationManager GPS fallback** → same EventChannel when YNavi
      is not delivering (`source=android_gps`); prefer YNavi when it does
- [x] `Log.i` on `sendLocation` + `speedcam/location` emit path (`adb logcat -s ZEE`)
- [x] Harvest centers on live pose when available; last-known otherwise; **honest error if neither** (no silent Minsk)
- [x] Demo / inject / drive-sim still work (manual pose holds off live until `clearHostPose`)
- [x] Tip on `0044-publish-prep`; push; car verify steps below
- [x] Analyze clean on touched files; harvest remains merge-no-purge

## Design
1. **Native YNavi:** `IAppHostStub.sendLocation` → `onLocation` →
   `YNaviCarAppHost.onLocation` → MainActivity EventChannel
   `zee/speedcam/location` map `{lat,lon,speedKmh?,headingDeg?,source:"ynavi"}`.
2. **Native Android GPS fallback:** `AndroidGpsLocationSource` uses
   `LocationManager` (GPS / network / passive). Started when Dart listens to
   the EventChannel. Emits `source:"android_gps"`. Yields for 5 s after any
   YNavi fix (no thrash). Immediate `getLastKnownLocation` on start.
3. **Dart:** `NativeSpeedcamLocation` listens and calls
   `setHostPose(..., fromLive: true)`.
4. **Manual hold:** inject / demo / drive set pose without `fromLive` and hold
   until `clearHostPose` so live GPS cannot stomp T1 tools.
5. **Harvest:** `centerLat/Lon` → prior pack center → `StateError` (no Minsk).
6. **Permissions:** `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` (system
   `sharedUserId` → granted on Zeekr DHU).

## Verify on car
1. Build/install tip; app start is enough (GPS fallback does **not** require
   Minimap / nav route). Optional: enable Minimap (binds YNavi →
   `startLocationUpdates`).
2. `adb logcat -s ZEE | grep -E 'sendLocation|speedcam/location|AndroidGps'` —
   expect `AndroidGpsLocationSource: start` + `speedcam/location source=android_gps`
   with Gomel-ish lat/lon (~52.46/30.81). If actively navigating, prefer
   `source=ynavi` lines when YNavi finally sends.
3. `ext.zee.speedcam` `clearPose`, then `ext.zee.dumpState` / readViewModel:
   `speedcam.host` lat/lon track the car (not null, not Minsk Demo).
4. HUD radar danger bearing/distance update while driving.
5. Speedcam settings → Harvest: center ≈ live pose (not Minsk).
6. Demo button still arms CRT; Stop clears and live may resume.
7. Without pose and without prior center, Harvest shows an honest error (no silent Minsk).

## Out of scope
- 0045 / 0051
- AdaptAPI lat/lon sensors (none documented / wired)
- Changing harvest merge-no-purge semantics
- Moving GPS into the FGS (`foregroundServiceType=location`) — Activity +
  system UID is enough for on-car HUD session

## Reconciliation
YNavi `sendLocation` remains the preferred live feed when it fires. Android
`LocationManager` covers the common case where cluster host gets trip updates
but never `sendLocation` without a nav route. Manual pose hold preserves T1
Demo/inject/drive. Minsk constants remain only as explicit fixture centers,
not an automatic harvest fallback.
