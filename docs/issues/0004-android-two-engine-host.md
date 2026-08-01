---
status: done
labels: [foundation, android, two-engine]
created: 2026-06-11
satisfies: foundation          # implements ADR 0001 / 0005 / 0002 (Android edge) / 0003 (relay transport)
blocked-by: [0001, 0003]
modules: [HudHost, app-shell, relay]
tier: T2
---

# 0004 — Android two-engine host (T2)

## Block scope
Bring the **same** Dart `lib/` to the Android emulator (T2) as **two engines via `FlutterEngineGroup`** — DHU on the primary display + HUD on a secondary-display `Presentation` (ADR 0001/0005) — with the cross-isolate relay running over a **native bridge** (the per-tier transport of ADR 0003; `desktop_multi_window` is T1-only), and the VM-service Feedback Loop reaching **both** isolates on Android (ADR 0004). One APK, no flavors (ADR 0002). CarSignals stays the Dart fake here (the native AdaptAPI/simulator adapter is the next Block); inject keeps flowing over the VM channel on T2.

## Touches
- **Satisfies:** Foundation — ADR 0001 (two engines + Presentation), 0005 (own the host), 0003 (native relay transport), 0002 (single APK on the Android edge), 0004 (VM loop reaches both isolates on Android).
- **Modules:** HudHost (Android), the relay transport, app-shell entrypoints.
- **ADRs:** 0001, 0005, 0003, 0002, 0004.

## Grounding — port from the PoC
- The two-engine native host (EXP2) + transparent-overlay (EXP3, for the later Minimap Block): `_poc/multidisplay_poc/android/app/src/main/kotlin/com/zeepowertoys/multidisplay_poc/MainActivity.kt` — `FlutterEngineGroup.createAndRunEngine(DartEntrypoint(findAppBundlePath(), "hudMain"))`, `eng.lifecycleChannel.appIsResumed()`, `Presentation(this, display)` + `FlutterView` + `attachToFlutterEngine`, `findSecondaryDisplay()` = first display ≠ DEFAULT.
- Distilled: [`docs/knowledge/pocs-twoengine-relay-and-overlay.md`](../knowledge/pocs-twoengine-relay-and-overlay.md), [`docs/knowledge/hud-presentation-host.md`](../knowledge/hud-presentation-host.md).
- Emulator secondary display: `adb shell settings put global overlay_display_devices "1280x720/213"` (proven to create a non-default display). **Historical:** this Block's T2 setup ran the emulator overlay at 1280×720; the real HUD geometry (both emulator and car) is **1024×576 @ 213dpi** — the overlay value was corrected in a later Block (see `docs/knowledge/pocs-twoengine-relay-and-overlay.md`'s equivalent note, and `CONTEXT.md`'s Minimap entry).

## What to build
- **Dart `Relay` abstraction** (`lib/relay/`): `DesktopRelay` (current `desktop_multi_window` `zee/hub`) + `AndroidRelay` (plain `MethodChannel('zee/hub')`, `invokeMethod('relay', envelope)` on DHU / `setMethodCallHandler` on HUD). Select by `Platform.isAndroid`. Keep `pushConfigToHud`/`pushCarSignalToHud`/`listenForRelay` as the stable API. Guard so `desktop_multi_window` is never *called* on Android (import may remain).
- **HUD entrypoint** (`lib/main.dart`): `@pragma('vm:entry-point') void hudEntry() => hudMain(const [])`. On Android `main()` → `dhuMain` (the native side creates the HUD engine); the desktop HUD-window creation in `dhuMain` is guarded to desktop only.
- **Native host** (`android/.../MainActivity.kt`): port EXP2 — DHU `FlutterActivity`; in `configureFlutterEngine` register the relay channel on the DHU engine and (deferred) create the HUD engine via `FlutterEngineGroup` + `DartEntrypoint("hudEntry")`, register the relay channel on it, create the `Presentation` on the secondary display and attach a `FlutterView`. Handle "no secondary display" gracefully (run DHU anyway, log).
- **Native relay bridge**: DHU-engine `zee/hub` handler forwards `relay` calls to the HUD-engine `zee/hub` channel (`invokeMethod('relay', args)`). This is the Android transport for ADR 0003's events.

## Definition of Done (runtime-confirmed on T2)
Inherits [PRINCIPLES.md](../PRINCIPLES.md). On `emulator-5554` with the overlay display set:
- [x] One APK builds & installs; app launches; the VM service enumerates **2 isolates**, `whoami` → dhu+hud (same pid `23276`, distinct heaps). — artifact: whoami-all JSON.
- [x] `tap dhu-toggle` → `dump-state hud` flips (cross-isolate relay over the **native** bridge). — artifact: hud `hudBoxOn:false` after tap.
- [x] `inject kind=speed value=80` → `readViewModel` on both dhu+hud = 80 (signal relay over the native bridge). — artifact: JSON (both = 80).
- [x] `shot` captures both surfaces rendering on Android — DHU Material UI on the primary display, the emissive yellow box on the secondary-display HUD. — artifact: [`shots/t2-dhu.png`](../../shots/t2-dhu.png), [`shots/t2-hud.png`](../../shots/t2-hud.png).
- [x] Principles: one APK (no flavors); HUD engine created only when a secondary display exists; relay carries serialized envelopes only. T1 not regressed (analyze clean, 10 tests green, build linux ok).

## Reconciliation
Confirmed by the orchestrator (Opus) on T2 (emulator-5554, API 32 x86_64), 2026-06-11. **Load-bearing findings for the on-car (T3) two-engine host:**
1. **The secondary (HUD) engine does NOT auto-initialize the Flutter binding.** Unlike the primary `FlutterActivity` engine, a `FlutterEngineGroup.createAndRunEngine` engine runs its Dart entrypoint *without* `WidgetsFlutterBinding.ensureInitialized()` — so plugin access (e.g. `SharedPreferences`) throws "ServicesBinding not initialized". The HUD entrypoint **must** call `WidgetsFlutterBinding.ensureInitialized()` first. (`lib/main.dart` `hudEntry()`.)
2. **`hudEngine.lifecycleChannel.appIsResumed()` is mandatory** — without it the engine stays paused: the Dart isolate exists (VM-service sees it) but the UI never renders.
3. **Relay transport is per-tier (ADR 0003), implemented as a `Relay` abstraction.** `DesktopRelay` (desktop_multi_window `WindowMethodChannel`) vs `AndroidRelay` (plain `MethodChannel('zee/hub')`) selected by `Platform.isAndroid`. On Android the native `MainActivity` bridges the two engines: the DHU `zee/hub` handler forwards every `relay` call to the HUD `zee/hub` channel. `desktop_multi_window` is imported but only *constructed* inside `DesktopRelay` — the APK builds fine with it present.
4. **Secondary display on the emulator** = `overlay_display_devices "1280x720/213"` → appears as `Overlay #1` (id ≠ 0); `findSecondaryDisplay()` = first non-default display. On the car this is `displayId=2` (the HUD backing display) — same code path. **Historical:** 1280×720 was this Block's emulator overlay value; the real HUD (emulator and car) is **1024×576 @ 213dpi**, corrected in a later Block.
5. **APK size:** debug ~145 MB (Dart snapshot + all ABIs dominate); release will be far smaller. Emulator `/data` needed ~1 GB free to install the debug APK.

These belong in the on-car HUD-host Block's checklist; ADR 0001's two-engine choice is unchanged (validated, not revised).
