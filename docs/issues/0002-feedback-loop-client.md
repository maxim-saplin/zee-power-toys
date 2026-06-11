---
status: backlog
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
- [ ] The client enumerates both isolates, `dumpState` on each surface, drives `setConfig`, and captures a `shot` — exposed as a clean CLI **and** a reusable lib the `verify` skill calls. — artifact: a driver transcript + captured shots.
- [ ] Surface resolution is robust (both isolates named `main`; resolve by `whoami.surface`, per ADR 0004). — artifact: whoami-all JSON.
- [ ] `ext.zee.*` contract documented (the required probes any new surface must expose).
- [ ] Native-channel ops present in the API surface but cleanly stubbed on T1 (no fake "success").

## Reconciliation
_(Filled while building.)_

## Notes
Keep the client tier-agnostic at its seams — adding T2/T3 must not change call sites in later Blocks' verification steps.
