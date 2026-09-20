---
status: done
labels: [foundation, config, install]
created: 2026-09-20
satisfies: foundation
blocked-by: []
modules: [ConfigStore, ConfigShim, SpeedcamPackStore]
tier: T1
owner: zee-dev
---

# 0054 — Settings survive reinstall / deploy wipe

## Block scope
Settings (and speedcam pack cache when easy) are lost on every deploy.
Root-cause the install path, then make prefs durable across reinstall when
possible.

## Root cause — **yes, deploy was wiping data**

1. Main manifest declares `android:sharedUserId="android.uid.system"` (car /
   privileged). Debug overlay **removes** it (`tools:remove`) so stock AVD
   installs work.
2. Switching debug ↔ release (or platform-signed ↔ debug-signed) →
   `INSTALL_FAILED_SHARED_USER_INCOMPATIBLE` (and sometimes
   `UPDATE_INCOMPATIBLE`).
3. Operators then `adb uninstall` + reinstall — **that deletes**
   `/data/data/<pkg>/` including `FlutterSharedPreferences.xml` and
   `getApplicationSupportDirectory()` pack cache.
4. `allowBackup` alone does **not** survive uninstall; Auto Backup only helps
   on restore from cloud/device-transfer.

## Fix
- Mirror `AppConfig` JSON to **`/sdcard/zee-power-toys/config.json`** on every
  `setConfig` / successful `load`.
- On `load` with empty prefs (fresh install): restore from the mirror.
- Native `ConfigShim` falls back to the same mirror when prefs are empty so
  boot/`hudEnabled` survive wipe.
- Speedcam pack cache root → durable `…/speedcam_packs/`.
- Manifest: `allowBackup=true` + backup/data-extraction rules (belt-and-suspenders).
- Prefer `adb install -r` when signatures/`sharedUserId` match; uninstall only
  when incompatible.

## Definition of Done
- [x] Root cause documented (uninstall after SHARED_USER / signature mismatch)
- [x] Durable config mirror + restore on empty prefs
- [x] ConfigShim durable fallback
- [x] Pack cache on durable path
- [x] allowBackup + extraction rules
- [x] Unit test: mirror write + restore after empty prefs
- [ ] Runtime T2/T3: set prefs → uninstall → reinstall → prefs back (QA)

## Reconciliation
Mac `machineId` unavailable; built on box checkout of `0044-publish-prep`
after 0053 tip `932aae9`.

## Notes
Do not start 0045. Next: 0055 Zee HUD 2 minimap info overlay.
