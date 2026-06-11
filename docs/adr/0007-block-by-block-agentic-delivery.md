# 0007 — Block-by-block agentic delivery, reconciled to runtime

This MVP is large — 4 Foundation work-streams plus ~10 feature areas (REQUIREMENTS.md, minus Speedcam) — and it is built by a *team of subagents*, not one author. Two failure modes must be designed out: a single agent swallowing the whole scope (drift, no verification gate, unreviewable diffs), and parallel fan-out across agents (merge chaos and unverified interactions on a single shared HUD/native surface). We also have, uniquely, the machinery to verify behaviour for real — the dual-channel Feedback Loop across three Tiers (ADR 0004).

**Decision.** Work ships as **Blocks**. A Block is one Issue, scoped so a single subagent carries it end-to-end in one loop. Blocks are delivered **sequentially** — exactly one Block in-progress at a time — with the **Foundation** wave (two-engine host, environment adapters, the services/ports skeleton, the Feedback Loop) landing before any feature Block. A Block is `done` only when it is **runtime-confirmed**: its behaviour observed working in the runtime on the appropriate Tier through the Feedback Loop, with an attached artifact (screenshot / state dump / log) — never merely "compiles" or "unit tests pass." The plan is **living**: when building a Block reveals an ADR, CONTEXT entry, REQUIREMENT, or Issue to be wrong, the agent **reconciles that document inside the same Block**.

**Why sequential + runtime-gated:**
- *vs. big-bang (one agent, whole lump):* no verification gate, diffs too large to review, and the plan silently drifts from reality. The thing we are building — `state → pixels`, `gesture → config-write` on a real HUD — is exactly what a code-only agent cannot confirm.
- *vs. parallel fan-out:* the HUD Presentation, the native host, and the two-isolate event relay (ADR 0003) are *shared* surfaces; concurrent Blocks would integrate blind and merge into an unverified whole. Throughput is not the bottleneck; correctness on real hardware is.

Sequential + runtime-gated buys an **always-green, always-true-to-reality trunk** — which is the entire reason ADR 0004's Feedback Loop was worth its cost.

**Consequences:**
- Issues are sized as single-loop Blocks; anything bigger is split *before* work starts.
- The board (`docs/issues/`) shows **exactly one** Block in-progress; agents hand off Block → Block.
- `done` requires a runtime artifact and a pass of the standing Definition of Done (`docs/PRINCIPLES.md`) — not just code.
- **Reconciliation is part of the Block, not an afterthought** — docs never lag the code by more than one Block.
- No feature Block can be runtime-confirmed until Foundation exists, so Foundation is Wave 0 by construction.
- The cost is wall-clock throughput. We accept it; a safety-relevant car app earns its trunk being green at every step.
