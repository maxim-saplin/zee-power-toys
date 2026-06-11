---
status: ready-for-agent        # ready-for-agent | in-progress | blocked | done
labels: []                     # e.g. [foundation], [hud], [app-shell]
created: YYYY-MM-DD
satisfies: foundation          # which REQUIREMENTS.md capability, or "foundation" for Wave 0
blocked-by: []                 # e.g. [0003]
modules: []                    # ports/services touched: CarSignals, HudHost, ...
tier: T1                       # the Tier this Block is runtime-confirmed on
---

# NNNN — <title>

## Block scope
<What this single Block delivers, end-to-end. Small enough for one agentic loop. If it doesn't fit one loop, split it before starting.>

## Touches
- **Satisfies:** <REQUIREMENTS.md capability, or "Foundation — implements ADR NNNN">
- **Modules:** <ports/services>
- **ADRs:** <relevant decisions>

## Definition of Done
Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:
- [ ] Runtime-confirmed on **Tier <N>** — artifact: <what proves it: screenshot / `dumpState` / log>
- [ ] <any Block-specific acceptance criteria>

## Reconciliation
<Filled while building. What diverged from the plan, and which docs were updated. "None" if the plan held.>

## Notes
<Anything else.>
