---
status: ready-for-agent
labels: [foundation, walking-skeleton]
created: 2026-06-11
satisfies: foundation          # implements ADR 0001 / 0002(T1) / 0003 / 0004 / 0006
blocked-by: []
modules: [ConfigStore, app-shell, FeedbackLoop]
tier: T1
---

# 0001 — Walking skeleton: T1 end-to-end loop

## Block scope
Bring the architecture's spine to life on **T1 Desktop (Linux)**, end-to-end and *ugly on purpose*: two Flutter engines (DHU + HUD surfaces) running as two isolates in one process; a real (minimal) Dart **ConfigStore** behind a Riverpod provider; a gesture on the DHU surface that writes config, which **relays across the isolate boundary** and re-derives a visible pixel change on the HUD surface; all of it **driven and read through the Feedback Loop**.

This proves — on the fastest tier — the single hardest path the whole product depends on:
`gesture → ConfigStore write → changed event → cross-isolate relay → both isolates re-derive → HUD pixels`, plus `state → pixels` readback. Every later Block (foundation or feature) hangs off this breathing spine.

This is the largest Block by nature (it includes project genesis). **Split seam** if it doesn't fit one loop — build and runtime-confirm in this order, each independently checkable:
1. project genesis + two surfaces render (2 isolates; `whoami` resolves both; two windows up);
2. ConfigStore + Riverpod + cross-isolate relay (set config on DHU → HUD re-derives → pixel changes);
3. Feedback Loop driver confirms it headlessly (drive + readback + screenshot).

## Touches
- **Satisfies:** Foundation — implements ADR 0001 (two engines), 0002 (T1 desktop adapter), 0003 (event-driven services, Dart brain, cross-isolate relay), 0006 (Riverpod injection), 0004 (Feedback Loop).
- **Modules:** ConfigStore (minimal), the two-surface app shell (DHU/HUD), the inline Feedback Loop driver (promoted to a real module in Block 0002).
- **ADRs:** 0001, 0002, 0003, 0004, 0006.

## Grounding — lift from these PoCs, don't reinvent
- **Two-engine desktop topology + the working cross-isolate relay:** `_poc/desktop_twoengine/lib/main.dart:54–56,112–138` — the `zee/hub` `WindowMethodChannel`, `pushConfig` on PRIMARY + handler on HUD — using `desktop_multi_window` 0.3.0. **Sanctioned for T1 by ADR 0002.** (The owned GTK runner `_poc/desktop_twoengine/approach_b/linux/runner/my_application.cc:21–63` is the ADR-0005 fallback if the package bites — *not* required for this Block.)
- **`ext.zee.*` surface contract:** `_poc/desktop_twoengine/lib/main.dart:70–106` — `whoami` (`{surface,isolate,counter,configFromMain,pid}`), `bump`, `pushConfig`, `shot` (`RepaintBoundary`→base64 PNG). Register the same probes in **both** entrypoints; tag each isolate by surface.
- **Feedback Loop driver seed:** `_poc/feedback_loop/zee_drive.py:111–237` (VM discovery, `getVM` isolate enum, surface→isolate map via `whoami`, `ext.zee.*` RPC) + proof `_poc/desktop_twoengine/drive/probe.py` + screenshots `_poc/desktop_twoengine/drive/grab_shots.py`.

## What to build (the real app — replaces the _poc throwaways)
- Scaffold the actual Flutter app with a **Linux desktop target** and two entrypoints: `main()` = DHU, `@pragma('vm:entry-point') hudMain()` = HUD. Wire `desktop_multi_window` for the two engines (this is the **T1 adapter**, ADR 0002).
- **ConfigStore** (Dart): one tiny schema (e.g. `{ hudBoxOn: bool }`), a **plain JSON** persisted format (native-readable per ADR 0003), exposed as a Riverpod provider with a `setConfig` command + a `changed` stream.
- **Relay:** the `changed` event crosses to the HUD isolate over the host channel (the `zee/hub` pattern). **Never a shared mutable Dart object** (ADR 0003).
- **DHU surface:** a single ugly toggle → `ConfigStore.setConfig(hudBoxOn: !x)`.
- **HUD surface:** derives from the same provider graph; draws a box visible iff `hudBoxOn`, wrapped in a `RepaintBoundary` so `ext.zee.shot` can capture it.
- **`ext.zee.*` probes** in both isolates: `whoami`, `dumpState` (returns the derived view-model `{hudBoxOn}`), `setConfig` (drive the write headlessly), `shot`.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md). With `flutter run -d linux` up and the driver attached:
- [ ] `getVM` shows **2 isolates**; `whoami` resolves `dhu` + `hud`. — artifact: whoami-all JSON.
- [ ] Drive `ext.zee.setConfig {hudBoxOn:true}` on the **DHU** isolate → `ext.zee.dumpState` on the **HUD** isolate returns `hudBoxOn:true`; and the reverse for `false`. (cross-isolate relay proven) — artifact: before/after dumpState JSON from both isolates.
- [ ] `ext.zee.shot` on the HUD isolate captures the box visible vs hidden, matching config. — artifact: `shots/hud-on.png`, `shots/hud-off.png`.
- [ ] ConfigStore persists across a restart (write → restart → dumpState shows the value). — artifact: log/JSON.
- [ ] Principles honored: no shared mutable Dart object across isolates; minimal UI; no stray always-on timers.

## Reconciliation
_(Filled while building. e.g. if `desktop_multi_window` proves unfit and the approach_b owned runner is adopted, note it and update ADR 0002 / 0005 here.)_

## Notes
Ugly is correct — no theming, no layout, no real car signals; those are later Blocks. The only goal is a breathing spine the Feedback Loop can drive and read on every later Block.
