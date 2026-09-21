# Spike — YNavi as second cam feed into toys store

**Branch:** `spike/ynavi-second-cam`  
**Date:** 2026-09-21  
**Maxim:** CONDITIONAL GO (route-enrich). Free-drive NO-GO.

## DoD (unchanged summary)

See earlier tip `0e306e7` section. Payload yes; tip lacked Broadcaster; toys had no ingest; dedupe/stale proposed; free-drive blocked.

## Build progress

### ynavi `spike/ynavi-second-cam` @ `57cfb2383`
- Revived `SpeedCamBroadcaster` + `DistancesProviderImpl.start()` hook
- `source=ynavi` + `setPackage(com.zeepowertoys.zee_power_toys)`
- Free-drive left out

### toys (this branch)
- Runtime `SpeedcamYnaviReceiver` (FGS / Activity `ensureRegistered`)
- EventChannel `zee/speedcam/ynavi` → `NativeSpeedcamYnavi` → `DefaultSpeedcamService.ingestYnaviEvent`
- `SpeedcamPoint.source` + OSM↔YNavi ~20 m dedupe (`mergeOsmWithYnavi`)
- Unit: `test/services/speedcam_ynavi_merge_test.dart`

## Still owed (iterate)
1. Rebuild YNavi Zeekr APK from ynavi spike + install with toys debug
2. Route-sim T2: prove broadcasts land Dig/HUD without double blips
3. Dig surface for last bridge fire / session count
4. Stale prune for YNavi-only overlay (time policy)

## 0071 productization
YNavi enrich behind Speedcam toggle **default OFF**. Ghost = freeDriveRoute idle-drive, not true free-roam. Windshield closed.

