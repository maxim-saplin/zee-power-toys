---
status: accepted
labels: [hud, battery, range, polish]
created: 2026-09-25
satisfies: Own estimated range HUD — always visible when ON + typography/layout polish
tier: T2
owner: zee-dev
blocked-by: []
modules: [BatteryWidget, RangeEstimator, BatteryConfig.showOwnRangeEstimate]
priority: now
filed-by: zee-pdm
tip: e1c3419
accepted: 2026-09-25
evidence: tmp/qa/0107-cut-e1c3419/
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

- [x] Toggle ON + no ready estimate → visible pending marker beside/near % (not identical to OFF).
- [x] Toggle ON + ready → `N km` without `~`; km smaller than digits; % slightly smaller than before.
- [x] Battery+range stays one line (no wrap) on Tablet dens320 HUD / justText and default pack looks — widen panel as needed.
- [x] Toggle OFF → % only (unchanged intent).
- [x] Help copy still says estimate is not the car’s range.
- [x] Units/widget tests updated. Soft: car T3.
- [x] QA FINDINGS on tip + PDM ACCEPT — PASS / ACCEPT `e1c3419` (2026-09-25). Soft: car T3.


## Reconciliation

**2026-09-25 tip:** Own-range ON always shows chrome; drop `~`; typography + slot width.

### Changes
1. **Pending (ON + !ready):** `N% · … km` via `_SocRangeLabel` — not identical to OFF bare `%`.
2. **Ready:** `N% · N km` — tilde removed.
3. **Typography:** SoC/`%` at 0.90× label size; range digits full size; `km` at 0.70×.
4. **Layout:** When toggle ON, SoC+range renders **below** the pack (not inside DualColor). Slot width floor `kBatterySlotWidthFracOwnRange` (0.18). `softWrap: false` / `maxLines: 1`.
5. **OFF:** `%` only (dual-color inside pack unchanged for default batteryText).
6. Help hint unchanged (still “not the car’s range”). No Live bump (`1.1.0+21`). 0108 honesty window **not** touched.

### Verification
`flutter test` — `test/widgets/battery_widget_test.dart` (0107 pending/ready/justText typography), `test/hud/battery_geometry_test.dart` (own-range width), `test/services/range_estimator_test.dart`. `dart analyze` clean on touched Dart.

**Divergence:** None from scope; change-only. Soft: car T3.

## ACCEPT (PDM 2026-09-25)

Tip `e1c3419` (1.1.0+21; Live not bumped). QA T2 dens320 PASS (`tmp/qa/0107-cut-e1c3419/`); 63/63 widget, geometry, and estimator tests PASS. OFF stays percentage-only; ON with no history shows `… km`; ready state shows `360 km` without `~`, with smaller `km`/`%` and one-line layout. Soft: hint copy is stale versus the always-show pending marker; car T3 remains open. Neither soft is a blocker.

## Notes

- Cooking: change-only; no Live bump until Maxim GO after ACCEPT. Prefer after 0106 if one Tablet contested.
- Do **not** implement 0108 honesty window here.
