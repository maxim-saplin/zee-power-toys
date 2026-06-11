# 0004 — The Feedback Loop is two channels across three tiers

Driving and inspecting the app is the project's cornerstone: every tier must give both **state insight** and **end-to-end UI driving** (agents build UI, so the loop must exercise the `state → pixels` and `gesture → config-write` edges, not just the model). Three tiers form a fidelity gradient — **T1 Desktop** (pure-Dart fakes, fast), **T2 Emulator** (real native, native simulator), **T3 Car** (real AdaptAPI) — each validating a strictly larger slice of real plumbing. A VM-service-only loop is necessary but provably insufficient: even the all-Flutter `nothingness` reference app falls back to `adb dumpsys` for its one genuinely-native edge, and ADR 0003 makes our native edge far larger (AdaptAPI is the source of truth, plus YNavi bind, Display-2 Presentation, boot-before-Flutter).

**Decision:** The Feedback Loop has **two channels**, fronted by one tier-agnostic client that routes semantic ops (`inject`, `setConfig`, `dumpState`, `tap`, `readViewModel`) to the right channel per tier:

1. **VM-service channel** — `ext.zee.*` extensions (the `nothingness` `drive.py` pattern, i.e. the reused "flutter debug skill") for UI driving + reading the Dart view-model. **Uniform across T1/T2/T3** — verified identical on Linux desktop and Android.
2. **Native ADB/broadcast channel** — signal injection at the native services + native-state inspection (AdaptAPI/YNavi/Presentation). The **injection point descends the stack as the tier rises** — T1 Dart fake → T2 broadcast→native service → T3 real AdaptAPI — and that descent *is* the fidelity gradient, so higher tiers earn their cost instead of an expensive T1 re-run.

Native inspection returns a **synchronous structured dump** (broadcast result-extras or a small debug dump service), upgrading phase0's async/logcat probe so agents get deterministic JSON back, matching the VM channel's feel.

**Considered options:**
- *Native-only* (drive services, treat UI as pure projection) — rejected: never exercises `state → pixels` or `gesture → write`, the actual product under construction.
- *VM-service-only* — rejected: cannot reach the native edge (AdaptAPI/YNavi/Presentation/boot); proven insufficient even in a pure-Flutter app.
- *Native socket/HTTP debug server* — rejected: more surface area than reusing phase0's on-car-proven broadcast pattern.

**Consequences:**
- The loop runs **debug/profile** builds (the VM service is absent in release); release is outside the loop.
- A fresh clone pays a one-time cold Flutter-engine download (~1.5 GB) for the T1 desktop path — pre-warm rather than treat as a blocker.
- Native read-back moves from phase0's async/logcat (`Phase0ProbeReceiver` → `JobIntentService`) to a synchronous structured dump.
- **Confirmed (PoC `_poc/multidisplay_poc` + `_poc/feedback_loop/zee_drive.py`):** with two engines (`FlutterEngineGroup`), one VM service enumerates *both* isolates and an `ext.zee.*` extension registered in the secondary/HUD isolate is both readable and writable from one external client. Two nuances the loop must honour: (1) the HUD engine must be *created and running* for its isolate to exist — poll `getVM` until both surfaces resolve rather than assuming both are up at connect; (2) both isolates are named `main` and share a `rootLib`, so surfaces are **not** name-distinguishable — every driveable surface must expose a `whoami`-style probe and the driver builds the surface→isolateId map from it.
