# 0002 — One Android artifact with environment-selected adapters

Testing flexibility is a first-class requirement: iterate UI fast off-car, validate native plumbing on the emulator, and run for real on-car — without divergent builds drifting apart.

**Decision:** The Flutter `lib/` depends only on abstract ports (`CarSignals`, `Installer`, `SystemConfig`, `HudHost`); each environment injects a concrete adapter at startup.

- **Desktop (Linux only) — T1.** Pure-Dart fakes; the HUD renders into a second OS window. **Two Flutter engines / two isolates** (PoC-proven via a two-engine runner / `desktop_multi_window`), faithful to the Android two-engine target rather than a single-isolate shortcut. Services (ADR 0003) are injected as Dart fakes; cross-isolate events relay over a host channel instead of the native bridge, and the dual-channel Feedback Loop's "native" side (ADR 0004) becomes that host channel — same role, no adb.
- **Android — a single APK, no build flavors.** `CarSignals` bridges to native over platform channels — an `EventChannel` (`zee/car_signals/events`) streams signal events native→Dart and a `MethodChannel` (`zee/car_signals`) carries `start`/`snapshot`/`simulate` (the last added in Block 0026 for in-app signal injection), and `start` also returns which source native selected (`adaptapi`/`simulated`) so the app can report it on screen rather than only logging it. Native auto-selects its provider: real **AdaptAPI** when present (on-car) or a **native simulator** when absent (emulator), overridable by `setprop persist.zee.carsignals sim|adapt`. The simulator is driven by ADB broadcasts (`com.zeepowertoys.SIMULATE`), reusing phase0's `SIMULATE` pattern so agentic CLI loops keep working.

> **Reconciliation (2026-07-31, recovery wave):** three claims above were false and are corrected in place.
> (a) T1 was described as the "macOS/Linux" tier. It is **Linux-only** — `dev/zee_run.py` hardcodes
> `flutter run -d linux` and there is no `macos/` runner directory in this repo, so T1 cannot run on a
> macOS host at all. On macOS the fast loop is `flutter test`; **T2 is the truth tier.**
> (b) "the HUD renders … over a placeholder map" never existed: `lib/app/hud_app.dart` states the
> opposite — on desktop the HUD is pure black, because there is no native under-layer to composite over.
> T1 injects `FakeMinimapHost`, so T1 structurally **cannot** verify the Minimap. That is a large part of
> why a minimap regression shipped undetected.
> (c) "the UI-iteration workhorse — hot reload across both engines" oversold it: `dev/zee_run.py`
> detaches `flutter run` with its stdin redirected, so there is no hot-reload channel; the documented
> loop is `down && up`.
>
> **Reconciliation (Block 0005):** this ADR originally said "bridges to native via Pigeon." Pigeon was reconsidered and **not** adopted for CarSignals: a native→Dart *event stream* is the idiomatic job of an `EventChannel`, Pigeon's `FlutterApi` callback codegen adds compile-time weight for a 5-event contract, and Pigeon's `*.g.dart` output collides with the repo's generated-file ignore rule. The channel schema *is* the Pigeon contract realized in-channel; migrating to Pigeon later is mechanical. Pigeon remains the default for richer request/response native APIs.

**Why not build flavors:** the artifact tested on the emulator is byte-identical to the one on the car, and there is a single build path. A future engineer may reach for flavors to separate stub vs prod — this records that the runtime switch is deliberate.
