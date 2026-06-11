# 0002 — One Android artifact with environment-selected adapters

Testing flexibility is a first-class requirement: iterate UI fast off-car, validate native plumbing on the emulator, and run for real on-car — without divergent builds drifting apart.

**Decision:** The Flutter `lib/` depends only on abstract ports (`CarSignals`, `Installer`, `SystemConfig`, `HudHost`); each environment injects a concrete adapter at startup.

- **Desktop (macOS/Linux) — T1.** Pure-Dart fakes; the HUD renders into a second OS window over a placeholder map. **Two Flutter engines / two isolates** (PoC-proven via a two-engine runner / `desktop_multi_window`), faithful to the Android two-engine target rather than a single-isolate shortcut. Services (ADR 0003) are injected as Dart fakes; cross-isolate events relay over a host channel instead of the native bridge, and the dual-channel Feedback Loop's "native" side (ADR 0004) becomes that host channel — same role, no adb. The UI-iteration workhorse — hot reload across both engines.
- **Android — a single APK, no build flavors.** `CarSignals` bridges to native via Pigeon. Native auto-selects its provider: real **AdaptAPI** when present (on-car) or a **native simulator** when absent (emulator), overridable by an ADB flag. The simulator is driven by ADB broadcasts, reusing phase0's `SIMULATE` pattern so agentic CLI loops keep working.

**Why not build flavors:** the artifact tested on the emulator is byte-identical to the one on the car, and there is a single build path. A future engineer may reach for flavors to separate stub vs prod — this records that the runtime switch is deliberate.
