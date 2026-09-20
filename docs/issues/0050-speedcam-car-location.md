---
status: implemented
labels: [hud, speedcam, ynavi, gps]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0047]
modules: [SpeedcamService, YNaviCarAppHost, SpeedcamPackStore]
tier: T3
owner: zee-dev
---

# 0050 — Speedcam pose from car GPS / YNavi

## Block scope
Speedcam host pose is only Demo / inject / drive-sim today. Car GPS never feeds
it. Harvest falls back to Minsk; on-road alerts do not track the car. YNavi
already receives live location via its CarApp pipe (`IAppHost.sendLocation`) —
we only log it.

Wire **YNavi location** (and keep inject/demo working) into Speedcam host pose
+ harvest center. **No silent Minsk fallback** when a live pose or last-known
center exists; if neither exists, fail honestly.

## Hints (verified)
- `android/.../carapp/YNaviCarAppHost.kt` already calls `startLocationUpdates`
- `IAppHostStub.sendLocation` currently only logs
- Dart: `SpeedcamService.setHostPose` / `SpeedcamHostPose` (lat/lon/headingDeg/speedKmh)
- Harvest center in `speedcam_pack_store.dart` — prefer live pose; last-known;
  never invent Minsk when live GPS is available

## Definition of Done
- [x] `docs/issues/0050-speedcam-car-location.md` from this brief
- [x] Live YNavi location → Dart Speedcam pose (`zee/speedcam/location` EventChannel)
- [x] Harvest centers on live pose when available; last-known otherwise; **honest error if neither** (no silent Minsk)
- [x] Demo / inject / drive-sim still work (manual pose holds off live until `clearHostPose`)
- [x] Tip on `0044-publish-prep`; push; car verify steps below
- [x] Analyze clean on touched files; harvest remains merge-no-purge

## Design
1. **Native:** `IAppHostStub.sendLocation` → `onLocation` → `YNaviCarAppHost.onLocation`
   → MainActivity EventChannel `zee/speedcam/location` map
   `{lat,lon,speedKmh?,headingDeg?,source:"ynavi"}`.
2. **Dart:** `NativeSpeedcamLocation` listens and calls
   `setHostPose(..., fromLive: true)`.
3. **Manual hold:** inject / demo / drive set pose without `fromLive` and hold
   until `clearHostPose` so live GPS cannot stomp T1 tools.
4. **Harvest:** `centerLat/Lon` → prior pack center → `StateError` (no Minsk).

## Verify on car
1. Build/install tip; enable Minimap (binds YNavi → `startLocationUpdates`).
2. `adb logcat -s ZEE | grep -E 'sendLocation|speedcam/location'` — locations flow.
3. `ext.zee.dumpState` / readViewModel: `speedcam.host` lat/lon track the car.
4. HUD radar danger bearing/distance update while driving.
5. Speedcam settings → Harvest: center ≈ live pose (not Minsk).
6. Demo button still arms CRT; Stop clears and live may resume.
7. Without pose and without prior center, Harvest shows an honest error (no silent Minsk).

## Out of scope
- 0045
- Standalone Android `LocationManager` GPS (YNavi pipe is the live source)
- Changing harvest merge-no-purge semantics

## Reconciliation
YNavi `sendLocation` is the live feed (Car App host already starts updates).
Manual pose hold preserves T1 Demo/inject/drive. Minsk constants remain only as
explicit fixture centers, not an automatic harvest fallback.
