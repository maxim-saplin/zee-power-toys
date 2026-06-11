---
status: done
labels: [foundation, feedback-loop]
created: 2026-06-11
satisfies: foundation          # implements ADR 0004
blocked-by: [0001]
modules: [FeedbackLoop]
tier: T1
---

# 0002 — Feedback Loop client (tier-agnostic)

## Block scope
Promote the throwaway driver from Block 0001 into the project's **tier-agnostic Feedback Loop client** — the machine that makes every later Block runtime-confirmable (ADR 0004). One client fronts **semantic ops** (`whoami`, `dumpState`, `readViewModel`, `setConfig`, `tap`, `shot`, `inject`) and routes each to the right channel per tier. Also pin the **`ext.zee.*` surface contract** every driveable surface must implement.

On **T1**, every op goes over the VM-service channel; the native ADB/broadcast channel is a stub/no-op (it descends the stack and gains teeth on T2/T3 — Block for the Android edge). This Block is the T1 half, specced so T2/T3 slot in without changing the client's surface.

## Touches
- **Satisfies:** Foundation — implements ADR 0004 (two channels, three tiers).
- **Modules:** FeedbackLoop (the client + the `ext.zee.*` contract).
- **ADRs:** 0004 (primary), 0003 (it reads derived view-state), 0001 (two-isolate `getVM` + per-surface resolution).

## Grounding — lift from these PoCs
- Driver seed: `_poc/feedback_loop/zee_drive.py:111–237` — VM discovery, `getVM` isolate enumeration, surface→isolateId map via `whoami`, `ext.zee.*` RPC subcommands.
- Proof + screenshot patterns: `_poc/desktop_twoengine/drive/probe.py`, `_poc/desktop_twoengine/drive/grab_shots.py`.
- Native-channel target (T2/T3, spec only here): phase0's `Phase0ProbeReceiver`→`last.json` async readback — **upgrade to a synchronous structured dump** (ADR 0004), and the `SIMULATE` broadcast injection (`harness/SimulateReceiver.kt`). Implemented in the Android-edge Block, not here.

## Definition of Done (runtime-confirmed on T1)
Inherits [PRINCIPLES.md](../PRINCIPLES.md). Against the running Block-0001 skeleton:
- [x] The client enumerates both isolates, `dumpState` on each surface, drives `setConfig`, and captures a `shot` — exposed as a clean CLI **and** a reusable lib (`dev/feedback_loop.py`: `FeedbackLoop` class). — artifact: driver transcript + [`shots/fl-after-tap1.png`](../../shots/fl-after-tap1.png)/[`fl-after-tap2.png`](../../shots/fl-after-tap2.png).
- [x] Surface resolution is robust (both isolates named `main`; resolve by `whoami.surface`). — artifact: whoami-all JSON resolving dhu+hud.
- [x] `ext.zee.*` contract documented — [`docs/feedback-loop-contract.md`](../feedback-loop-contract.md).
- [x] Native-channel ops present in the API surface but cleanly stubbed on T1 (`inject` raises an explicit "native channel not available on T1" error — **no fake success**).
- [x] **Bonus, beyond DoD:** `tap` is a *real* UI driver — added `ext.zee.tapByKey` (3-tier: callback-walk → synthetic pointer → ancestor-walk) + a `ValueKey('dhu-toggle')`. Confirmed end-to-end: `tap dhu-toggle` → cross-isolate relay → **HUD box appears/disappears** (gesture→pixels), captured in the shots above. Also added `ext.zee.readViewModel`.

## Reconciliation
Confirmed by the orchestrator (Opus) on T1, 2026-06-11.
1. **`inject` routing (carry-forward to the services-skeleton Block).** ADR 0004 says the injection point *descends the stack* — on **T1 the target is the Dart fake**, reachable over the **VM-service** channel, not the native channel. There is no `CarSignals`/fake yet (it lands in the services-skeleton Block), so `inject` correctly stubs today. When `FakeCarSignals` exists, add `ext.zee.inject` (VM-service) into it and route T1 `inject` over the VM channel (T2/T3 keep the ADB-broadcast native channel). The seam in `feedback_loop.py` (`NativeChannel` ABC) is built for this.
2. **`tap` faithfulness.** The Material `Switch`'s toggle is reached via the descendant-callback tier of `tapByKey`. The convention for later Blocks: put the `ValueKey` directly on the tappable (button/`InkWell`/`GestureDetector`) so the first callback found is the intended one.

## Notes
Keep the client tier-agnostic at its seams — adding T2/T3 must not change call sites in later Blocks' verification steps.
