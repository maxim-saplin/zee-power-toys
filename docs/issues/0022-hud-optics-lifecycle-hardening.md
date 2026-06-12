---
status: done
labels: [foundation, hud, android, lifecycle, efficiency]
created: 2026-06-12
closed: 2026-06-12
satisfies: foundation — HUD optics correctness + ADR 0001 efficiency hardening
blocked-by: []
modules: [HudHost, MinimapHost, CarSignals, YNaviCarAppHost]
tier: T2
---

# 0022 — HUD optics + lifecycle hardening (Fix Batch A)

## Block scope

QA sweep identified blockers in HUD rendering and efficiency regressions.  This
Block resolves all QA1-* (HUD optics) and QA4-* (native lifecycle) findings.

## Touches
- **Satisfies:** Foundation — ADR 0001 (HUD emissive rendering; HUD engine only while active)
- **Modules:** HudHost (new `NativeHudHost`), MinimapHost (dynamic HUD dims), CarSignals
  (handler alloc), YNaviCarAppHost (worker lifecycle), MinimapView (render thread)
- **ADRs:** 0001 (HUD emissive; efficiency), 0003 (service ports), 0007 (delivery discipline)

## Findings fixed

### GROUP 1 — HUD optics BLOCKERs

**QA1-1 BLOCKER** — HUD window background near-white (#F7F7F7) → solid panel glow  
FIX: `setupHud()` now sets `root.setBackgroundColor(Color.BLACK)` on the root
`FrameLayout` and `pres.window?.setBackgroundDrawable(ColorDrawable(Color.BLACK))` on
the Presentation window.  Black pixels emit no light; the projector renders them as
transparent.

**QA1-2 BLOCKER** — Minimap bounds used hardcoded `_kHudW=1024, _kHudH=576` but the
real HUD display is 1280×720 (→ map mispositioned, undersized, possibly outside Safe Area)  
FIX:
- `_kHudW`/`_kHudH` constants replaced by mutable `_hudW`/`_hudH` (default 1024×576).
- `setupHud()` invokes `hudReady({w,h,dpi})` on the DHU `zee/minimap` MethodChannel
  after the Presentation is attached.
- `NativeMinimapHost` registers `setMethodCallHandler` to receive `hudReady`; exposes
  `onHudReady` stream.
- `dhuMain()` subscribes to `onHudReady`: updates `_hudW`/`_hudH` from the real display
  metrics and re-applies minimap config.
- `_applyMinimapConfig` now uses the runtime-updated values (QA1-4 boot-order fixed too).

**QA1-4 MAJOR** — `_applyMinimapConfig` fired before `minimapView` existed → bounds silently
dropped; map initialised MATCH_PARENT then corrected on first config relay  
FIX: same `hudReady` re-apply path as QA1-2 (setupHud completion → Dart re-apply) ensures
the minimap has correct bounds as soon as the Presentation is live.

**QA1-7 NIT** — Battery slot right edge only ~9px inside Safe Area on 1280×720  
FIX: `hud_root.dart` battery `Positioned.right` changed from `saWidth * 0.008` to
`saWidth * 0.04` (matching the blinker's `sidePadFrac = 0.04`).

### GROUP 2 — HUD engine runtime teardown (deferred ADR-0001 item)

**QA4-1 MAJOR** — HUD FlutterEngine + Presentation NOT torn down when `hudEnabled=false`  
FIX:
- New `zee/hud_lifecycle` MethodChannel registered in `configureFlutterEngine`.
  `show()` → idempotent `setupHud()` (NOOP if engine already running).
  `hide()` → new `tearDownHud()`: stops YNavi host, stops MinimapView render thread,
  dismisses Presentation, destroys HUD FlutterEngine + engineGroup.
- New `lib/services/adapters/native_hud_host.dart` (`NativeHudHost`) implements
  `HudHost` over `zee/hud_lifecycle`.
- `dhuMain()` selects `NativeHudHost` on Android (was always `FakeHudHost`).
- `dhuMain()` listens for `hudEnabled` transitions in `store.changes` and calls
  `hudHostRaw.show()` / `hudHostRaw.hide()` on toggle.
- Re-enable path fires `hudReady` → re-applies minimap config so HUD renders correctly
  after a disable/enable cycle.

### GROUP 3 — native thread/alloc lifecycle

**QA4-2** — `YNaviCarAppHost.worker` executor never shut down after `stop()`  
FIX: `worker` changed from `val` to `var`; `stop()` calls `worker.shutdown()` after
submitting `performStop`; `start()` recreates `worker` if `isShutdown`.

**QA4-3** — `CarSignalsController.emitEvent` allocated a new `Handler` per event  
FIX: hoisted `private val mainHandler = Handler(Looper.getMainLooper())` field; `emitEvent`
reuses it.

**QA4-4** — `MinimapView.pauseRendering()` parked thread (wait) but did not terminate it
on minimap-disable; thread survived when minimap was disabled (ADR 0001)  
FIX: `pauseRendering()` now stops the thread (sets `running=false`, interrupts, joins with
500ms timeout) instead of merely parking with `pauseLock.wait()`.  `resumeRendering()`
already handles `renderThread == null` by calling `startRenderLoop()` — no regression to
YNavi surface-ownership logic.

**QA4-5 NIT** — `performStop` did not call `stopLocationUpdates` before unbind  
FIX: `performStop` calls `appManager?.stopLocationUpdates(cb)` before the REBIND_DELAY_MS
wait, giving YNavi the symmetric stop signal.

**QA4-6 NIT** — Placeholder loop ran at ~60fps (`Thread.sleep(16)`); decorative placeholder
does not need display-rate updates  
FIX: changed to `Thread.sleep(33)` (~30fps).

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md).

- [x] **Runtime-confirmed on T2** — HUD screenshot shows black background + minimap inside
  Safe Area at correct 1280×720 bounds; battery readable inside Safe Area.
  Screenshots in `/tmp/fixA/`.
- [x] Group 2 verified: `hudEnabled=false` → HUD engine/Presentation threads gone;
  `hudEnabled=true` → HUD re-spawns and renders correctly.
- [x] `flutter analyze` clean (0 issues)
- [x] `flutter test` = 199 green
- [x] `flutter build apk --debug` succeeds

## Reconciliation

- `docs/issues/0017-final-sweep.md` and `0018-premium-ui-ynavi-host.md` deferred items:
  HUD-engine teardown on `hudEnabled=false` was listed as deferred in 0017 §3.  Now closed.
- `docs/issues/0021` noted the minimap bounds were computed from hardcoded 1024×576;
  this Block closes that known drift.
- `docs/issues/BACKLOG.md` updated: 0022 added as `done`.

## Notes

T3 (on-car) verification of QA4-1 disable/enable cycle and of HUD optics on the real
projector is deferred — emulator confirms the engine lifecycle; windshield optics require
physical hardware.
