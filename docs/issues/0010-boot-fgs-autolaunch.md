---
status: done
labels: [foundation, android, boot, fgs]
created: 2026-06-11
satisfies: foundation (ADR 0003 boot shim / 0002) + REQUIREMENTS auto-launch/background/persistence
blocked-by: [0004]
modules: [ConfigStore, app-shell]
tier: T2
---

# 0010 — Boot shim + foreground service + auto-launch

## Block scope
Make the app **start on boot, run in the background as a foreground service, and persist config** (REQUIREMENTS: "Auto launching, working in the background, persistence of configs"; ADR 0003 boot shim reads the plain ConfigStore before Flutter). Efficiency is a hard gate (ADR/PRINCIPLES): **no unnecessary wake locks**, engines/listeners only while needed.

## Touches
- **Satisfies:** Foundation — ADR 0003 (native boot shim reads `flutter.zee.config` plain JSON pre-Flutter), ADR 0002; REQUIREMENTS auto-launch/background/persistence.
- **Modules:** native boot + FGS, ConfigStore (read path).
- **ADRs:** 0003, 0002.

## Grounding — port from phase0
- Boot/auto-launch/FGS pattern + manifest entries: [`docs/knowledge/boot-fgs-apibrowser-diagnostics.md`](../knowledge/boot-fgs-apibrowser-diagnostics.md) (phase0 `boot/BootActions`, `BootNetworkWatchdog`, the BOOT_COMPLETED receiver + foreground service; what permissions/receivers/services the manifest needs).
- ConfigStore on-disk key: `flutter.zee.config` (plain JSON in `shared_prefs`) — the boot shim reads HUD-enabled / feature flags from it (see `docs/knowledge/flutter-conventions-riverpod-testing.md` §11).

## What to build
- **BootReceiver** (`android/.../boot/`): `RECEIVE_BOOT_COMPLETED` → start the foreground service (and the two-engine host as appropriate). Manifest receiver + permission.
- **ForegroundService**: a lean FGS with a minimal persistent notification (efficiency: no wake locks; the HUD engine starts only when the HUD is enabled per config). Reads `flutter.zee.config` (the boot shim's single privileged read, ADR 0003) to decide whether to bring up the HUD.
- **Config-driven boot policy**: a `hudEnabled` flag in `AppConfig` (default true) that the boot shim honors. The Dart ConfigStore already persists plain JSON; expose `hudEnabled` and gate the native HUD-engine spawn on it.
- Make `MainActivity`/host cooperate with the FGS (don't double-spawn engines; the Activity path for `flutter run` still works for the loop).
- A driver/ext path so the Feedback Loop can read boot/FGS state (e.g. is the FGS running; was config read).

## Definition of Done (runtime-confirmed on T2)
Inherits [PRINCIPLES.md](../PRINCIPLES.md). On `emulator-5554`:
- [x] Simulated boot starts the foreground service — confirmed by the orchestrator from a **cold** `am force-stop` (0 services) → boot broadcast → `ServiceRecord{...ZeeForegroundService}` `isForeground=true`. (Real-device `BOOT_COMPLETED`/`QUICKBOOT_POWERON` registered; `TEST_BOOT` alias used because `BOOT_COMPLETED` is a protected broadcast on API 32 from adb.) — artifact: dumpsys ServiceRecord.
- [x] The boot shim reads `flutter.zee.config` and honors `hudEnabled` (false → HUD engine not spawned, 1 isolate; true → spawned, 2 isolates). — artifact: logcat + whoami isolate count.
- [x] Config persists across kill+relaunch (ConfigStore; re-confirmed via the `hudEnabled` flag). — artifact: dumpState/bootState.
- [x] analyze clean; 86 tests; one APK. Principles: **no wake locks** (`dumpsys power` → our `Wake Locks: size=0`); FGS notification `IMPORTANCE_LOW`; HUD engine only when enabled. — artifact: dumpsys power.

## Reconciliation
- **SharedPreferences file**: `FlutterSharedPreferences` (confirmed in shared_preferences_android 2.4.26 `LegacySharedPreferencesPlugin.java`). On-disk: `<data>/data/com.zeepowertoys.zee_power_toys/shared_prefs/FlutterSharedPreferences.xml`. Key: `flutter.zee.config` (Flutter namespace prefix `flutter.` + `zee.config` from `shared_prefs_config_store.dart`).
- **targetSdk**: Flutter 3.44.1 defaults → `flutter.targetSdkVersion` resolves to **36** at build time (evidenced in dumpsys `targetSdkVersion:36`). The `FOREGROUND_SERVICE_DATA_SYNC` permission is therefore required (API 34+ mandatory; our manifest already declares it). On API 32 emulator it is harmless.
- **BOOT_COMPLETED protected broadcast** on API 32 production-build emulators: `adb shell am broadcast -a android.intent.action.BOOT_COMPLETED` is blocked (SecurityException from uid=2000). A `TEST_BOOT` alias (`com.zeepowertoys.TEST_BOOT`) is registered on the same receiver for smoke testing. This alias exercises the identical code path and is the method used in the T2 smoke run. The production `BOOT_COMPLETED` / `QUICKBOOT_POWERON` remain registered for real-device behaviour.
- **FGS export=false**: `ZeeForegroundService` is `exported="false"` (correct — only the BootReceiver and the app itself start it). `am start-foreground-service` from adb uid=2000 is therefore blocked, which is intentional.
- **No wake locks**: confirmed via `dumpsys power | grep "Wake Locks"` → `size=0`.
- **HUD engine gate**: `ConfigShim.readHudEnabled()` is called synchronously in `setupHud()` — this is the same SharedPreferences read the boot shim uses, so the Activity and the FGS always see the same decision. No Dart↔native round-trip needed at launch.
