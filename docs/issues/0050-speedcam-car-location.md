---
status: implemented
labels: [hud, speedcam, ynavi, gps]
created: 2026-09-20
satisfies: HUD · Speedcam
blocked-by: [0047]
modules: [SpeedcamService, YNaviCarAppHost, SpeedcamPackStore, AndroidGpsLocationSource, NativeSpeedcamLocation]
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
- **T3 FAIL follow-up (0050 HARD):** Manifest had FINE/COARSE but **no**
  `requestPermissions` / permission_handler. Fresh install → GPS source silent
  no-op → no live pose → Harvest stuck on prior Minsk. After ADB `pm grant`,
  native emits `android_gps` @ Gomel — product must not depend on ADB. After
  `clearPose`, host stayed null while native was still emitting — need
  re-emit lastKnown after clearPose / permission grant.

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
- [x] **0050 HARD:** Runtime location prompt via app UI (Activity.requestPermissions
      / `zee/speedcam/location_ctl`) before GPS starts / when opening Speedcam or
      tapping Harvest
- [x] **0050 HARD:** Honest UI if denied — do not silent-fail to Minsk prior center
- [x] **0050 HARD:** README UI↔CLI — location = runtime (Settings or in-app), ADB grant = lab only
- [x] **0050 HARD:** Re-emit lastKnown after clearPose / permission grant so
      `fromLive` poses resume (Dart cache + native)

## Design
1. **Native YNavi:** `IAppHostStub.sendLocation` → `onLocation` →
   `YNaviCarAppHost.onLocation` → MainActivity EventChannel
   `zee/speedcam/location` map `{lat,lon,speedKmh?,headingDeg?,source:"ynavi"}`.
2. **Native Android GPS fallback:** `AndroidGpsLocationSource` uses
   `LocationManager` (GPS / network / passive). Started when Dart listens **and**
   runtime permission is granted. Emits `source:"android_gps"`. Yields for 5 s
   after any YNavi fix. Immediate `getLastKnownLocation` on start / reemit.
3. **Runtime permission (0050 HARD):** MethodChannel `zee/speedcam/location_ctl`
   — `hasPermission` / `requestPermission` / `ensureGpsStarted` /
   `reemitLastKnown`. `MainActivity.requestPermissions` shows the system dialog;
   on grant → start GPS + reemit. Speedcam settings calls `ensurePermission` on
   open and before Harvest.
4. **Dart:** `NativeSpeedcamLocation` listens and calls
   `setHostPose(..., fromLive: true)`. Hooks `DefaultSpeedcamService.onHostPoseCleared`
   to re-apply cached pose + native reemit after `clearHostPose`.
5. **Manual hold:** inject / demo / drive set pose without `fromLive` and hold
   until `clearHostPose` so live GPS cannot stomp T1 tools.
6. **Harvest:** live pose → prior pack center → `StateError` (no Minsk). If
   permission **denied**, UI shows `speedcamLocationDenied` and does **not**
   harvest around a stale Demo/Minsk prior.
7. **Permissions:** Manifest declares `ACCESS_FINE_LOCATION` +
   `ACCESS_COARSE_LOCATION`; **runtime** grant via in-app dialog (or Settings).
   ADB `pm grant` is lab-only.

## Verify on car (no ADB grant)
1. **Fresh install** (or revoke location in Settings). Build/install tip —
   do **not** `pm grant` location.
2. Open **Speedcam** settings — expect system location permission dialog
   (or Settings redirect if permanently denied). Allow it.
3. `adb logcat -s ZEE | grep -E 'sendLocation|speedcam/location|AndroidGps|requesting ACCESS'` —
   expect permission grant path, `AndroidGpsLocationSource: start`, and
   `speedcam/location source=android_gps` with Gomel-ish lat/lon (~52.46/30.81).
4. Tap **Harvest** — center ≈ live pose (not Minsk). Deny permission on a
   fresh install → honest error string, no harvest on prior Minsk.
5. `ext.zee.speedcam` `clearPose`, then `ext.zee.dumpState` / readViewModel:
   `speedcam.host` resumes from live (not null, not Minsk Demo) via lastKnown
   reemit — without waiting for the next GPS tick alone.
6. HUD radar danger bearing/distance update while driving.
7. Demo button still arms CRT; Stop clears and live may resume.
8. Optional: enable Minimap (binds YNavi → prefer `source=ynavi` when it sends).

## Out of scope
- 0045 / 0051
- AdaptAPI lat/lon sensors (none documented / wired)
- Changing harvest merge-no-purge semantics
- Moving GPS into the FGS (`foregroundServiceType=location`) — Activity +
  system UID is enough for on-car HUD session
- `permission_handler` pub package (Activity.requestPermissions is enough)

## Reconciliation
YNavi `sendLocation` remains the preferred live feed when it fires. Android
`LocationManager` covers the common case where cluster host gets trip updates
but never `sendLocation` without a nav route. Manual pose hold preserves T1
Demo/inject/drive. Minsk constants remain only as explicit fixture centers,
not an automatic harvest fallback. Runtime permission is product; ADB grant
is lab.
