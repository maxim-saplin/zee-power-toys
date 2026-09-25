---
status: ready-for-agent
labels: [hud, battery, range, polish]
created: 2026-09-25
satisfies: Own estimated range HUD — always visible when ON + typography/layout polish
tier: T2
owner: zee-dev
blocked-by: []
modules: [BatteryWidget, RangeEstimator, BatteryConfig.showOwnRangeEstimate]
priority: now
filed-by: zee-pdm
related: [0105]
---

# 0107 — Own-range ON must always show something + drop ~ + layout polish

## Block scope

Maxim 2026-09-25 ~21:53 Minsk (after Live 1.1.0+21 / 0105):

1. When own estimated range is toggled ON, HUD must show *something* so the user can tell ON vs OFF — do not leave only bare `%` (same as OFF) while waiting for ≥~5 km history. (Placeholder/pending state OK: e.g. `… km` / `— km` / `…` — pick clear short chrome; must not look identical to toggle OFF.)
2. Remove the tilde `~` from the range figure (show `360 km` not `~360 km`).
3. Make the `km` unit smaller than the number.
4. Make the battery `%` slightly smaller.
5. Slightly grow the battery panel / text width so combined battery + range does **not** line-break (currently wraps on HUD).

## Context for agents

0105 shipped Live +21 — `72% · ~360 km` justText path; default OFF; ON+insufficient history currently hides ~km (same as OFF visually) — that is the “guess if on” problem.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [ ] Toggle ON + no ready estimate → visible pending marker beside/near % (not identical to OFF).
- [ ] Toggle ON + ready → `N km` without `~`; km smaller than digits; % slightly smaller than before.
- [ ] Battery+range stays one line (no wrap) on Tablet dens320 HUD / justText and default pack looks — widen panel as needed.
- [ ] Toggle OFF → % only (unchanged intent).
- [ ] Help copy still says estimate is not the car’s range.
- [ ] Units/widget tests updated; QA FINDINGS + PDM ACCEPT. Soft: car T3.

## Notes

Cooking: change-only; no Live bump until Maxim GO after ACCEPT. Prefer after 0106 if one Tablet contested.
