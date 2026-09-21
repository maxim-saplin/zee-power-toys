---
status: done
labels: [foundation, config, install, signing]
created: 2026-09-20
satisfies: foundation
blocked-by: []
modules: [ConfigStore, signing, sharedUserId]
tier: T1
owner: zee-dev
---

# 0054 — Settings survive reinstall (keep-data via `adb install -r`)

## Block scope (PIVOT — Maxim HARD)

**Stop** the `/sdcard` durable mirror / backup harness. Settings must survive
deploy via genuine **keep-data** reinstall: plain `adb install -r` with
matching signature + `sharedUserId`. **`adb uninstall` = fail, not wipe.**

## Root cause

1. Main manifest declares `android:sharedUserId="android.uid.system"` (car /
   privileged). Debug overlay **removes** it (`tools:remove`) so stock AVD
   installs work.
2. Switching debug ↔ release, or Flutter-debug-signed ↔ AOSP/platform-signed,
   yields `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE` (often
   `tried to change user null`) and/or `UPDATE_INCOMPATIBLE`.
3. Agents then `adb uninstall` + reinstall — **that deletes**
   `/data/data/<pkg>/` including `FlutterSharedPreferences.xml` and the
   app-support speedcam pack cache. Prefs look “wiped on every deploy.”
4. Auto Backup / `allowBackup` does **not** survive uninstall. An `/sdcard`
   mirror papers over the wipe but is the wrong product path (Maxim: no
   mirror/harness).

## Fix (this tip)

- **Signing:** `android/gradle.properties` sets `useAospDebugKey=true`.
  Release/car builds sign with `android/tools/zeekr/androiddebugkey.jks`
  (alias `platformkey`). If the flag is on and the keystore is missing,
  **release assemble/package fails loudly** — never silent Flutter-debug
  fallback for car APKs that keep `sharedUserId`.
- **Install policy (agents):** **never `adb uninstall`** this package to
  recover from SHARED_USER / signature mismatch. Fix the APK (release +
  AOSP key, same `sharedUserId` as the installed build) and retry
  `adb install -r`. Uninstall fallback = **report fail**, do not wipe.
- **Removed:** `/sdcard/zee-power-toys/` mirror, ConfigShim sdcard fallback,
  `durable_store_paths`, restore-on-empty prefs, allowBackup / extraction
  rules added for the harness.

## Agent install (car / T3)

```bash
# Keystore present (see android/tools/zeekr/README.md)
flutter build apk --release -PuseAospDebugKey=true
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
# Expect AOSP/platform cert — not Flutter default debug.

adb install -r build/app/outputs/flutter-apk/app-release.apk
# If SHARED_USER_INCOMPATIBLE / UPDATE_INCOMPATIBLE:
#   → fix signing / build type (do NOT uninstall)
```

Debug APKs drop `sharedUserId` (AVD). Do **not** mix debug and release on
the car; that is the SHARED_USER trap.

## Prove keep-data

1. Install release (platform-signed) once: `adb install -r app-release.apk`
2. Set a pref in-app (e.g. toggle HUD / minimap setting)
3. Rebuild tip; `adb install -r` the new release APK **twice** (no uninstall)
4. Pref remains

## Definition of Done

- [x] Root-cause write-up (signing/sharedUser → uninstall wipe; not “prefs flaky”)
- [x] `useAospDebugKey=true` in `android/gradle.properties`; release fails if key missing
- [x] Durable `/sdcard` mirror + backup harness removed
- [x] Agent install documented: never uninstall; SHARED_USER → fix signing
- [x] Tip proves keep-data path (`install -r`, no wipe harness)

## Notes

Do not start 0045. Prior tip `33b3d6e` added the mirror approach; this pivot
replaces it.
