---
status: in-progress
labels: [hud, lifecycle, watchdog, t3, incident]
created: 2026-11-20
satisfies: HUD recovers automatically when the overlay stops rendering
blocked-by: []
modules: [MainActivity, hud lifecycle]
tier: T3
owner: zee-dev
priority: now
filed-by: zee-dev
related: [0130]
---

# 0131 — HUD went blank on T3; add isolate-liveness watchdog

## Incident (T3 2026-11-20)

~10:28 local: the whole HUD stopped — no minimap, no battery, no media.
The Zee DHU app itself stayed alive (no entry in `ApplicationExitInfo`;
process, Activity, and FGS all healthy when inspected at ~11:00).

Evidence:

- `crash` buffer: 10:28:56.013 `SIGABRT` in `ru.yandex.yandexnavi`
  (`Invoked not in UI thread.`, `libmaps-mobile.so`
  `TrafficLayerBinding_setTrafficVisible`). Explains map loss only.
- Battery + media vanished too → the failure includes the shared HUD
  Presentation / HUD Flutter engine, not just YNavi.
- `main`/`system` logcat had rolled past the incident window; root trigger
  unproven.

## Root gap

`ensureHudPresentation` declares the HUD healthy when the engine ref is
non-null, `Presentation.isShowing`, and the display id matches. None of
these prove the HUD isolate still renders. A dead/frozen HUD engine passes
all three checks forever, so recovery never fires.

Secondary gap: `setupHud`'s catch block kept partial refs, which made the
same healthy-check pass after a failed setup.

## Fix

`MainActivity` watchdog, every 30 s: ping the HUD isolate over the
`zee/hub` MethodChannel. Any reply — success, error, or notImplemented —
proves the isolate processes platform messages. No reply within 5 s is a
strike (a destroyed engine drops the reply: "FlutterJNI was detached"; a
frozen isolate never dispatches it). Two consecutive strikes → tear down
and recreate the Presentation + engine. Strikes reset on every pong and on
teardown. `setupHud` failure now tears down instead of keeping partial refs.

YNavi-only death stays with the existing bind/reconnect path — the watchdog
only replaces the whole HUD when the HUD isolate itself is unresponsive.

## Definition of Done

- [x] Watchdog pings HUD isolate; 2 missed pongs recreate Presentation + engine.
- [x] `setupHud` exception path tears down partial state.
- [ ] Kotlin compile green (blocked offline in the car session — Maven
      unreachable for `:gradle` build-logic jars; verify in CI / next build).
- [ ] T3: after a forced HUD engine kill, HUD self-recovers within ~65 s.

## Notes

If the incident repeats before the fix ships, immediately capture
`adb logcat -b main,system,crash -d` and `dumpsys activity exit-info` —
the 10:22–10:32 window was already rolled over by 11:00 this time.
