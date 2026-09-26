---
status: ready-for-qa
labels: [hud, adapt, drive-mode, polish]
created: 2026-09-26
satisfies: foundation
blocked-by: []
modules: [DriveModeToastLayer, DriveModeMapping, HudHost]
tier: T2
owner: zee-dev
priority: now
filed-by: zee-pdm
gate: armed-2026-09-26
related: [0104]
parent: [0104]
---

# 0109 — Drive-mode toast higher + blue/green/red accents

## Block scope

Maxim 2026-09-26 ~09:33 Minsk (after Live 1.1.0+22):

1. Raise the HUD drive-mode change toast **slightly higher** — it currently **crosses the speedo**.
2. Recolor the three modes: **blue / green / red** (one solid accent per mode). Drop the current cyan/orange 0104 palette.

**Does not** add a permanent badge (that is **0110**). Change-only toast chrome; keep 0104 change-only / ~5 s / fade / cold-open silence rules.

## Product mapping (HARD)

| Mode | Accent |
|------|--------|
| ECO | **green** |
| Comfort | **blue** |
| Sport | **red** |
| other / unknown | soft grey (no invent) |

Keep Adapt `0x22010100` mapping from 0104. Labels unchanged (ECO / Comfort / Sport).

## Position

- Move toast **up** within Safe Area / top-centre stack so it clears the speedo cluster on Tablet dens320 HUD and DHU geometry.
- Still clear of blinkers / Alien radar / battery.
- Measure on T2 Tablet dens320 (never `wm density`); soft car T3 after.

## Definition of Done

Inherits [PRINCIPLES.md](../PRINCIPLES.md). For this Block specifically:

- [x] Toast sits **above** the speedo region — Alignment raised `-0.55` → `-0.82` (top-centre Safe Area). QA evidence crop on tip.
- [x] ECO=green, Comfort=blue, Sport=red on toast chrome (glyph/label accent); other/unknown soft grey.
- [x] 0104 behaviour preserved: change-only; cold-open / first-known silent; ~5 s then fade; same-mode silent.
- [x] Simulated Settings / inject still fires ECO / Comfort / Sport for T2 (untouched).
- [x] Unit / widget fixtures for accent colors; `dart analyze` clean on touched Dart.
- [ ] QA FINDINGS on tip + beta four-point + PDM ACCEPT after own-check. Soft: car T3.


## Reconciliation

**2026-09-26 tip:** Raise drive-mode toast above speedo; blue/green/red accents.

### Changes
1. **Position:** `DriveModeToastLayer` Align `Alignment(0, -0.55)` → `Alignment(0, -0.82)` — higher in Safe Area top-centre so chrome clears the speedo cluster on Tablet dens320 / DHU geometry; still clear of blinkers / Alien radar / battery.
2. **Accents (0109):** ECO=`#3DDC84` green, Comfort=`#3B82F6` blue, Sport=`#FF3B30` red; other/unknown soft grey `#C8CDD8`. Drops 0104 cyan (`#7EC8FF`) / orange (`#FF8A4C`) palette. Exposed as `driveModeToastAccent`.
3. **0104 preserved:** change-only; cold-open / first-known silent; ~5 s hold + ~450 ms fade; same-mode silent. Labels / Adapt `0x22010100` mapping unchanged. Simulate ECO/Comfort/Sport untouched.
4. **0110 not touched** (no persistent corner dot). No Live bump (`1.1.0+22`). Soft: car T3.

### Verification
`flutter test` — `test/hud/drive_mode_toast_accent_test.dart`, `test/providers/drive_mode_toast_test.dart` (incl. 0109 accent chrome widget), `test/services/drive_mode_mapping_test.dart` → 10/10 PASS. `dart analyze` clean on touched Dart.

**Divergence:** None from scope; change-only. Soft: car T3 clearance confirm.

## Notes

- Cooking: tip OK; **no Live bump** until Maxim GO after ACCEPT.
- Do **not** implement 0110 persistent corner dot here — leave that for 0110.
- Prefer cut **before** 0110 if one Tablet contested.
- Toast accents = blue/green/**red**; 0110 Sport **dot** is yellow (document both when 0110 lands).
